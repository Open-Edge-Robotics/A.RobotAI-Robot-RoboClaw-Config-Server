// frontend/lib/services/api_service.dart
//
// 관리자 API 파사드.
//
// 실제 HTTP 로직은 api/http_admin_api.dart(HttpAdminApi)에 있다.
// 이 클래스는 기존 화면의 static 호출(ApiService.fetchConfigs() 등)을 그대로
// 유지하기 위한 얇은 래퍼다. 내부적으로 HttpAdminApi.instance 로 위임한다.
//
// TDD: Controller/Service 는 AdminApi 인터페이스에 의존하고, 테스트에서는
// FakeAdminApi 를 주입한다. HttpAdminApi 는 MockClient 로 검증한다.

import '../api/http_admin_api.dart';
import '../models/config_model.dart';
import '../models/mcp_catalog_entry.dart';
import '../models/scenario_model.dart';

export '../api/http_admin_api.dart' show ApiException;

class ApiService {
  static HttpAdminApi get _api => HttpAdminApi.instance;

  // ===== 토큰 =====

  static String? get adminToken => _api.adminToken;

  static void loadAdminTokenFromStorage() {
    _api.adminToken; // 읽기만 수행 (로깅은 HttpAdminApi 내부)
  }

  static void saveAdminTokenToStorage(String token) =>
      _api.saveAdminToken(token);

  static void clearAdminToken() => _api.clearAdminToken();

  // ===== Configs =====

  static Future<List<RoboClawConfig>> fetchConfigs({
    String? robotName,
    String? environment,
  }) => _api.fetchConfigs(robotName: robotName, environment: environment);

  static Future<RoboClawConfig> saveConfig(RoboClawConfig config, bool isNew) =>
      _api.saveConfig(config, isNew);

  static Future<void> deleteConfig(int id) => _api.deleteConfig(id);

  static Future<void> activateConfig(int id) => _api.activateConfig(id);

  static Future<String> fetchConfigFile(int id, String filename) =>
      _api.fetchConfigFile(id, filename);

  static Future<RoboClawConfig> cloneConfig(int id) => _api.cloneConfig(id);

  // ===== MCP catalog =====

  static Future<List<McpCatalogEntry>> fetchMcpCatalog({String? query}) =>
      _api.fetchMcpCatalog(query: query);

  // ===== Scenarios =====

  static Future<List<TestScenario>> fetchScenarios({
    String? robotName,
    String? environment,
  }) => _api.fetchScenarios(robotName: robotName, environment: environment);

  static Future<TestScenario> saveScenario(TestScenario scenario, bool isNew) =>
      _api.saveScenario(scenario, isNew);

  static Future<void> deleteScenario(int id) => _api.deleteScenario(id);

  static Future<void> activateScenario(int id) => _api.activateScenario(id);

  static Future<TestScenario> cloneScenario(int id) => _api.cloneScenario(id);

  // ===== Backup =====

  static Future<String> exportBackup({
    required bool includeSecrets,
    bool includeConfigs = true,
    bool includeScenarios = true,
  }) => _api.exportBackup(
    includeSecrets: includeSecrets,
    includeConfigs: includeConfigs,
    includeScenarios: includeScenarios,
  );

  static Future<Map<String, dynamic>> validateImport(
    Map<String, dynamic> document,
  ) => _api.validateImport(document);

  static Future<Map<String, dynamic>> importBackup({
    required Map<String, dynamic> document,
    required String conflictPolicy,
    required String activationPolicy,
  }) => _api.importBackup(
    document: document,
    conflictPolicy: conflictPolicy,
    activationPolicy: activationPolicy,
  );
}
