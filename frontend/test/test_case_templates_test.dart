// frontend/test/test_case_templates_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/test_case_templates.dart';

void main() {
  group('createTestCaseTemplate', () {
    test('각 유형별 템플릿을 생성하고 suffix 를 적용한다', () {
      expect(createTestCaseTemplate('ping', 1).id, 'tc_ping_1');
      expect(createTestCaseTemplate('ping', 1).type, 'ping');
      expect(createTestCaseTemplate('robot_info', 2).id, 'tc_robot_info_2');
      expect(createTestCaseTemplate('battery', 3).id, 'tc_battery_3');
      expect(createTestCaseTemplate('camera', 4).id, 'tc_camera_4');
      expect(createTestCaseTemplate('map', 5).id, 'tc_slam_map_5');
      expect(
        createTestCaseTemplate('camera_analysis', 6).id,
        'tc_camera_analysis_6',
      );
      expect(createTestCaseTemplate('map_analysis', 7).id, 'tc_map_analysis_7');
      expect(createTestCaseTemplate('navigation', 8).id, 'tc_guardrail_8');
      expect(
        createTestCaseTemplate('manipulation', 9).id,
        'tc_joint_control_9',
      );
      expect(createTestCaseTemplate('persona', 10).id, 'tc_persona_10');
      expect(createTestCaseTemplate('custom', 11).id, 'tc_custom_11');
    });

    test('navigation 템플릿에 params 가 포함된다', () {
      final tc = createTestCaseTemplate('navigation', 1);
      expect(tc.params['mode'], 'guardrail');
      expect(tc.params['speed'], 0.05);
    });

    test('persona 템플릿에 prompt 가 포함된다', () {
      final tc = createTestCaseTemplate('persona', 1);
      expect(tc.params['prompt'], isNotEmpty);
    });

    test('custom 템플릿에 기본 params 가 포함된다', () {
      final tc = createTestCaseTemplate('custom', 1);
      expect(tc.params['expect_success'], isTrue);
      expect(tc.params['expected_keywords'], isA<List>());
    });
  });

  group('defaultParamsForTestCaseType', () {
    test('navigation 은 guardrail params 를 반환한다', () {
      final p = defaultParamsForTestCaseType('navigation');
      expect(p['mode'], 'guardrail');
      expect(p['speed'], 0.05);
    });

    test('persona 는 prompt 를 반환한다', () {
      final p = defaultParamsForTestCaseType('persona');
      expect(p['prompt'], isNotEmpty);
    });

    test('custom 은 기본 params 를 반환한다', () {
      final p = defaultParamsForTestCaseType('custom');
      expect(p['expect_success'], isTrue);
    });

    test('그 외 유형은 빈 맵을 반환한다', () {
      expect(defaultParamsForTestCaseType('ping'), isEmpty);
      expect(defaultParamsForTestCaseType('camera'), isEmpty);
    });
  });
}
