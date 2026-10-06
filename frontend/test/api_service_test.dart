// frontend/test/api_service_test.dart
//
// ApiService 가 http.Client / TokenStore 를 주입받아 동작하는지 검증한다.
// MockClient(http/testing) 와 FakeTokenStore 를 사용해 네트워크/브라우저 없이 테스트한다.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/api/http_admin_api.dart';
import 'package:frontend/models/config_model.dart';
import 'package:frontend/models/scenario_model.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/storage/token_store.dart';

class FakeTokenStore implements TokenStore {
  String? value;
  @override
  String? read() => value;
  @override
  void write(String token) => value = token;
  @override
  void clear() => value = null;
}

void main() {
  setUp(() {
    // 각 테스트가 독립적으로 기본 인스턴스를 교체한다.
    HttpAdminApi.instance = HttpAdminApi(
      client: http.Client(),
      tokenStore: FakeTokenStore(),
    );
  });

  group('토큰 저장소', () {
    test('save/read/clear 가 동작한다', () {
      final store = FakeTokenStore();
      HttpAdminApi.instance = HttpAdminApi(
        client: http.Client(),
        tokenStore: store,
      );

      expect(ApiService.adminToken, isNull);
      ApiService.saveAdminTokenToStorage('tok-123');
      expect(ApiService.adminToken, 'tok-123');
      ApiService.clearAdminToken();
      expect(ApiService.adminToken, isNull);
    });
  });

  group('fetchConfigs', () {
    test('Authorization 헤더를 보내고 목록을 파싱한다', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/configs');
        expect(request.headers['Authorization'], 'Bearer tok');
        return http.Response(
          '[{"name":"a","robot_name":"butler","environment":"office"}]',
          200,
        );
      });
      final store = FakeTokenStore()..value = 'tok';
      HttpAdminApi.instance = HttpAdminApi(client: client, tokenStore: store);

      final list = await ApiService.fetchConfigs();
      expect(list, hasLength(1));
      expect(list.first.name, 'a');
      expect(list.first.robotName, 'butler');
    });

    test('robot_name/environment 필터를 query 로 전달한다', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['robot_name'], 'butler');
        expect(request.url.queryParameters['environment'], 'office');
        return http.Response('[]', 200);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      await ApiService.fetchConfigs(robotName: 'butler', environment: 'office');
    });

    test('401 응답이면 ApiException 을 던진다', () async {
      final client = MockClient((request) async {
        return http.Response('{"error":"unauthorized"}', 401);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      expect(ApiService.fetchConfigs(), throwsA(isA<ApiException>()));
    });

    test('잘못된 JSON 이면 예외를 던진다', () async {
      final client = MockClient((request) async {
        return http.Response('not-json', 200);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      expect(ApiService.fetchConfigs(), throwsA(isA<FormatException>()));
    });
  });

  group('saveConfig', () {
    test('신규는 POST, JSON body 를 보낸다', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/configs');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], 'new-cfg');
        return http.Response(
          '{"ID":1,"name":"new-cfg","robot_name":"butler","environment":"office"}',
          201,
        );
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      final cfg = RoboClawConfig(
        name: 'new-cfg',
        robotName: 'butler',
        environment: 'office',
      );
      final saved = await ApiService.saveConfig(cfg, true);
      expect(saved.id, 1);
      expect(saved.name, 'new-cfg');
    });

    test('기존은 PUT, id 경로로 보낸다', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/admin/configs/7');
        return http.Response(
          '{"ID":7,"name":"x","robot_name":"butler","environment":"office"}',
          200,
        );
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      final cfg = RoboClawConfig(
        id: 7,
        name: 'x',
        robotName: 'butler',
        environment: 'office',
      );
      final saved = await ApiService.saveConfig(cfg, false);
      expect(saved.id, 7);
    });
  });

  group('deleteConfig / activateConfig', () {
    test('deleteConfig 는 DELETE 를 보낸다', () async {
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/admin/configs/3');
        return http.Response('{"deleted":3}', 200);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      await ApiService.deleteConfig(3);
    });

    test('activateConfig 는 POST 를 보낸다', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/configs/3/activate');
        return http.Response('{"message":"activated"}', 200);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      await ApiService.activateConfig(3);
    });
  });

  group('fetchScenarios', () {
    test('시나리오 목록을 파싱한다', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/scenarios');
        return http.Response(
          '[{"name":"sc","robot_name":"butler","environment":"office","test_cases":[]}]',
          200,
        );
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      final list = await ApiService.fetchScenarios();
      expect(list, hasLength(1));
      expect(list.first.name, 'sc');
    });
  });

  group('백업 API', () {
    test('exportBackup 은 원본 JSON 문자열을 반환한다', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/transfer/export');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['include_secrets'], isFalse);
        return http.Response(
          '{"kind":"ai-config-server.portable-backup"}',
          200,
        );
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      final body = await ApiService.exportBackup(includeSecrets: false);
      expect(body, contains('portable-backup'));
    });

    test('validateImport 는 document 를 보낸다', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/transfer/import/validate');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['document'], isNotNull);
        return http.Response('{"valid":true,"summary":{}}', 200);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      final result = await ApiService.validateImport({'kind': 'x'});
      expect(result['valid'], isTrue);
    });

    test('importBackup 은 options 를 보낸다', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/transfer/import');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final options = body['options'] as Map<String, dynamic>;
        expect(options['conflict_policy'], 'skip');
        expect(options['activation_policy'], 'inactive');
        return http.Response('{"configs":{"created":1}}', 200);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      final result = await ApiService.importBackup(
        document: {'kind': 'x'},
        conflictPolicy: 'skip',
        activationPolicy: 'inactive',
      );
      expect(result['configs']['created'], 1);
    });
  });

  group('fetchConfigFile / cloneConfig', () {
    test('fetchConfigFile 은 파일 본문을 반환한다', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/configs/1/files/ROBOT.md');
        return http.Response('# soul', 200);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      final body = await ApiService.fetchConfigFile(1, 'ROBOT.md');
      expect(body, '# soul');
    });

    test('cloneConfig 는 복제본을 반환한다', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/configs/1/clone');
        return http.Response(
          '{"ID":2,"name":"cfg_copy","robot_name":"butler","environment":"office"}',
          201,
        );
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      final cloned = await ApiService.cloneConfig(1);
      expect(cloned.id, 2);
      expect(cloned.name, 'cfg_copy');
    });
  });

  group('fetchMcpCatalog', () {
    test('카탈로그 항목을 파싱한다', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/mcp/catalog');
        return http.Response(
          '{"servers":[{"name":"fs","display_name":"Filesystem","transport":"stdio"}]}',
          200,
        );
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      final list = await ApiService.fetchMcpCatalog();
      expect(list, hasLength(1));
      expect(list.first.name, 'fs');
    });
  });

  group('scenario CRUD', () {
    test('saveScenario 는 POST 로 저장한다', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/scenarios');
        return http.Response(
          '{"ID":1,"name":"sc","robot_name":"butler","environment":"office","test_cases":[]}',
          201,
        );
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      final scenario = TestScenario(
        name: 'sc',
        robotName: 'butler',
        environment: 'office',
        testCases: [],
      );
      final saved = await ApiService.saveScenario(scenario, true);
      expect(saved.id, 1);
    });

    test('deleteScenario 는 DELETE 를 보낸다', () async {
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/admin/scenarios/3');
        return http.Response('{"deleted":3}', 200);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      await ApiService.deleteScenario(3);
    });

    test('activateScenario 는 POST 를 보낸다', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/scenarios/3/activate');
        return http.Response('{"message":"activated"}', 200);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      await ApiService.activateScenario(3);
    });

    test('cloneScenario 는 복제본을 반환한다', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/scenarios/1/clone');
        return http.Response(
          '{"ID":2,"name":"sc_copy","robot_name":"butler","environment":"office","test_cases":[]}',
          201,
        );
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      final cloned = await ApiService.cloneScenario(1);
      expect(cloned.id, 2);
    });
  });

  group('API 오류 케이스', () {
    test('saveConfig 400 응답이면 ApiException 을 던진다', () async {
      final client = MockClient((request) async {
        return http.Response('{"error":"bad request"}', 400);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      final cfg = RoboClawConfig(
        name: 'x',
        robotName: 'butler',
        environment: 'office',
      );
      expect(ApiService.saveConfig(cfg, true), throwsA(isA<ApiException>()));
    });

    test('cloneConfig 500 응답이면 ApiException 을 던진다', () async {
      final client = MockClient((request) async {
        return http.Response('{"error":"server error"}', 500);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      expect(ApiService.cloneConfig(1), throwsA(isA<ApiException>()));
    });

    test('deleteConfig 404 응답이면 ApiException 을 던진다', () async {
      final client = MockClient((request) async {
        return http.Response('{"error":"not found"}', 404);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      expect(ApiService.deleteConfig(99), throwsA(isA<ApiException>()));
    });

    test('fetchConfigFile 404 응답이면 ApiException 을 던진다', () async {
      final client = MockClient((request) async {
        return http.Response('{"error":"not found"}', 404);
      });
      HttpAdminApi.instance = HttpAdminApi(
        client: client,
        tokenStore: FakeTokenStore(),
      );

      expect(
        ApiService.fetchConfigFile(1, 'ROBOT.md'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
