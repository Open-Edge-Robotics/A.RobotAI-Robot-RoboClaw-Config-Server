// frontend/lib/features/scenarios/scenario_controller.dart
//
// 테스트 시나리오 목록/CRUD 상태를 담당하는 Controller.
// AdminApi 를 주입받아 Widget 없이 테스트할 수 있다.
//
// 상태 규칙
// - 401: 목록 조회(load)와 변이(activate/clone/delete/save) 모두
//   [unauthorized] 로 기록한다. 변이의 예외 전파 계약은 그대로 유지한다.
// - 최신응답: [load] 는 요청 세대를 기록하고, 늦게 도착한 이전 응답은 상태에
//   반영하지 않는다.
// - 중복 제출: 변이 중에는 [busy] 가 true 이고 재호출은 API 를 다시 부르지
//   않는다. 반환값이 있는 clone/save 는 진행 중인 요청의 Future 를 재사용한다.

import 'package:flutter/foundation.dart';
import '../../api/admin_api.dart';
import '../../api/api_exception.dart';
import '../../models/scenario_model.dart';
import '../../services/logger.dart';
import '../activation.dart';

class ScenarioController extends ChangeNotifier {
  final AdminApi api;

  List<TestScenario> scenarios = [];
  bool loading = false;
  String? error;
  bool unauthorized = false;

  /// 변이(activate/clone/delete/save) 요청이 진행 중인지 여부.
  bool busy = false;

  bool _disposed = false;

  /// 마지막 load 요청의 세대. 이전 세대의 응답은 버린다.
  int _generation = 0;

  /// 진행 중인 clone/save 요청.
  /// 중복 제출 시 새 API 호출 대신 이 Future 를 그대로 돌려준다.
  Future<TestScenario>? _pendingClone;
  Future<TestScenario>? _pendingSave;

  ScenarioController({required this.api});

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// dispose 이후 도착한 in-flight 응답은 상태만 갱신하고 알림은 보내지 않는다.
  void _notifyIfActive() {
    if (_disposed) return;
    notifyListeners();
  }

  void _beginMutation() {
    busy = true;
    _notifyIfActive();
  }

  void _endMutation() {
    busy = false;
    _notifyIfActive();
  }

  /// 목록을 조회한다. [robotName]/[environment] 로 필터링할 수 있다.
  ///
  /// 더 새로운 load 가 시작되면 이전 요청의 응답(성공/실패)은 상태에 반영하지
  /// 않는다. `loading` 은 최신 요청이 끝날 때만 내려간다.
  Future<void> load({String? robotName, String? environment}) async {
    final generation = ++_generation;
    loading = true;
    error = null;
    unauthorized = false;
    _notifyIfActive();
    try {
      final fetched = await api.fetchScenarios(
        robotName: robotName,
        environment: environment,
      );
      if (generation != _generation) return;
      scenarios = fetched;
    } on ApiException catch (e, stack) {
      if (generation != _generation) return;
      if (e.statusCode == 401) unauthorized = true;
      error = e.message;
      AppLogger.error('ScenarioController.load', e, stack);
    } catch (e, stack) {
      if (generation != _generation) return;
      error = e.toString();
      AppLogger.error('ScenarioController.load', e, stack);
    } finally {
      if (generation == _generation) {
        loading = false;
        _notifyIfActive();
      }
    }
  }

  /// 시나리오를 활성화하고 같은 로봇/환경의 다른 항목을 비활성화한다.
  ///
  /// 다른 로봇/환경 그룹의 활성 상태는 유지된다(서버 ActivateScenario 와 동일 규칙).
  /// 변이 진행 중이면([busy]) API 를 다시 호출하지 않고 즉시 반환한다.
  Future<void> activate(int id) async {
    if (busy) return;
    _beginMutation();
    try {
      await api.activateScenario(id);
      applyGroupActivation(
        scenarios,
        activatedId: id,
        idOf: (scenario) => scenario.id,
        robotOf: (scenario) => scenario.robotName,
        environmentOf: (scenario) => scenario.environment,
        setActive: (scenario, isActive) => scenario.isActive = isActive,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) unauthorized = true;
      rethrow;
    } finally {
      _endMutation();
    }
  }

  /// 시나리오를 복제하고 목록에 추가한다.
  ///
  /// 같은 clone 요청이 진행 중이면 그 Future 를 재사용하므로 중복 탭은 API 를
  /// 한 번만 호출한다(두 번째 호출의 [id] 는 무시된다). clone/save 가 아닌
  /// 다른 변이가 진행 중이면 재사용할 결과가 없어 [StateError] 를 던진다.
  /// 화면은 [busy] 로 버튼을 비활성화하므로 이 경로는 UI 에서 발생하지 않는다.
  Future<TestScenario> clone(int id) {
    final pending = _pendingClone;
    if (pending != null) return pending;
    if (busy) return Future.error(_concurrentMutationError);

    _beginMutation();
    final future = _clone(id);
    _pendingClone = future;
    return future;
  }

  Future<TestScenario> _clone(int id) async {
    try {
      final cloned = await api.cloneScenario(id);
      scenarios.add(cloned);
      _notifyIfActive();
      return cloned;
    } on ApiException catch (e) {
      if (e.statusCode == 401) unauthorized = true;
      rethrow;
    } finally {
      _pendingClone = null;
      _endMutation();
    }
  }

  /// 시나리오를 삭제하고 목록에서 제거한다.
  ///
  /// 변이 진행 중이면([busy]) API 를 다시 호출하지 않고 즉시 반환한다.
  Future<void> delete(int id) async {
    if (busy) return;
    _beginMutation();
    try {
      await api.deleteScenario(id);
      scenarios.removeWhere((s) => s.id == id);
    } on ApiException catch (e) {
      if (e.statusCode == 401) unauthorized = true;
      rethrow;
    } finally {
      _endMutation();
    }
  }

  /// 시나리오를 저장(생성/수정)하고 목록을 갱신한다.
  ///
  /// 같은 save 요청이 진행 중이면 그 Future 를 재사용하고, 다른 변이가 진행
  /// 중이면 [StateError] 를 던진다(clone 과 동일 규칙).
  Future<TestScenario> save(TestScenario scenario, bool isNew) {
    final pending = _pendingSave;
    if (pending != null) return pending;
    if (busy) return Future.error(_concurrentMutationError);

    _beginMutation();
    final future = _save(scenario, isNew);
    _pendingSave = future;
    return future;
  }

  Future<TestScenario> _save(TestScenario scenario, bool isNew) async {
    try {
      final saved = await api.saveScenario(scenario, isNew);
      if (isNew) {
        scenarios.add(saved);
      } else {
        final idx = scenarios.indexWhere((s) => s.id == saved.id);
        if (idx >= 0) {
          scenarios[idx] = saved;
        }
      }
      _notifyIfActive();
      return saved;
    } on ApiException catch (e) {
      if (e.statusCode == 401) unauthorized = true;
      rethrow;
    } finally {
      _pendingSave = null;
      _endMutation();
    }
  }

  StateError get _concurrentMutationError =>
      StateError('다른 시나리오 변경 요청이 진행 중입니다.');
}
