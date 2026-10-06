// frontend/test/peer_config_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/peer_config.dart';

void main() {
  group('PeerConfig', () {
    test('fromJson/toJson round-trip', () {
      final p = PeerConfig(
        name: 'robot_a',
        host: '192.168.1.100',
        port: 50051,
        description: 'desc',
        role: 'manipulator',
        capabilities: ['navigate', 'inspect'],
      );
      final decoded = PeerConfig.fromJson(p.toJson());
      expect(decoded.name, 'robot_a');
      expect(decoded.host, '192.168.1.100');
      expect(decoded.port, 50051);
      expect(decoded.description, 'desc');
      expect(decoded.role, 'manipulator');
      expect(decoded.capabilities, ['navigate', 'inspect']);
    });

    test('fromJson 은 agent_name 과 문자열 port 를 처리한다', () {
      final p = PeerConfig.fromJson({
        'agent_name': 'robot_b',
        'host': '10.0.0.1',
        'port': '50052',
      });
      expect(p.name, 'robot_b');
      expect(p.port, 50052);
    });

    test('fromJson/toJson 는 capabilities 를 보존한다', () {
      final p = PeerConfig.fromJson({
        'name': 'robot_c',
        'host': '10.0.0.3',
        'port': 50052,
        'capabilities': ['navigate', 'manipulate'],
      });

      expect(p.capabilities, ['navigate', 'manipulate']);
      expect(PeerConfig.fromJson(p.toJson()).capabilities, [
        'navigate',
        'manipulate',
      ]);
    });

    test('fromJson 은 잘못된 port 에 기본값을 사용한다', () {
      final p = PeerConfig.fromJson({'name': 'x', 'host': 'h', 'port': 'abc'});
      expect(p.port, 50051);
    });

    test('parsePeersJson 은 빈/잘못된 입력을 빈 목록으로 처리한다', () {
      expect(PeerConfig.parsePeersJson(''), isEmpty);
      expect(PeerConfig.parsePeersJson('[]'), isEmpty);
      expect(PeerConfig.parsePeersJson('{bad'), isEmpty);
    });

    test('parsePeersJson 은 유효한 목록을 파싱한다', () {
      final list = PeerConfig.parsePeersJson(
        '[{"name":"a","host":"h","port":50051}]',
      );
      expect(list, hasLength(1));
      expect(list.first.name, 'a');
    });

    test('serializePeersJson 은 JSON 문자열을 만든다', () {
      final json = PeerConfig.serializePeersJson([
        PeerConfig(name: 'a', host: 'h', port: 50051),
      ]);
      expect(json, contains('"agent_name":"a"'));
    });
  });
}
