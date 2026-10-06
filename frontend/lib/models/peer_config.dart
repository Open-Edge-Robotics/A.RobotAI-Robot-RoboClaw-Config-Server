import 'dart:convert';

class PeerConfig {
  String name;
  String host;
  int port;
  String description;
  String role;
  List<String> capabilities;

  PeerConfig({
    required this.name,
    required this.host,
    required this.port,
    this.description = '',
    this.role = '',
    this.capabilities = const [],
  });

  // Convert a JSON map to a PeerConfig instance.
  factory PeerConfig.fromJson(Map<String, dynamic> json) {
    return PeerConfig(
      name: json['name'] ?? json['agent_name'] ?? '',
      host: json['host'] ?? '',
      port: json['port'] is int
          ? json['port']
          : int.tryParse(json['port']?.toString() ?? '50051') ?? 50051,
      description: json['description'] ?? '',
      role: json['role'] ?? '',
      capabilities: (json['capabilities'] is List)
          ? (json['capabilities'] as List)
                .map((item) => item.toString())
                .toList()
          : const [],
    );
  }

  // Convert a PeerConfig instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'agent_name': name, // Maintain compatibility with client_node.py
      'host': host,
      'port': port,
      'description': description,
      'role': role,
      'capabilities': capabilities,
    };
  }

  // Helper method to parse a JSON string into a list of PeerConfig.
  static List<PeerConfig> parsePeersJson(String jsonStr) {
    if (jsonStr.isEmpty || jsonStr == '[]') {
      return [];
    }
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is List) {
        return decoded
            .map((item) => PeerConfig.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Ignore parse error and return empty list or fallback handling
    }
    return [];
  }

  // Helper method to serialize a list of PeerConfig into a JSON string.
  static String serializePeersJson(List<PeerConfig> peers) {
    final list = peers.map((p) => p.toJson()).toList();
    return json.encode(list);
  }
}
