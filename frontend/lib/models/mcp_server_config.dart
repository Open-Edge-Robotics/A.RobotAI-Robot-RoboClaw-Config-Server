import 'dart:convert';

/// mcp_adapter.py::MCPManager._open_transport가 파싱하는 형식과 반드시 일치해야 합니다.
class McpServerConfig {
  /// 서버 응답에서 자격 증명 값을 대신하는 마스킹 문자열.
  static const String maskedValue = '********';

  String name;
  String transport; // 'stdio' | 'sse' | 'streamable_http'

  // stdio 전송 설정
  String command;
  List<String> args;
  Map<String, String> env;
  String cwd;

  // sse 전송 설정
  String url;
  Map<String, String> headers;
  double connectTimeoutSec;
  double readTimeoutSec;

  McpServerConfig({
    required this.name,
    this.transport = 'stdio',
    this.command = '',
    this.args = const [],
    this.env = const {},
    this.cwd = '',
    this.url = '',
    this.headers = const {},
    this.connectTimeoutSec = 5.0,
    this.readTimeoutSec = 300.0,
  });

  static Map<String, String> _stringMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  factory McpServerConfig.fromJson(Map<String, dynamic> json) {
    return McpServerConfig(
      name: json['name'] ?? '',
      transport: json['transport'] ?? 'stdio',
      command: json['command'] ?? '',
      args: _stringList(json['args']),
      env: _stringMap(json['env']),
      cwd: json['cwd'] ?? '',
      url: json['url'] ?? '',
      headers: _stringMap(json['headers']),
      connectTimeoutSec: (json['connect_timeout_sec'] ?? 5.0).toDouble(),
      readTimeoutSec: (json['read_timeout_sec'] ?? 300.0).toDouble(),
    );
  }

  // 선택된 transport와 무관한 키는 생략하여 mcp_adapter.py가 기대하는 형태를 유지합니다.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'name': name, 'transport': transport};
    if (transport == 'stdio') {
      map['command'] = command;
      if (args.isNotEmpty) map['args'] = args;
      if (env.isNotEmpty) map['env'] = env;
      if (cwd.isNotEmpty) map['cwd'] = cwd;
    } else if (transport == 'sse' || transport == 'streamable_http') {
      map['url'] = url;
      if (headers.isNotEmpty) map['headers'] = headers;
      map['connect_timeout_sec'] = connectTimeoutSec;
      map['read_timeout_sec'] = readTimeoutSec;
    }
    return map;
  }

  // 백엔드는 MCP 서버 구조(name/transport/command/args/cwd/url)를 그대로 내려주고
  // 자격 증명(env/headers 값)만 "********" 로 마스킹한다. 구버전 응답처럼 JSON 전체가
  // 마스킹된 경우("********")에는 파싱할 수 없으므로 예외 대신 빈 리스트로 처리한다.
  static List<McpServerConfig> parseServersJson(String jsonStr) {
    if (jsonStr.isEmpty || jsonStr == '[]' || jsonStr == maskedValue) {
      return [];
    }
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is List) {
        return decoded
            .map(
              (item) => McpServerConfig.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (e) {
      // 파싱 실패 시 빈 목록으로 대체
    }
    return [];
  }

  static String serializeServersJson(List<McpServerConfig> servers) {
    final list = servers.map((s) => s.toJson()).toList();
    return json.encode(list);
  }

  /// 목록에 마스킹된 자격 증명이 남아 있는지 확인한다.
  ///
  /// true 이면 대시보드에 "마스킹된 값은 그대로 두면 기존 값이 유지된다"는
  /// 안내를 보여준다.
  static bool containsMaskedSecrets(String jsonStr) {
    return jsonStr.contains(maskedValue);
  }
}
