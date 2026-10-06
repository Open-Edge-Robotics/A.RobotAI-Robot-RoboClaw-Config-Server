// frontend/test/scenario_editor_utils_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/scenario_model.dart';
import 'package:frontend/utils/scenario_editor_utils.dart';

void main() {
  group('parseScenarioTestCasesJson', () {
    test('유효한 배열을 파싱한다', () {
      final list = parseScenarioTestCasesJson(
        '[{"id":"tc1","name":"Ping","type":"ping","enabled":true}]',
      );
      expect(list, hasLength(1));
      expect(list.first.id, 'tc1');
      expect(list.first.type, 'ping');
    });

    test('최상위가 배열이 아니면 예외를 던진다', () {
      expect(
        () => parseScenarioTestCasesJson('{"a":1}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('잘못된 JSON 이면 예외를 던진다', () {
      expect(
        () => parseScenarioTestCasesJson('{bad'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('encodeScenarioTestCasesJson', () {
    test('TestCase 목록을 JSON 문자열로 인코딩한다', () {
      final json = encodeScenarioTestCasesJson([
        TestCase(id: 'tc1', name: 'Ping', step: 'Step 1', type: 'ping'),
      ]);
      expect(json, contains('"id": "tc1"'));
      expect(json, contains('"type": "ping"'));
    });

    test('round-trip 이 값을 보존한다', () {
      final original = [
        TestCase(
          id: 'tc1',
          name: 'Ping',
          step: 'Step 1',
          type: 'ping',
          timeoutMs: 3000,
          enabled: true,
          params: {'mode': 'fast'},
        ),
      ];
      final decoded = parseScenarioTestCasesJson(
        encodeScenarioTestCasesJson(original),
      );
      expect(decoded.first.id, 'tc1');
      expect(decoded.first.params['mode'], 'fast');
    });
  });

  group('buildScenarioTestCaseTemplate', () {
    test('각 유형별 템플릿을 생성한다', () {
      expect(buildScenarioTestCaseTemplate('ping')['type'], 'ping');
      expect(buildScenarioTestCaseTemplate('robot_info')['type'], 'robot_info');
      expect(buildScenarioTestCaseTemplate('battery')['type'], 'battery');
      expect(buildScenarioTestCaseTemplate('camera')['type'], 'camera');
      expect(buildScenarioTestCaseTemplate('map')['type'], 'map');
      expect(
        buildScenarioTestCaseTemplate('camera_analysis')['type'],
        'camera_analysis',
      );
      expect(
        buildScenarioTestCaseTemplate('map_analysis')['type'],
        'map_analysis',
      );
      expect(buildScenarioTestCaseTemplate('navigation')['type'], 'navigation');
      expect(
        buildScenarioTestCaseTemplate('manipulation')['type'],
        'manipulation',
      );
      expect(buildScenarioTestCaseTemplate('persona')['type'], 'persona');
      expect(buildScenarioTestCaseTemplate('custom')['type'], 'custom');
    });

    test('navigation 템플릿에 params 가 포함된다', () {
      final t = buildScenarioTestCaseTemplate('navigation');
      expect(t['params'], isA<Map<String, dynamic>>());
      expect((t['params'] as Map)['mode'], 'guardrail');
    });

    test('지원하지 않는 유형이면 예외를 던진다', () {
      expect(
        () => buildScenarioTestCaseTemplate('unknown'),
        throwsArgumentError,
      );
    });
  });

  group('appendScenarioTestCaseTemplate', () {
    test('빈 문자열이면 템플릿을 추가한다', () {
      final result = appendScenarioTestCaseTemplate(
        currentText: '',
        type: 'ping',
      );
      expect(result, contains('"type": "ping"'));
    });

    test('유효한 배열에 템플릿을 추가한다', () {
      final result = appendScenarioTestCaseTemplate(
        currentText: '[{"id":"tc1","name":"a","type":"ping"}]',
        type: 'battery',
      );
      final decoded = parseScenarioTestCasesJson(result);
      expect(decoded, hasLength(2));
      expect(decoded.last.type, 'battery');
    });

    test('배열이 아닌 JSON 이면 예외를 던진다', () {
      expect(
        () => appendScenarioTestCaseTemplate(
          currentText: '{"a":1}',
          type: 'ping',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('잘못된 JSON 이면 예외를 던진다', () {
      expect(
        () => appendScenarioTestCaseTemplate(currentText: '{bad', type: 'ping'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
