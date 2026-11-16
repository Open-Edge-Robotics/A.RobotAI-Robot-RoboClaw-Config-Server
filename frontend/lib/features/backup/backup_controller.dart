// frontend/lib/features/backup/backup_controller.dart
//
// 백업 내보내기/가져오기 상태와 흐름을 담당하는 Controller.
// AdminApi / BackupFilePicker / FileDownloader 를 주입받아 Widget 없이 테스트할 수 있다.

import 'package:flutter/foundation.dart';
import '../../api/admin_api.dart';
import '../../platform/file_downloader.dart';
import '../../platform/file_picker.dart';
import '../../services/file_picker_helper.dart';
import '../../services/logger.dart';

enum BackupStatus {
  idle,
  picking,
  validating,
  ready,
  importing,
  success,
  error,
}

class BackupController extends ChangeNotifier {
  final AdminApi api;
  final BackupFilePicker picker;
  final FileDownloader downloader;

  BackupStatus status = BackupStatus.idle;
  Map<String, dynamic>? document;
  Map<String, dynamic>? validation;
  Map<String, dynamic>? importResult;
  String? error;

  bool _disposed = false;

  BackupController({
    required this.api,
    required this.picker,
    required this.downloader,
  });

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

  bool get isValid => validation?['valid'] == true;

  /// 백업을 내보내고 다운로더로 저장한다.
  Future<void> exportBackup({
    required bool includeSecrets,
    bool includeConfigs = true,
    bool includeScenarios = true,
  }) async {
    status = BackupStatus.importing;
    error = null;
    _notifyIfActive();
    try {
      final content = await api.exportBackup(
        includeSecrets: includeSecrets,
        includeConfigs: includeConfigs,
        includeScenarios: includeScenarios,
      );
      final ts = DateTime.now()
          .toLocal()
          .toString()
          .split(' ')
          .first
          .replaceAll('-', '');
      final filename = includeSecrets
          ? 'ai-config-backup-with-secrets-$ts.json'
          : 'ai-config-backup-$ts.json';
      downloader.downloadText(content, filename);
      status = BackupStatus.success;
    } catch (e, stack) {
      error = e.toString();
      status = BackupStatus.error;
      AppLogger.error('BackupController.exportBackup', e, stack);
    }
    _notifyIfActive();
  }

  /// 파일을 선택하고 서버 검증까지 수행한다.
  Future<void> pickAndValidate() async {
    status = BackupStatus.picking;
    error = null;
    document = null;
    validation = null;
    _notifyIfActive();

    final picked = await picker.pickJson();
    if (picked == null) {
      status = BackupStatus.idle;
      _notifyIfActive();
      return;
    }

    final doc = FilePickerHelper.parseJsonDocument(picked.content);
    if (doc == null) {
      error = 'invalid_json';
      status = BackupStatus.error;
      _notifyIfActive();
      return;
    }

    document = doc;
    status = BackupStatus.validating;
    _notifyIfActive();

    try {
      validation = await api.validateImport(doc);
      status = BackupStatus.ready;
    } catch (e, stack) {
      error = e.toString();
      status = BackupStatus.error;
      AppLogger.error('BackupController.pickAndValidate', e, stack);
    }
    _notifyIfActive();
  }

  /// 검증된 문서를 가져온다.
  Future<void> import({
    required String conflictPolicy,
    required String activationPolicy,
  }) async {
    if (document == null) return;
    status = BackupStatus.importing;
    error = null;
    _notifyIfActive();
    try {
      importResult = await api.importBackup(
        document: document!,
        conflictPolicy: conflictPolicy,
        activationPolicy: activationPolicy,
      );
      status = BackupStatus.success;
    } catch (e, stack) {
      error = e.toString();
      status = BackupStatus.error;
      AppLogger.error('BackupController.import', e, stack);
    }
    _notifyIfActive();
  }
}
