// frontend/lib/features/scenarios/scenario_controller.dart
//
// 테스트 시나리오 목록/CRUD 상태를 담당하는 Controller.
// AdminApi 를 주입받아 Widget 없이 테스트할 수 있다.

import 'package:flutter/foundation.dart';
import '../../api/admin_api.dart';
import '../../api/http_admin_api.dart' show ApiException;
import '../../models/scenario_model.dart';
import '../activation.dart';

class ScenarioController extends ChangeNotifier {
  final AdminApi api;

  List<TestScenario> scenarios = [];
  bool loading = false;
  String? error;
  bool unauthorized = false;

  ScenarioController({required this.api});

  /// 목록을 조회한다. [robotName]/[environment] 로 필터링할 수 있다.
  Future<void> load({String? robotName, String? environment}) async {
    loading = true;
    error = null;
    unauthorized = false;
    notifyListeners();
    try {
      scenarios = await api.fetchScenarios(
        robotName: robotName,
        environment: environment,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) unauthorized = true;
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
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
    notifyListeners();
  }

  /// 시나리오를 복제하고 목록에 추가한다.
  Future<TestScenario> clone(int id) async {
    final cloned = await api.cloneScenario(id);
    scenarios.add(cloned);
    notifyListeners();
    return cloned;
  }

  /// 시나리오를 삭제하고 목록에서 제거한다.
  Future<void> delete(int id) async {
    await api.deleteScenario(id);
    scenarios.removeWhere((s) => s.id == id);
    notifyListeners();
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
    notifyListeners();
    return saved;
  }
}
