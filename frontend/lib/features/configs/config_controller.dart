// frontend/lib/features/configs/config_controller.dart
//
// 설정 프로필 목록/CRUD 상태를 담당하는 Controller.
// AdminApi 를 주입받아 Widget 없이 테스트할 수 있다.

import 'package:flutter/foundation.dart';
import '../../api/admin_api.dart';
import '../../api/api_exception.dart';
import '../../models/config_model.dart';
import '../../services/logger.dart';
import '../activation.dart';
import 'runtime_config_validator.dart';

class ConfigController extends ChangeNotifier {
  final AdminApi api;

  List<RoboClawConfig> configs = [];
  bool loading = false;
  String? error;
  bool unauthorized = false;

  bool _disposed = false;

  ConfigController({required this.api});

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
      configs = await api.fetchConfigs(
        robotName: robotName,
        environment: environment,
      );
    } on ApiException catch (e, stack) {
      if (e.statusCode == 401) unauthorized = true;
      error = e.message;
      AppLogger.error('ConfigController.load', e, stack);
    } catch (e, stack) {
      error = e.toString();
      AppLogger.error('ConfigController.load', e, stack);
    } finally {
      loading = false;
      _notifyIfActive();
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
    _notifyIfActive();
  }

  /// 설정을 복제하고 목록에 추가한다.
  Future<RoboClawConfig> clone(int id) async {
    final cloned = await api.cloneConfig(id);
    configs.add(cloned);
    _notifyIfActive();
    return cloned;
  }

  /// 설정을 삭제하고 목록에서 제거한다.
  Future<void> delete(int id) async {
    await api.deleteConfig(id);
    configs.removeWhere((c) => c.id == id);
    _notifyIfActive();
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
    _notifyIfActive();
    return saved;
  }
}
