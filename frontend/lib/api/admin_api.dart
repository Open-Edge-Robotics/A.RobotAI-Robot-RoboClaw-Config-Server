// frontend/lib/api/admin_api.dart
//
// 관리자 API 인터페이스. Controller/Service 는 이 인터페이스에만 의존한다.
// 실제 구현(HttpAdminApi)과 테스트용 Fake 를 교체 주입할 수 있다.

import '../models/config_model.dart';
import '../models/mcp_catalog_entry.dart';
import '../models/scenario_model.dart';

abstract interface class AdminApi {
  // Configs
  Future<List<RoboClawConfig>> fetchConfigs({
    String? robotName,
    String? environment,
  });

  Future<RoboClawConfig> saveConfig(RoboClawConfig config, bool isNew);

  Future<void> deleteConfig(int id);

  Future<void> activateConfig(int id);

  Future<String> fetchConfigFile(int id, String filename);

  Future<RoboClawConfig> cloneConfig(int id);

  // MCP catalog
  Future<List<McpCatalogEntry>> fetchMcpCatalog({String? query});

  // Scenarios
  Future<List<TestScenario>> fetchScenarios({
    String? robotName,
    String? environment,
  });

  Future<TestScenario> saveScenario(TestScenario scenario, bool isNew);

  Future<void> deleteScenario(int id);

  Future<void> activateScenario(int id);

  Future<TestScenario> cloneScenario(int id);

  // Backup
  Future<String> exportBackup({
    required bool includeSecrets,
    bool includeConfigs,
    bool includeScenarios,
  });

  Future<Map<String, dynamic>> validateImport(Map<String, dynamic> document);

  Future<Map<String, dynamic>> importBackup({
    required Map<String, dynamic> document,
    required String conflictPolicy,
    required String activationPolicy,
  });
}
