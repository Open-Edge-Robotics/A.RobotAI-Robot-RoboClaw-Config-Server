// frontend/lib/features/configs/config_controller.dart
//
// 설정 프로필 목록/CRUD 상태를 담당하는 Controller.
// AdminApi 를 주입받아 Widget 없이 테스트할 수 있다.

import 'package:flutter/foundation.dart';
import '../../api/admin_api.dart';
import '../../api/http_admin_api.dart' show ApiException;
import '../../models/config_model.dart';
import '../activation.dart';
import 'runtime_config_validator.dart';

class ConfigController extends ChangeNotifier {
  final AdminApi api;

  List<RoboClawConfig> configs = [];
  bool loading = false;
  String? error;
  bool unauthorized = false;

  ConfigController({required this.api});

  /// 목록을 조회한다. [robotName]/[environment] 로 필터링할 수 있다.
  Future<void> load({String? robotName, String? environment}) async {
    loading = true;
    error = null;
    unauthorized = false;
    notifyListeners();
    try {
      configs = await api.fetchConfigs(
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

  /// 설정을 활성화하고 같은 로봇/환경의 다른 항목을 비활성화한다.
  ///
  /// 다른 로봇/환경 그룹의 활성 상태는 유지된다(서버 ActivateConfig 와 동일 규칙).
  Future<void> activate(int id) async {
    await api.activateConfig(id);
    applyGroupActivation(
      configs,
      activatedId: id,
      idOf: (config) => config.id,
      robotOf: (config) => config.robotName,
      environmentOf: (config) => config.environment,
      setActive: (config, isActive) => config.isActive = isActive,
    );
    notifyListeners();
  }

  /// 설정을 복제하고 목록에 추가한다.
  Future<RoboClawConfig> clone(int id) async {
    final cloned = await api.cloneConfig(id);
    configs.add(cloned);
    notifyListeners();
    return cloned;
  }

  /// 설정을 삭제하고 목록에서 제거한다.
  Future<void> delete(int id) async {
    await api.deleteConfig(id);
    configs.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// 설정을 저장(생성/수정)하고 목록을 갱신한다.
  Future<RoboClawConfig> save(RoboClawConfig config, bool isNew) async {
    final validationErrors = validateRuntimeConfigJson(config.toJson());
    if (validationErrors.isNotEmpty) {
      throw ArgumentError('설정값 검증 실패: ${validationErrors.join(', ')}');
    }
    final saved = await api.saveConfig(config, isNew);
    if (isNew) {
      configs.add(saved);
    } else {
      final idx = configs.indexWhere((c) => c.id == saved.id);
      if (idx >= 0) {
        configs[idx] = saved;
      }
    }
    notifyListeners();
    return saved;
  }
}
