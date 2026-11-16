// frontend/test/api_timeout_test.dart
//
// HttpAdminApi 가 모든 HTTP 호출에 requestTimeout 을 적용하는지 검증한다.
// 응답을 보류하는 MockClient(Completer)로 TimeoutException 전파를 확인하고,
// 정상 응답/토큰 헤더 같은 기존 동작이 그대로인지도 함께 확인한다.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/api/http_admin_api.dart';
import 'package:frontend/models/config_model.dart';
import 'package:frontend/models/scenario_model.dart';
import 'package:frontend/storage/token_store.dart';

class FakeTokenStore implements TokenStore {
  FakeTokenStore([this.value]);

  String? value;

  @override
  String? read() => value;

  @override
  void write(String token) => value = token;

  @override
  void clear() => value = null;
}

/// 테스트에서만 쓰는 아주 짧은 상한. 실제 기본값은 20초.
const _shortTimeout = Duration(milliseconds: 10);

HttpAdminApi _pendingApi(
  Completer<http.Response> completer, {
  TokenStore? tokenStore,
}) {
  return HttpAdminApi(
    client: MockClient((request) => completer.future),
    tokenStore: tokenStore ?? FakeTokenStore(),
    requestTimeout: _shortTimeout,
  );
}

RoboClawConfig _config({int? id}) => RoboClawConfig(
  id: id,
  name: 'cfg',
  robotName: 'butler',
  environment: 'office',
);

TestScenario _scenario({int? id}) => TestScenario(
  id: id,
  name: 'sc',
  robotName: 'butler',
  environment: 'office',
  testCases: [],
);

/// AdminApi 의 모든 HTTP 호출 경로를 한 번씩 실행하는 목록.
final Map<String, Future<Object?> Function(HttpAdminApi)> _allCalls = {
  'fetchConfigs (GET)': (api) => api.fetchConfigs(),
  'saveConfig 신규 (POST)': (api) => api.saveConfig(_config(), true),
  'saveConfig 수정 (PUT)': (api) => api.saveConfig(_config(id: 1), false),
  'deleteConfig (DELETE)': (api) => api.deleteConfig(1),
  'activateConfig (POST)': (api) => api.activateConfig(1),
  'fetchConfigFile (GET)': (api) => api.fetchConfigFile(1, 'ROBOT.md'),
  'cloneConfig (POST)': (api) => api.cloneConfig(1),
  'fetchMcpCatalog (GET)': (api) => api.fetchMcpCatalog(),
  'fetchScenarios (GET)': (api) => api.fetchScenarios(),
  'saveScenario 신규 (POST)': (api) => api.saveScenario(_scenario(), true),
  'saveScenario 수정 (PUT)': (api) => api.saveScenario(_scenario(id: 1), false),
  'deleteScenario (DELETE)': (api) => api.deleteScenario(1),
  'activateScenario (POST)': (api) => api.activateScenario(1),
  'cloneScenario (POST)': (api) => api.cloneScenario(1),
  'exportBackup (POST)': (api) => api.exportBackup(includeSecrets: false),
  'validateImport (POST)': (api) => api.validateImport({'kind': 'x'}),
  'importBackup (POST)': (api) => api.importBackup(
    document: {'kind': 'x'},
    conflictPolicy: 'skip',
    activationPolicy: 'inactive',
  ),
};

void main() {
  group('requestTimeout', () {
    for (final entry in _allCalls.entries) {
      test('${entry.key} 은 응답이 없으면 TimeoutException 으로 실패한다', () async {
        final completer = Completer<http.Response>();
        await expectLater(
          entry.value(_pendingApi(completer)),
          throwsA(isA<TimeoutException>()),
        );
        // 보류 중인 요청을 정리하고 테스트를 종료한다.
        completer.complete(http.Response('{}', 200));
      }, timeout: const Timeout(Duration(seconds: 10)));
    }

    test('정상 응답은 timeout 내에 완료되고 토큰 헤더를 유지한다', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/configs');
        expect(request.headers['Authorization'], 'Bearer tok');
        return http.Response(
          '[{"name":"a","robot_name":"butler","environment":"office"}]',
          200,
        );
      });
      final api = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore('tok'),
        requestTimeout: const Duration(seconds: 1),
      );

      final list = await api.fetchConfigs();
      expect(list.single.name, 'a');
    });

    test('기본 timeout 으로 구성해도 정상 응답은 그대로 완료된다', () async {
      final client = MockClient((request) async => http.Response('[]', 200));
      final api = HttpAdminApi(client: client, tokenStore: FakeTokenStore());

      expect(await api.fetchScenarios(), isEmpty);
    });

    test('timeout 은 예외 타입을 바꾸지 않고 그대로 전파된다', () async {
      final completer = Completer<http.Response>();
      try {
        await _pendingApi(completer).fetchMcpCatalog();
        fail('TimeoutException 이 발생해야 한다');
      } on TimeoutException catch (e) {
        expect(e, isA<TimeoutException>());
      }
      completer.complete(http.Response('{"servers":[]}', 200));
    });
  });
}
