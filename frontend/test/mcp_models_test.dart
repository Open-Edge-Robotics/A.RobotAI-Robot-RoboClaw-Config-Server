// frontend/test/mcp_models_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/mcp_catalog_entry.dart';
import 'package:frontend/models/mcp_server_config.dart';

void main() {
  group('McpCatalogEntry', () {
    test('fromJson 은 모든 필드를 파싱한다', () {
      final e = McpCatalogEntry.fromJson({
        'name': 'fs',
        'display_name': 'Filesystem',
        'description': 'desc',
        'category': 'storage',
        'transport': 'stdio',
        'command': 'npx',
        'args': ['-y', 'pkg'],
        'env': {'KEY': 'val'},
        'url': 'https://x',
        'homepage': 'https://h',
        'source': 'registry',
      });
      expect(e.name, 'fs');
      expect(e.displayName, 'Filesystem');
      expect(e.transport, 'stdio');
      expect(e.args, ['-y', 'pkg']);
      expect(e.env['KEY'], 'val');
      expect(e.source, 'registry');
    });

    test('fromJson 은 누락 필드에 기본값을 사용한다', () {
      final e = McpCatalogEntry.fromJson({'name': 'fs'});
      expect(e.displayName, 'fs');
      expect(e.transport, 'stdio');
      expect(e.args, isEmpty);
      expect(e.env, isEmpty);
      expect(e.source, 'builtin');
    });

    test('toServerConfig 는 MCP 서버 설정으로 변환한다', () {
      final e = McpCatalogEntry.fromJson({
        'name': 'fs',
        'transport': 'stdio',
        'command': 'npx',
        'args': ['-y', 'pkg'],
        'env': {'K': 'v'},
      });
      final s = e.toServerConfig(nameOverride: 'fs_2');
      expect(s.name, 'fs_2');
      expect(s.transport, 'stdio');
      expect(s.command, 'npx');
      expect(s.args, ['-y', 'pkg']);
      expect(s.env['K'], 'v');
    });
  });

  group('McpServerConfig', () {
    test('stdio round-trip', () {
      final s = McpServerConfig(
        name: 'fs',
        transport: 'stdio',
        command: 'npx',
        args: ['-y', 'pkg'],
        env: {'K': 'v'},
        cwd: '/tmp',
      );
      final decoded = McpServerConfig.fromJson(s.toJson());
      expect(decoded.name, 'fs');
      expect(decoded.transport, 'stdio');
      expect(decoded.command, 'npx');
      expect(decoded.args, ['-y', 'pkg']);
      expect(decoded.env['K'], 'v');
      expect(decoded.cwd, '/tmp');
    });

    test('sse round-trip', () {
      final s = McpServerConfig(
        name: 'sse',
        transport: 'sse',
        url: 'https://x/mcp',
        headers: {'A': 'b'},
        connectTimeoutSec: 3.0,
        readTimeoutSec: 60.0,
      );
      final decoded = McpServerConfig.fromJson(s.toJson());
      expect(decoded.transport, 'sse');
      expect(decoded.url, 'https://x/mcp');
      expect(decoded.headers['A'], 'b');
      expect(decoded.connectTimeoutSec, 3.0);
      expect(decoded.readTimeoutSec, 60.0);
    });

    test('streamable_http round-trip', () {
      final s = McpServerConfig(
        name: 'remote',
        transport: 'streamable_http',
        url: 'https://x/mcp',
        headers: {'Authorization': 'Bearer token'},
      );
      final decoded = McpServerConfig.fromJson(s.toJson());
      expect(decoded.transport, 'streamable_http');
      expect(decoded.url, 'https://x/mcp');
      expect(decoded.headers['Authorization'], 'Bearer token');
    });

    test('parseServersJson 은 빈/마스킹/잘못된 입력을 빈 목록으로 처리한다', () {
      expect(McpServerConfig.parseServersJson(''), isEmpty);
      expect(McpServerConfig.parseServersJson('[]'), isEmpty);
      expect(McpServerConfig.parseServersJson('********'), isEmpty);
      expect(McpServerConfig.parseServersJson('{bad'), isEmpty);
    });

    // 회귀: 예전에는 mcp_servers_json 전체가 "********" 로 내려와 등록한 서버가
    // 대시보드에 하나도 보이지 않았다. 자격 증명만 마스킹되면 서버는 보여야 한다.
    test('자격 증명만 마스킹된 목록은 서버 구조를 유지한 채 파싱된다', () {
      final list = McpServerConfig.parseServersJson(
        '[{"name":"fs","transport":"stdio","command":"npx","args":["-y","server-fs"],'
        '"env":{"GITHUB_TOKEN":"********","LOG_LEVEL":"********"}}]',
      );
      expect(list, hasLength(1));
      expect(list.first.name, 'fs');
      expect(list.first.command, 'npx');
      expect(list.first.args, ['-y', 'server-fs']);
      expect(list.first.env['GITHUB_TOKEN'], McpServerConfig.maskedValue);
    });

    test('containsMaskedSecrets 는 자격 증명 마스킹 여부를 판별한다', () {
      expect(
        McpServerConfig.containsMaskedSecrets(
          '[{"name":"fs","env":{"TOKEN":"********"}}]',
        ),
        isTrue,
      );
      expect(
        McpServerConfig.containsMaskedSecrets(
          '[{"name":"fs","env":{"TOKEN":"real"}}]',
        ),
        isFalse,
      );
      expect(McpServerConfig.containsMaskedSecrets('[]'), isFalse);
    });

    test('parseServersJson 은 유효한 목록을 파싱한다', () {
      final list = McpServerConfig.parseServersJson(
        '[{"name":"fs","transport":"stdio","command":"npx"}]',
      );
      expect(list, hasLength(1));
      expect(list.first.name, 'fs');
    });

    test('serializeServersJson 은 JSON 문자열을 만든다', () {
      final json = McpServerConfig.serializeServersJson([
        McpServerConfig(name: 'fs', transport: 'stdio', command: 'npx'),
      ]);
      expect(json, contains('"name":"fs"'));
    });
  });
}
