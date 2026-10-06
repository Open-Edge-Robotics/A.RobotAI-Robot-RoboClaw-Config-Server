import 'mcp_server_config.dart';

/// 백엔드 `GET /api/v1/mcp/catalog` 의 servers[] 항목.
/// handler/mcp_catalog.go 의 McpCatalogEntry 와 필드가 일치해야 한다.
class McpCatalogEntry {
  final String name;
  final String displayName;
  final String description;
  final String category;
  final String transport; // 'stdio' | 'sse' | 'streamable_http'
  final String command;
  final List<String> args;
  final Map<String, String> env;
  final String url;
  final String homepage;
  final String source; // 'builtin' | 'registry'

  McpCatalogEntry({
    required this.name,
    required this.displayName,
    required this.description,
    required this.category,
    required this.transport,
    this.command = '',
    this.args = const [],
    this.env = const {},
    this.url = '',
    this.homepage = '',
    this.source = 'builtin',
  });

  static List<String> _stringList(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];

  static Map<String, String> _stringMap(dynamic v) => v is Map
      ? v.map((k, val) => MapEntry(k.toString(), val.toString()))
      : const {};

  factory McpCatalogEntry.fromJson(Map<String, dynamic> json) {
    return McpCatalogEntry(
      name: json['name'] ?? '',
      displayName: (json['display_name'] ?? json['name'] ?? '').toString(),
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      transport: json['transport'] ?? 'stdio',
      command: json['command'] ?? '',
      args: _stringList(json['args']),
      env: _stringMap(json['env']),
      url: json['url'] ?? '',
      homepage: json['homepage'] ?? '',
      source: json['source'] ?? 'builtin',
    );
  }

  /// 카탈로그 항목을 편집 가능한 MCP 서버 설정으로 변환한다.
  /// [nameOverride] 로 중복 이름 회피 시 이름을 지정할 수 있다.
  McpServerConfig toServerConfig({String? nameOverride}) {
    return McpServerConfig(
      name: nameOverride ?? name,
      transport: transport,
      command: command,
      // 원본 리스트/맵을 공유하지 않도록 복사본 전달
      args: List<String>.from(args),
      env: Map<String, String>.from(env),
      url: url,
    );
  }
}
