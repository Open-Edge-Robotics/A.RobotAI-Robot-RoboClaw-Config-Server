// frontend/test/controller_lifecycle_test.dart
//
// Controller lifecycle 안전성 테스트.
// 위젯이 사라진 뒤에도 in-flight API 호출은 완료될 수 있다. 그때 Controller 가
// 이미 dispose 되었다면 notifier 알림을 보내면 안 되고, 호출자에게 예외를
// 던져서도 안 된다.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/api/admin_api.dart';
import 'package:frontend/features/backup/backup_controller.dart';
import 'package:frontend/features/configs/config_controller.dart';
import 'package:frontend/features/scenarios/scenario_controller.dart';
import 'package:frontend/models/config_model.dart';
import 'package:frontend/models/mcp_catalog_entry.dart';
import 'package:frontend/models/scenario_model.dart';
import 'package:frontend/platform/file_downloader.dart';
import 'package:frontend/platform/file_picker.dart';

class PendingAdminApi implements AdminApi {
  final fetchConfigsCompleter = Completer<List<RoboClawConfig>>();
  final saveConfigCompleter = Completer<RoboClawConfig>();
  final deleteConfigCompleter = Completer<void>();
  final fetchScenariosCompleter = Completer<List<TestScenario>>();
  final cloneScenarioCompleter = Completer<TestScenario>();
  final exportCompleter = Completer<String>();
  final importCompleter = Completer<Map<String, dynamic>>();

  Map<String, dynamic> validateResult = {'valid': true, 'summary': {}};

  @override
  Future<List<RoboClawConfig>> fetchConfigs({
    String? robotName,
    String? environment,
  }) => fetchConfigsCompleter.future;

  @override
  Future<RoboClawConfig> saveConfig(RoboClawConfig config, bool isNew) =>
      saveConfigCompleter.future;

  @override
  Future<void> deleteConfig(int id) => deleteConfigCompleter.future;

  @override
  Future<List<TestScenario>> fetchScenarios({
    String? robotName,
    String? environment,
  }) => fetchScenariosCompleter.future;

  @override
  Future<TestScenario> cloneScenario(int id) => cloneScenarioCompleter.future;

  @override
  Future<String> exportBackup({
    required bool includeSecrets,
    bool includeConfigs = true,
    bool includeScenarios = true,
  }) => exportCompleter.future;

  @override
  Future<Map<String, dynamic>> validateImport(Map<String, dynamic> document) =>
      Future.value(validateResult);

  @override
  Future<Map<String, dynamic>> importBackup({
    required Map<String, dynamic> document,
    required String conflictPolicy,
    required String activationPolicy,
  }) => importCompleter.future;

  @override
  Future<void> activateConfig(int id) => throw UnimplementedError();

  @override
  Future<String> fetchConfigFile(int id, String filename) =>
      throw UnimplementedError();

  @override
  Future<RoboClawConfig> cloneConfig(int id) => throw UnimplementedError();

  @override
  Future<List<McpCatalogEntry>> fetchMcpCatalog({String? query}) =>
      throw UnimplementedError();

  @override
  Future<TestScenario> saveScenario(TestScenario scenario, bool isNew) =>
      throw UnimplementedError();

  @override
  Future<void> deleteScenario(int id) => throw UnimplementedError();

  @override
  Future<void> activateScenario(int id) => throw UnimplementedError();
}

class CompletingFilePicker implements BackupFilePicker {
  PickedBackupFile? nextFile;
  Completer<PickedBackupFile?>? pickCompleter;

  @override
  Future<PickedBackupFile?> pickJson() {
    final completer = pickCompleter;
    if (completer != null) return completer.future;
    return Future.value(nextFile);
  }
}

class RecordingDownloader implements FileDownloader {
  final List<String> downloads = [];

  @override
  void downloadText(String content, String filename) => downloads.add(filename);

  @override
  void downloadZip(Map<String, String> files, String zipFilename) {}
}

RoboClawConfig _cfg(int id, String name) {
  return RoboClawConfig(
    id: id,
    name: name,
    robotName: 'butler',
    environment: 'office',
  );
}

void main() {
  group('ConfigController lifecycle', () {
    test('load 는 응답을 기다리기 전에 loading=true 를 알린다', () async {
      final api = PendingAdminApi();
      final controller = ConfigController(api: api);
      var notifications = 0;
      controller.addListener(() => notifications++);

      final future = controller.load();
      expect(controller.loading, isTrue);
      expect(notifications, 1, reason: 'loading 상태를 즉시 알려야 한다');

      api.fetchConfigsCompleter.complete([_cfg(1, 'a')]);
      await future;
      expect(controller.loading, isFalse);
      expect(notifications, 2);
      controller.dispose();
    });

    test('load 진행 중 dispose 되면 완료 후 알림과 예외가 없다', () async {
      final api = PendingAdminApi();
      final controller = ConfigController(api: api);
      var notifications = 0;
      controller.addListener(() => notifications++);

      final future = controller.load();
      expect(notifications, 1);
      controller.dispose();

      api.fetchConfigsCompleter.complete([_cfg(1, 'a')]);
      await future;

      expect(notifications, 1, reason: 'disposed notifier 는 알림을 보내지 않는다');
    });

    test('save 진행 중 dispose 되면 완료 후 알림과 예외가 없다', () async {
      final api = PendingAdminApi();
      final controller = ConfigController(api: api);
      var notifications = 0;
      controller.addListener(() => notifications++);

      final future = controller.save(_cfg(1, 'saved'), true);
      controller.dispose();

      api.saveConfigCompleter.complete(_cfg(1, 'saved'));
      final saved = await future;

      expect(saved.id, 1, reason: 'API 반환 계약은 유지된다');
      expect(notifications, 0);
    });

    test('delete 진행 중 dispose 되면 완료 후 알림과 예외가 없다', () async {
      final api = PendingAdminApi();
      final controller = ConfigController(api: api);
      var notifications = 0;
      controller.addListener(() => notifications++);

      final future = controller.delete(1);
      controller.dispose();

      api.deleteConfigCompleter.complete();
      await future;

      expect(notifications, 0);
    });
  });

  group('ScenarioController lifecycle', () {
    test('load 는 응답을 기다리기 전에 loading=true 를 알린다', () async {
      final api = PendingAdminApi();
      final controller = ScenarioController(api: api);
      var notifications = 0;
      controller.addListener(() => notifications++);

      final future = controller.load();
      expect(controller.loading, isTrue);
      expect(notifications, 1, reason: 'loading 상태를 즉시 알려야 한다');

      api.fetchScenariosCompleter.complete([]);
      await future;
      expect(controller.loading, isFalse);
      controller.dispose();
    });

    test('load 진행 중 dispose 되면 완료 후 알림과 예외가 없다', () async {
      final api = PendingAdminApi();
      final controller = ScenarioController(api: api);
      var notifications = 0;
      controller.addListener(() => notifications++);

      final future = controller.load();
      expect(notifications, 1);
      controller.dispose();

      api.fetchScenariosCompleter.complete([]);
      await future;

      expect(notifications, 1);
    });

    test('clone 진행 중 dispose 되면 완료 후 알림과 예외가 없다', () async {
      final api = PendingAdminApi();
      final controller = ScenarioController(api: api);
      var notifications = 0;
      controller.addListener(() => notifications++);

      final future = controller.clone(1);
      controller.dispose();

      api.cloneScenarioCompleter.complete(
        TestScenario(
          id: 2,
          name: 'copy',
          robotName: 'butler',
          environment: 'office',
          testCases: [],
        ),
      );
      final cloned = await future;

      expect(cloned.id, 2, reason: 'API 반환 계약은 유지된다');
      expect(notifications, 0);
    });
  });

  group('BackupController lifecycle', () {
    late PendingAdminApi api;
    late CompletingFilePicker picker;
    late RecordingDownloader downloader;

    setUp(() {
      api = PendingAdminApi();
      picker = CompletingFilePicker();
      downloader = RecordingDownloader();
    });

    test('pickAndValidate 진행 중 dispose 되면 완료 후 알림과 예외가 없다', () async {
      picker.pickCompleter = Completer<PickedBackupFile?>();
      final controller = BackupController(
        api: api,
        picker: picker,
        downloader: downloader,
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      final future = controller.pickAndValidate();
      expect(notifications, 1, reason: 'picking 상태를 알린다');
      controller.dispose();

      picker.pickCompleter!.complete(null);
      await future;

      expect(notifications, 1);
    });

    test('exportBackup 진행 중 dispose 되면 완료 후 알림과 예외가 없다', () async {
      final controller = BackupController(
        api: api,
        picker: picker,
        downloader: downloader,
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      final future = controller.exportBackup(includeSecrets: false);
      expect(notifications, 1, reason: 'importing 상태를 알린다');
      controller.dispose();

      api.exportCompleter.complete('{"version":1}');
      await future;

      expect(notifications, 1);
    });

    test('import 진행 중 dispose 되면 완료 후 알림과 예외가 없다', () async {
      picker.nextFile = PickedBackupFile('backup.json', '{"kind":"x"}');
      final controller = BackupController(
        api: api,
        picker: picker,
        downloader: downloader,
      );
      await controller.pickAndValidate();
      expect(controller.status, BackupStatus.ready);

      var notifications = 0;
      controller.addListener(() => notifications++);

      final future = controller.import(
        conflictPolicy: 'skip',
        activationPolicy: 'inactive',
      );
      expect(notifications, 1, reason: 'importing 상태를 알린다');
      controller.dispose();

      api.importCompleter.complete({});
      await future;

      expect(notifications, 1);
    });
  });
}
