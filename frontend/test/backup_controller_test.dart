// frontend/test/backup_controller_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/api/admin_api.dart';
import 'package:frontend/features/backup/backup_controller.dart';
import 'package:frontend/models/config_model.dart';
import 'package:frontend/models/mcp_catalog_entry.dart';
import 'package:frontend/models/scenario_model.dart';
import 'package:frontend/platform/file_downloader.dart';
import 'package:frontend/platform/file_picker.dart';

class FakeAdminApi implements AdminApi {
  String exportResult = '{"kind":"x"}';
  Object? exportError;
  Map<String, dynamic> validateResult = {'valid': true, 'summary': {}};
  Object? validateError;
  Map<String, dynamic> importResult = {
    'configs': {'created': 1},
  };
  Object? importError;

  int exportCalls = 0;
  int validateCalls = 0;
  int importCalls = 0;
  bool? lastIncludeSecrets;
  String? lastConflictPolicy;
  String? lastActivationPolicy;

  @override
  Future<String> exportBackup({
    required bool includeSecrets,
    bool includeConfigs = true,
    bool includeScenarios = true,
  }) async {
    exportCalls++;
    lastIncludeSecrets = includeSecrets;
    if (exportError != null) throw exportError!;
    return exportResult;
  }

  @override
  Future<Map<String, dynamic>> validateImport(
    Map<String, dynamic> document,
  ) async {
    validateCalls++;
    if (validateError != null) throw validateError!;
    return validateResult;
  }

  @override
  Future<Map<String, dynamic>> importBackup({
    required Map<String, dynamic> document,
    required String conflictPolicy,
    required String activationPolicy,
  }) async {
    importCalls++;
    lastConflictPolicy = conflictPolicy;
    lastActivationPolicy = activationPolicy;
    if (importError != null) throw importError!;
    return importResult;
  }

  @override
  Future<void> activateConfig(int id) => throw UnimplementedError();
  @override
  Future<void> activateScenario(int id) => throw UnimplementedError();
  @override
  Future<RoboClawConfig> cloneConfig(int id) => throw UnimplementedError();
  @override
  Future<TestScenario> cloneScenario(int id) => throw UnimplementedError();
  @override
  Future<void> deleteConfig(int id) => throw UnimplementedError();
  @override
  Future<void> deleteScenario(int id) => throw UnimplementedError();
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
  Future<List<TestScenario>> fetchScenarios({
    String? robotName,
    String? environment,
  }) => throw UnimplementedError();
  @override
  Future<RoboClawConfig> saveConfig(RoboClawConfig config, bool isNew) =>
      throw UnimplementedError();
  @override
  Future<TestScenario> saveScenario(TestScenario scenario, bool isNew) =>
      throw UnimplementedError();
}

class FakeFilePicker implements BackupFilePicker {
  PickedBackupFile? result;
  @override
  Future<PickedBackupFile?> pickJson() async => result;
}

class FakeDownloader implements FileDownloader {
  final List<String> downloads = [];
  @override
  void downloadText(String content, String filename) => downloads.add(filename);
  @override
  void downloadZip(Map<String, String> files, String zipFilename) {}
}

void main() {
  late FakeAdminApi api;
  late FakeFilePicker picker;
  late FakeDownloader downloader;
  late BackupController controller;

  setUp(() {
    api = FakeAdminApi();
    picker = FakeFilePicker();
    downloader = FakeDownloader();
    controller = BackupController(
      api: api,
      picker: picker,
      downloader: downloader,
    );
  });

  group('exportBackup', () {
    test('성공 시 다운로더를 호출하고 success 상태가 된다', () async {
      await controller.exportBackup(includeSecrets: false);
      expect(api.exportCalls, 1);
      expect(api.lastIncludeSecrets, isFalse);
      expect(downloader.downloads, hasLength(1));
      expect(downloader.downloads.first, startsWith('ai-config-backup-'));
      expect(controller.status, BackupStatus.success);
    });

    test('민감 정보 포함 시 파일명에 with-secrets 가 붙는다', () async {
      await controller.exportBackup(includeSecrets: true);
      expect(
        downloader.downloads.first,
        startsWith('ai-config-backup-with-secrets-'),
      );
    });

    test('실패 시 error 상태가 된다', () async {
      api.exportError = Exception('boom');
      await controller.exportBackup(includeSecrets: false);
      expect(controller.status, BackupStatus.error);
      expect(controller.error, isNotNull);
      expect(downloader.downloads, isEmpty);
    });
  });

  group('pickAndValidate', () {
    test('파일 선택 취소 시 idle 로 돌아간다', () async {
      picker.result = null;
      await controller.pickAndValidate();
      expect(controller.status, BackupStatus.idle);
      expect(api.validateCalls, 0);
    });

    test('잘못된 JSON 이면 error 상태가 된다', () async {
      picker.result = PickedBackupFile('b.json', '{bad');
      await controller.pickAndValidate();
      expect(controller.status, BackupStatus.error);
      expect(api.validateCalls, 0);
    });

    test('검증 성공 시 ready 상태가 된다', () async {
      picker.result = PickedBackupFile('b.json', '{"kind":"x"}');
      await controller.pickAndValidate();
      expect(api.validateCalls, 1);
      expect(controller.status, BackupStatus.ready);
      expect(controller.isValid, isTrue);
      expect(controller.document, isNotNull);
    });

    test('검증 실패 시 error 상태가 된다', () async {
      picker.result = PickedBackupFile('b.json', '{"kind":"x"}');
      api.validateError = Exception('server down');
      await controller.pickAndValidate();
      expect(controller.status, BackupStatus.error);
    });
  });

  group('import', () {
    test('검증된 문서를 가져오고 success 상태가 된다', () async {
      picker.result = PickedBackupFile('b.json', '{"kind":"x"}');
      await controller.pickAndValidate();

      await controller.import(
        conflictPolicy: 'skip',
        activationPolicy: 'inactive',
      );
      expect(api.importCalls, 1);
      expect(api.lastConflictPolicy, 'skip');
      expect(api.lastActivationPolicy, 'inactive');
      expect(controller.status, BackupStatus.success);
      expect(controller.importResult, isNotNull);
    });

    test('실패 시 error 상태가 된다', () async {
      picker.result = PickedBackupFile('b.json', '{"kind":"x"}');
      await controller.pickAndValidate();
      api.importError = Exception('fail');
      await controller.import(
        conflictPolicy: 'skip',
        activationPolicy: 'inactive',
      );
      expect(controller.status, BackupStatus.error);
    });
  });
}
