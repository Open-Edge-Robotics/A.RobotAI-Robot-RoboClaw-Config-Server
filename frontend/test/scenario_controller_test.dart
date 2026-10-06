// frontend/test/scenario_controller_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/api/admin_api.dart';
import 'package:frontend/api/http_admin_api.dart';
import 'package:frontend/features/scenarios/scenario_controller.dart';
import 'package:frontend/models/config_model.dart';
import 'package:frontend/models/mcp_catalog_entry.dart';
import 'package:frontend/models/scenario_model.dart';

class FakeScenarioApi implements AdminApi {
  List<TestScenario> fetchResult = [];
  Object? fetchError;
  int fetchStatus = 200;
  int fetchCalls = 0;

  TestScenario? activateTarget;
  TestScenario? cloneResult;
  TestScenario? saveResult;
  Object? crudError;

  @override
  Future<List<TestScenario>> fetchScenarios({
    String? robotName,
    String? environment,
  }) async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    if (fetchStatus == 401) throw ApiException('unauthorized', statusCode: 401);
    return fetchResult;
  }

  @override
  Future<void> activateScenario(int id) async {
    if (crudError != null) throw crudError!;
    // 서버가 성공을 반환해도 목록에 없는 id 일 수 있다(필터 등).
    // 컨트롤러가 그 경우에도 안전한지 검증하기 위해 예외를 던지지 않는다.
    final index = fetchResult.indexWhere((s) => s.id == id);
    activateTarget = index < 0 ? null : fetchResult[index];
  }

  @override
  Future<TestScenario> cloneScenario(int id) async {
    if (crudError != null) throw crudError!;
    return cloneResult!;
  }

  @override
  Future<void> deleteScenario(int id) async {
    if (crudError != null) throw crudError!;
  }

  @override
  Future<TestScenario> saveScenario(TestScenario scenario, bool isNew) async {
    if (crudError != null) throw crudError!;
    return saveResult ?? scenario;
  }

  @override
  Future<void> activateConfig(int id) => throw UnimplementedError();
  @override
  Future<RoboClawConfig> cloneConfig(int id) => throw UnimplementedError();
  @override
  Future<void> deleteConfig(int id) => throw UnimplementedError();
  @override
  Future<String> exportBackup({
    required bool includeSecrets,
    bool includeConfigs = true,
    bool includeScenarios = true,
  }) => throw UnimplementedError();
  @override
  Future<List<RoboClawConfig>> fetchConfigs({
    String? robotName,
    String? environment,
  }) => throw UnimplementedError();
  @override
  Future<String> fetchConfigFile(int id, String filename) =>
      throw UnimplementedError();
  @override
  Future<List<McpCatalogEntry>> fetchMcpCatalog({String? query}) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> importBackup({
    required Map<String, dynamic> document,
    required String conflictPolicy,
    required String activationPolicy,
  }) => throw UnimplementedError();
  @override
  Future<RoboClawConfig> saveConfig(RoboClawConfig config, bool isNew) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> validateImport(Map<String, dynamic> document) =>
      throw UnimplementedError();
}

TestScenario _sc(
  int id,
  String name, {
  String robot = 'butler',
  String env = 'office',
  bool active = false,
}) {
  return TestScenario(
    id: id,
    name: name,
    robotName: robot,
    environment: env,
    isActive: active,
    testCases: [],
  );
}

void main() {
  late FakeScenarioApi api;
  late ScenarioController controller;

  setUp(() {
    api = FakeScenarioApi();
    controller = ScenarioController(api: api);
  });

  group('load', () {
    test('성공 시 목록을 채우고 loading 이 false 가 된다', () async {
      api.fetchResult = [_sc(1, 'a'), _sc(2, 'b')];
      await controller.load();
      expect(controller.scenarios, hasLength(2));
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
    });

    test('401 이면 unauthorized 가 true 가 된다', () async {
      api.fetchStatus = 401;
      await controller.load();
      expect(controller.unauthorized, isTrue);
      expect(controller.error, isNotNull);
    });

    test('네트워크 오류 시 error 가 설정된다', () async {
      api.fetchError = Exception('down');
      await controller.load();
      expect(controller.error, isNotNull);
      expect(controller.scenarios, isEmpty);
    });
  });

  group('activate', () {
    test('대상만 활성화하고 같은 로봇/환경의 다른 항목은 비활성화한다', () async {
      api.fetchResult = [
        _sc(1, 'a', robot: 'butler', env: 'office'),
        _sc(2, 'b', robot: 'butler', env: 'office'),
        _sc(3, 'c', robot: 'butler', env: 'office', active: true),
      ];
      await controller.load();
      await controller.activate(2);
      expect(controller.scenarios[0].isActive, isFalse);
      expect(controller.scenarios[1].isActive, isTrue);
      expect(
        controller.scenarios[2].isActive,
        isFalse,
        reason: '같은 그룹의 중복 Active 해제',
      );
    });

    test('다른 로봇/환경 그룹의 활성 상태는 유지한다', () async {
      api.fetchResult = [
        _sc(1, 'a', robot: 'butler', env: 'office'),
        _sc(2, 'b', robot: 'former', env: 'factory', active: true),
        _sc(3, 'c', robot: 'former', env: 'factory'),
        _sc(4, 'd', robot: 'butler', env: 'factory'),
      ];
      await controller.load();
      await controller.activate(1);
      expect(controller.scenarios[0].isActive, isTrue);
      expect(controller.scenarios[1].isActive, isTrue, reason: '다른 그룹의 활성 유지');
      expect(
        controller.scenarios[2].isActive,
        isFalse,
        reason: '다른 그룹의 비활성 유지',
      );
      expect(
        controller.scenarios[3].isActive,
        isFalse,
        reason: '같은 로봇/다른 환경 유지',
      );
    });

    test('목록에 없는 id 를 활성화해도 예외 없이 무시한다', () async {
      api.fetchResult = [_sc(1, 'a')];
      await controller.load();
      await controller.activate(999);
      expect(controller.scenarios[0].isActive, isFalse);
    });
  });

  group('clone / delete / save', () {
    test('clone 은 목록에 추가하고 복제본을 반환한다', () async {
      api.fetchResult = [_sc(1, 'a')];
      await controller.load();
      api.cloneResult = _sc(2, 'a_copy');
      final cloned = await controller.clone(1);
      expect(cloned.id, 2);
      expect(controller.scenarios, hasLength(2));
    });

    test('delete 는 목록에서 제거한다', () async {
      api.fetchResult = [_sc(1, 'a'), _sc(2, 'b')];
      await controller.load();
      await controller.delete(1);
      expect(controller.scenarios, hasLength(1));
      expect(controller.scenarios.first.id, 2);
    });

    test('save 신규는 목록에 추가한다', () async {
      api.fetchResult = [];
      await controller.load();
      final saved = await controller.save(_sc(1, 'new'), true);
      expect(saved.id, 1);
      expect(controller.scenarios, hasLength(1));
    });

    test('save 수정은 기존 항목을 갱신한다', () async {
      api.fetchResult = [_sc(1, 'old')];
      await controller.load();
      api.saveResult = _sc(1, 'renamed');
      await controller.save(_sc(1, 'renamed'), false);
      expect(controller.scenarios.first.name, 'renamed');
    });
  });
}
