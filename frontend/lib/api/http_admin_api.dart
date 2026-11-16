// frontend/lib/api/http_admin_api.dart
//
// AdminApi 의 HTTP 구현. http.Client 와 TokenStore 를 주입받는다.
// 테스트에서는 MockClient(http/testing) 로 교체할 수 있다.
//
// 모든 HTTP 호출에는 requestTimeout(기본 20초) 상한을 둔다. 초과 시
// TimeoutException 이 그대로 전파되며, 이 계층에서는 로깅하지 않는다.
// 오류 기록은 Controller 경계에서 한 번만 수행한다.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/config_model.dart';
import '../models/mcp_catalog_entry.dart';
import '../models/scenario_model.dart';
import '../services/logger.dart';
import '../storage/token_store.dart';
import 'admin_api.dart';
import 'api_exception.dart';

// 기존 경로(package:frontend/api/http_admin_api.dart)로 ApiException 을 계속
// 사용할 수 있도록 중립 타입을 다시 내보낸다.
export 'api_exception.dart';

class HttpAdminApi implements AdminApi {
  final http.Client _client;
  final TokenStore _tokenStore;
  final String _basePath;
  final Duration _requestTimeout;

  HttpAdminApi({
    required http.Client client,
    required TokenStore tokenStore,
    String basePath = '/api/v1/admin',
    Duration requestTimeout = const Duration(seconds: 20),
  }) : this._(client, tokenStore, basePath, requestTimeout);

  HttpAdminApi._(
    this._client,
    this._tokenStore,
    this._basePath,
    this._requestTimeout,
  );

  /// 전역 기본 인스턴스. main() 에서 구성한다.
  static HttpAdminApi instance = HttpAdminApi(
    client: http.Client(),
    tokenStore: _NoopTokenStore(),
  );

  // ===== 토큰 접근 =====

  String? get adminToken => _tokenStore.read();

  void saveAdminToken(String token) => _tokenStore.write(token);

  void clearAdminToken() => _tokenStore.clear();

  Map<String, String> _getHeaders() {
    final token = _tokenStore.read();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<List<RoboClawConfig>> fetchConfigs({
    String? robotName,
    String? environment,
  }) async {
    final queryParams = <String, String>{};
    if (robotName != null && robotName.isNotEmpty) {
      queryParams['robot_name'] = robotName;
    }
    if (environment != null && environment.isNotEmpty) {
      queryParams['environment'] = environment;
    }

    final uri = Uri.parse(
      '$_basePath/configs',
    ).replace(queryParameters: queryParams);
    AppLogger.info('GET: $uri');

    final response = await _client
        .get(uri, headers: _getHeaders())
        .timeout(_requestTimeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => RoboClawConfig.fromJson(json)).toList();
    }
    throw ApiException(
      '설정 목록 조회 실패',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  @override
  Future<RoboClawConfig> saveConfig(RoboClawConfig config, bool isNew) async {
    final url = isNew
        ? Uri.parse('$_basePath/configs')
        : Uri.parse('$_basePath/configs/${config.id}');
    final body = jsonEncode(config.toJson());
    AppLogger.info('${isNew ? "POST" : "PUT"}: $url');

    final response = isNew
        ? await _client
              .post(url, headers: _getHeaders(), body: body)
              .timeout(_requestTimeout)
        : await _client
              .put(url, headers: _getHeaders(), body: body)
              .timeout(_requestTimeout);
    if (response.statusCode == 200 || response.statusCode == 201) {
      AppLogger.info('Save successful. ID: ${config.id ?? "NEW"}');
      return RoboClawConfig.fromJson(jsonDecode(response.body));
    }
    throw ApiException(
      '설정 저장 실패',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  @override
  Future<void> deleteConfig(int id) async {
    final url = Uri.parse('$_basePath/configs/$id');
    AppLogger.info('DELETE: $url');
    final response = await _client
        .delete(url, headers: _getHeaders())
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw ApiException(
        '설정 삭제 실패',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    AppLogger.info('Deleted config ID: $id');
  }

  @override
  Future<void> activateConfig(int id) async {
    final url = Uri.parse('$_basePath/configs/$id/activate');
    AppLogger.info('POST (activate): $url');
    final response = await _client
        .post(url, headers: _getHeaders())
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw ApiException(
        '설정 활성화 실패',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    AppLogger.info('Activated config ID: $id');
  }

  @override
  Future<String> fetchConfigFile(int id, String filename) async {
    final url = Uri.parse('$_basePath/configs/$id/files/$filename');
    AppLogger.info('GET (file): $url');
    final response = await _client
        .get(url, headers: _getHeaders())
        .timeout(_requestTimeout);
    if (response.statusCode == 200) {
      return response.body;
    }
    throw ApiException(
      '설정 파일 조회 실패',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  @override
  Future<RoboClawConfig> cloneConfig(int id) async {
    final url = Uri.parse('$_basePath/configs/$id/clone');
    AppLogger.info('POST (clone): $url');
    final response = await _client
        .post(url, headers: _getHeaders())
        .timeout(_requestTimeout);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final cloned = RoboClawConfig.fromJson(jsonDecode(response.body));
      AppLogger.info('Cloned config ID: $id -> ${cloned.id}');
      return cloned;
    }
    throw ApiException(
      '설정 복제 실패',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  @override
  Future<List<McpCatalogEntry>> fetchMcpCatalog({String? query}) async {
    final queryParams = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      queryParams['q'] = query.trim();
    }
    final uri = Uri.parse(
      '$_basePath/mcp/catalog',
    ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    AppLogger.info('GET: $uri');
    final response = await _client
        .get(uri, headers: _getHeaders())
        .timeout(_requestTimeout);
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> servers = data['servers'] as List<dynamic>? ?? [];
      return servers
          .map((e) => McpCatalogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(
      'MCP 카탈로그 조회 실패',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  @override
  Future<List<TestScenario>> fetchScenarios({
    String? robotName,
    String? environment,
  }) async {
    final queryParams = <String, String>{};
    if (robotName != null && robotName.isNotEmpty) {
      queryParams['robot_name'] = robotName;
    }
    if (environment != null && environment.isNotEmpty) {
      queryParams['environment'] = environment;
    }
    final uri = Uri.parse(
      '$_basePath/scenarios',
    ).replace(queryParameters: queryParams);
    AppLogger.info('GET: $uri');
    final response = await _client
        .get(uri, headers: _getHeaders())
        .timeout(_requestTimeout);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => TestScenario.fromJson(json)).toList();
    }
    throw ApiException(
      '테스트 시나리오 목록 조회 실패',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  @override
  Future<TestScenario> saveScenario(TestScenario scenario, bool isNew) async {
    final url = isNew
        ? Uri.parse('$_basePath/scenarios')
        : Uri.parse('$_basePath/scenarios/${scenario.id}');
    final body = jsonEncode(scenario.toJson());
    AppLogger.info('${isNew ? "POST" : "PUT"}: $url');
    final response = isNew
        ? await _client
              .post(url, headers: _getHeaders(), body: body)
              .timeout(_requestTimeout)
        : await _client
              .put(url, headers: _getHeaders(), body: body)
              .timeout(_requestTimeout);
    if (response.statusCode == 200 || response.statusCode == 201) {
      AppLogger.info('Save successful. ID: ${scenario.id ?? "NEW"}');
      return TestScenario.fromJson(jsonDecode(response.body));
    }
    throw ApiException(
      '테스트 시나리오 저장 실패',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  @override
  Future<void> deleteScenario(int id) async {
    final url = Uri.parse('$_basePath/scenarios/$id');
    AppLogger.info('DELETE: $url');
    final response = await _client
        .delete(url, headers: _getHeaders())
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw ApiException(
        '테스트 시나리오 삭제 실패',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    AppLogger.info('Deleted scenario ID: $id');
  }

  @override
  Future<void> activateScenario(int id) async {
    final url = Uri.parse('$_basePath/scenarios/$id/activate');
    AppLogger.info('POST (activate): $url');
    final response = await _client
        .post(url, headers: _getHeaders())
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw ApiException(
        '테스트 시나리오 활성화 실패',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    AppLogger.info('Activated scenario ID: $id');
  }

  @override
  Future<TestScenario> cloneScenario(int id) async {
    final url = Uri.parse('$_basePath/scenarios/$id/clone');
    AppLogger.info('POST (clone): $url');
    final response = await _client
        .post(url, headers: _getHeaders())
        .timeout(_requestTimeout);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final cloned = TestScenario.fromJson(jsonDecode(response.body));
      AppLogger.info('Cloned scenario ID: $id -> ${cloned.id}');
      return cloned;
    }
    throw ApiException(
      '테스트 시나리오 복제 실패',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  @override
  Future<String> exportBackup({
    required bool includeSecrets,
    bool includeConfigs = true,
    bool includeScenarios = true,
  }) async {
    final url = Uri.parse('$_basePath/transfer/export');
    final body = jsonEncode({
      'include_secrets': includeSecrets,
      'include_configs': includeConfigs,
      'include_scenarios': includeScenarios,
    });
    AppLogger.info('POST (export): $url');
    final response = await _client
        .post(url, headers: _getHeaders(), body: body)
        .timeout(_requestTimeout);
    if (response.statusCode == 200) {
      return response.body;
    }
    throw ApiException(
      '백업 내보내기 실패',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  @override
  Future<Map<String, dynamic>> validateImport(
    Map<String, dynamic> document,
  ) async {
    final url = Uri.parse('$_basePath/transfer/import/validate');
    final body = jsonEncode({'document': document});
    AppLogger.info('POST (validate): $url');
    final response = await _client
        .post(url, headers: _getHeaders(), body: body)
        .timeout(_requestTimeout);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw ApiException(
      '백업 검증 실패',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  @override
  Future<Map<String, dynamic>> importBackup({
    required Map<String, dynamic> document,
    required String conflictPolicy,
    required String activationPolicy,
  }) async {
    final url = Uri.parse('$_basePath/transfer/import');
    final body = jsonEncode({
      'document': document,
      'options': {
        'conflict_policy': conflictPolicy,
        'activation_policy': activationPolicy,
      },
    });
    AppLogger.info('POST (import): $url');
    final response = await _client
        .post(url, headers: _getHeaders(), body: body)
        .timeout(_requestTimeout);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw ApiException(
      '백업 가져오기 실패',
      statusCode: response.statusCode,
      body: response.body,
    );
  }
}

/// 기본 인스턴스가 초기화되기 전에 접근될 때 사용하는 무동작 저장소.
class _NoopTokenStore implements TokenStore {
  @override
  String? read() => null;

  @override
  void write(String token) {}

  @override
  void clear() {}
}
