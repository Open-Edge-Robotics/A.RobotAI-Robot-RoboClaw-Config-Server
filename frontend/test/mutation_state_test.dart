// frontend/test/mutation_state_test.dart
//
// 변이(activate/clone/delete/save) 상태 규칙 테스트.
// - 401 은 목록 조회(load)와 동일하게 unauthorized 로 기록하고 예외는 전파한다.
// - load 는 최신 요청의 응답만 반영한다(늦게 도착한 이전 응답은 무시).
// - 변이 진행 중(busy) 재호출은 API 를 다시 호출하지 않는다.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/api/admin_api.dart';
import 'package:frontend/api/api_exception.dart';
import 'package:frontend/features/configs/config_controller.dart';
import 'package:frontend/features/scenarios/scenario_controller.dart';
import 'package:frontend/models/config_model.dart';
import 'package:frontend/models/scenario_model.dart';

RoboClawConfig _cfg(int id, String name) => RoboClawConfig(
  id: id,
  name: name,
  robotName: 'butler',
  environment: 'office',
);

TestScenario _sc(int id, String name) => TestScenario(
  id: id,
  name: name,
  robotName: 'butler',
  environment: 'office',
  testCases: [],
);

/// 요청별 호출 횟수/게이트/오류를 제어하는 Fake AdminApi.
class MutationApi implements AdminApi {
  final List<Completer<List<RoboClawConfig>>> configFetches = [];
  final List<Completer<List<TestScenario>>> scenarioFetches = [];

  final Map<String, Completer<void>> _gates = {};
  final Map<String, int> _calls = {};

  Object? configMutationError;
  Object? scenarioMutationError;

  RoboClawConfig cloneConfigResult = _cfg(9, 'cfg_copy');
  TestScenario cloneScenarioResult = _sc(9, 'sc_copy');

  int calls(String name) => _calls[name] ?? 0;

  Completer<void> gate(String name) {
    final completer = Completer<void>();
    _gates[name] = completer;
    return completer;
  }

  Future<void> _enter(String name, Object? error) async {
    _calls[name] = calls(name) + 1;
    final pending = _gates[name];
    if (pending != null) await pending.future;
    if (error != null) throw error;
  }

  @override
  Future<List<RoboClawConfig>> fetchConfigs({
    String? robotName,
    String? environment,
  }) {
    final completer = Completer<List<RoboClawConfig>>();
    configFetches.add(completer);
    return completer.future;
  }

  @override
  Future<List<TestScenario>> fetchScenarios({
    String? robotName,
    String? environment,
  }) {
    final completer = Completer<List<TestScenario>>();
    scenarioFetches.add(completer);
    return completer.future;
  }

  @override
  Future<void> activateConfig(int id) =>
      _enter('activateConfig', configMutationError);

  @override
  Future<void> deleteConfig(int id) =>
      _enter('deleteConfig', configMutationError);

  @override
  Future<RoboClawConfig> cloneConfig(int id) async {
    await _enter('cloneConfig', configMutationError);
    return cloneConfigResult;
  }

  @override
  Future<RoboClawConfig> saveConfig(RoboClawConfig config, bool isNew) async {
    await _enter('saveConfig', configMutationError);
    return config;
  }

  @override
  Future<void> activateScenario(int id) =>
      _enter('activateScenario', scenarioMutationError);

  @override
  Future<void> deleteScenario(int id) =>
      _enter('deleteScenario', scenarioMutationError);

  @override
  Future<TestScenario> cloneScenario(int id) async {
    await _enter('cloneScenario', scenarioMutationError);
    return cloneScenarioResult;
  }

  @override
  Future<TestScenario> saveScenario(TestScenario scenario, bool isNew) async {
    await _enter('saveScenario', scenarioMutationError);
    return scenario;
  }

  // 이 테스트에서 쓰지 않는 API 는 noSuchMethod 로 위임한다.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _unauthorized = ApiException('unauthorized', statusCode: 401);
final _serverError = ApiException('server down', statusCode: 500);

void main() {
  late MutationApi api;
  late ConfigController configs;
  late ScenarioController scenarios;

  setUp(() {
    api = MutationApi();
    configs = ConfigController(api: api);
    scenarios = ScenarioController(api: api);
  });

  group('ConfigController 401 통일', () {
    test('activate/delete 401 은 unauthorized 를 기록하고 예외를 전파한다', () async {
      api.configMutationError = _unauthorized;
      await expectLater(configs.activate(1), throwsA(_unauthorized));
      await expectLater(configs.delete(1), throwsA(_unauthorized));
      expect(configs.unauthorized, isTrue);
    });

    test('clone/save 401 은 unauthorized 를 기록하고 예외를 전파한다', () async {
      api.configMutationError = _unauthorized;
      await expectLater(configs.clone(1), throwsA(_unauthorized));
      await expectLater(
        configs.save(_cfg(1, 'a'), true),
        throwsA(_unauthorized),
      );
      expect(configs.unauthorized, isTrue);
    });

    test('401 이 아닌 실패는 unauthorized 를 건드리지 않는다', () async {
      api.configMutationError = _serverError;
      await expectLater(configs.activate(1), throwsA(_serverError));
      expect(configs.unauthorized, isFalse);
    });
  });

  group('ConfigController 최신응답 가드', () {
    test('늦게 도착한 이전 load 응답은 목록/loading 을 덮어쓰지 않는다', () async {
      final first = configs.load();
      final second = configs.load();
      expect(api.configFetches, hasLength(2));

      api.configFetches[0].complete([_cfg(1, 'stale')]);
      await first;
      expect(configs.loading, isTrue, reason: '최신 요청이 아직 진행 중이다');
      expect(configs.configs, isEmpty);

      api.configFetches[1].complete([_cfg(2, 'fresh')]);
      await second;
      expect(configs.configs.single.name, 'fresh');
      expect(configs.loading, isFalse);
    });

    test('이전 load 의 401 은 최신 상태(unauthorized)를 덮어쓰지 않는다', () async {
      final first = configs.load();
      final second = configs.load();

      api.configFetches[1].complete([]);
      await second;
      expect(configs.unauthorized, isFalse);

      api.configFetches[0].completeError(_unauthorized);
      await first;
      expect(configs.unauthorized, isFalse);
      expect(configs.error, isNull);
      expect(configs.loading, isFalse);
    });
  });

  group('ConfigController busy', () {
    test('busy 는 변이 중 true, 완료/실패 후 false 로 복구된다', () async {
      final gate = api.gate('activateConfig');
      final future = configs.activate(1);
      expect(configs.busy, isTrue);

      gate.complete();
      await future;
      expect(configs.busy, isFalse);

      api.configMutationError = _serverError;
      await expectLater(configs.activate(1), throwsA(_serverError));
      expect(configs.busy, isFalse);
    });

    test('activate/delete 진행 중 재호출은 API 를 다시 호출하지 않는다', () async {
      final activateGate = api.gate('activateConfig');
      final activate1 = configs.activate(1);
      final activate2 = configs.activate(1);
      activateGate.complete();
      await Future.wait([activate1, activate2]);

      final deleteGate = api.gate('deleteConfig');
      final delete1 = configs.delete(1);
      final delete2 = configs.delete(1);
      deleteGate.complete();
      await Future.wait([delete1, delete2]);

      expect(api.calls('activateConfig'), 1);
      expect(api.calls('deleteConfig'), 1);
    });

    test('clone 중복 제출은 진행 중인 요청의 결과를 재사용한다', () async {
      final gate = api.gate('cloneConfig');
      final first = configs.clone(1);
      final second = configs.clone(1);
      expect(identical(first, second), isTrue, reason: '동일 요청 Future 재사용');

      gate.complete();
      final results = await Future.wait([first, second]);
      expect(api.calls('cloneConfig'), 1);
      expect(results[0].id, 9);
      expect(configs.configs.where((c) => c.id == 9), hasLength(1));
    });

    test('save 중복 제출은 진행 중인 요청의 결과를 재사용한다', () async {
      final gate = api.gate('saveConfig');
      final first = configs.save(_cfg(1, 'a'), true);
      final second = configs.save(_cfg(1, 'a'), true);

      gate.complete();
      final results = await Future.wait([first, second]);
      expect(api.calls('saveConfig'), 1);
      expect(results[0].id, 1);
      expect(configs.configs, hasLength(1));
    });

    test('다른 종류의 변이가 진행 중이면 재사용할 결과가 없어 StateError', () async {
      final gate = api.gate('activateConfig');
      final activate = configs.activate(1);

      await expectLater(configs.clone(1), throwsStateError);
      expect(api.calls('cloneConfig'), 0);

      gate.complete();
      await activate;
    });
  });

  group('ScenarioController 401 / 최신응답 / busy', () {
    test('activate/clone/delete 401 은 unauthorized 를 기록하고 예외를 전파한다', () async {
      api.scenarioMutationError = _unauthorized;
      await expectLater(scenarios.activate(1), throwsA(_unauthorized));
      await expectLater(scenarios.clone(1), throwsA(_unauthorized));
      await expectLater(scenarios.delete(1), throwsA(_unauthorized));
      expect(scenarios.unauthorized, isTrue);
    });

    test('늦게 도착한 이전 load 응답은 반영되지 않는다', () async {
      final first = scenarios.load();
      final second = scenarios.load();

      api.scenarioFetches[1].complete([_sc(2, 'fresh')]);
      await second;
      api.scenarioFetches[0].complete([_sc(1, 'stale')]);
      await first;

      expect(scenarios.scenarios.single.name, 'fresh');
      expect(scenarios.loading, isFalse);
    });

    test('activate 진행 중 재호출은 API 를 다시 호출하지 않는다', () async {
      final gate = api.gate('activateScenario');
      final first = scenarios.activate(1);
      final second = scenarios.activate(1);

      gate.complete();
      await Future.wait([first, second]);
      expect(api.calls('activateScenario'), 1);
    });
  });
}
