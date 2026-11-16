// frontend/lib/features/scenarios/scenario_controller.dart
//
// 테스트 시나리오 목록/CRUD 상태를 담당하는 Controller.
// AdminApi 를 주입받아 Widget 없이 테스트할 수 있다.

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

  bool _disposed = false;

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

  /// 목록을 조회한다. [robotName]/[environment] 로 필터링할 수 있다.
  Future<void> load({String? robotName, String? environment}) async {
    loading = true;
    error = null;
    unauthorized = false;
    _notifyIfActive();
    try {
      scenarios = await api.fetchScenarios(
        robotName: robotName,
        environment: environment,
      );
    } on ApiException catch (e, stack) {
      if (e.statusCode == 401) unauthorized = true;
      error = e.message;
      AppLogger.error('ScenarioController.load', e, stack);
    } catch (e, stack) {
      error = e.toString();
      AppLogger.error('ScenarioController.load', e, stack);
    } finally {
      loading = false;
      _notifyIfActive();
    }
  }

  /// 시나리오를 활성화하고 같은 로봇/환경의 다른 항목을 비활성화한다.
  ///
  /// 다른 로봇/환경 그룹의 활성 상태는 유지된다(서버 ActivateScenario 와 동일 규칙).
  Future<void> activate(int id) async {
    await api.activateScenario(id);
    applyGroupActivation(
      scenarios,
      activatedId: id,
      idOf: (scenario) => scenario.id,
      robotOf: (scenario) => scenario.robotName,
      environmentOf: (scenario) => scenario.environment,
      setActive: (scenario, isActive) => scenario.isActive = isActive,
    );
    _notifyIfActive();
  }

  /// 시나리오를 복제하고 목록에 추가한다.
  Future<TestScenario> clone(int id) async {
    final cloned = await api.cloneScenario(id);
    scenarios.add(cloned);
    _notifyIfActive();
    return cloned;
  }

  /// 시나리오를 삭제하고 목록에서 제거한다.
  Future<void> delete(int id) async {
    await api.deleteScenario(id);
    scenarios.removeWhere((s) => s.id == id);
    _notifyIfActive();
  }

  /// 시나리오를 저장(생성/수정)하고 목록을 갱신한다.
  Future<TestScenario> save(TestScenario scenario, bool isNew) async {
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
  }
}
