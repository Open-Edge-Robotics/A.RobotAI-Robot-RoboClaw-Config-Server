import 'dart:convert';

import '../models/scenario_model.dart';

const Map<String, String> scenarioTestTypeGuideDescriptions = {
  'ping': '로봇 gRPC Ping 연결성 테스트 (실패 시 메신저 대체 통신)',
  'robot_info': '로봇 정보 조회 API 호출 및 프로필 비교 정합성 테스트 (RosGrpc 전용)',
  'battery': '로봇 배터리 상태 점검 (10% 미만 시 WARNING 분류)',
  'camera': '카메라 이미지 수신 및 디코딩 검증',
  'map': 'SLAM 맵 데이터 및 격자 정보 수신 검증 (RosGrpc 전용)',
  'camera_analysis': '메신저 채널을 통해 카메라 이미지 분석 AI 스킬 및 파일 연동 검증',
  'map_analysis': '메신저 채널을 통해 지도 이미지 분석 AI 스킬 및 파일 연동 검증',
  'navigation':
      '가드레일 속도 제한 검증 또는 자연어 주행 스킬 기동 테스트\n'
      '- Params:\n'
      '  • mode: "guardrail" 또는 "motion"\n'
      '  • speed (double): "guardrail" 모드 시 속도 제한 (m/s)\n'
      '  • command (string): "motion" 모드 시 로봇 이동 지시 자연어',
  'manipulation':
      '로봇 매니퓰레이터 관절 구동 및 제어 동작 테스트\n'
      '- Params:\n'
      '  • command (string): 메신저 챗 모드 시 매니퓰레이터 기동 자연어',
  'persona':
      'LLM 에이전트 정체성(성격) 검증\n'
      '- Params:\n'
      '  • prompt (string): 에이전트에게 전달할 정체성 질문 텍스트',
  'custom':
      '사용자 정의 임의 프롬프트 전송 및 검증\n'
      '- Params:\n'
      '  • prompt (string): 로봇 에이전트에 전달할 자연어 프롬프트 (필수)\n'
      '  • expect_success (bool): 성공 여부 기대값 (선택, 기본: true)\n'
      '  • expected_keywords (List<String>): 포함되어야 하는 키워드 목록 (선택)\n'
      '  • fail_keywords (List<String>): 포함되지 않아야 하는 키워드 목록 (선택)',
};

const JsonEncoder _testCaseJsonEncoder = JsonEncoder.withIndent('  ');

List<TestCase> parseScenarioTestCasesJson(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    throw const FormatException('최상위 노드는 배열(List) 형식이어야 합니다.');
  }

  return decoded
      .map((item) => TestCase.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

String encodeScenarioTestCasesJson(List<TestCase> testCases) {
  return _testCaseJsonEncoder.convert(
    testCases.map((testCase) => testCase.toJson()).toList(),
  );
}

String appendScenarioTestCaseTemplate({
  required String currentText,
  required String type,
}) {
  final template = buildScenarioTestCaseTemplate(type);
  final normalized = currentText.trim().isEmpty ? '[]' : currentText.trim();

  try {
    final decoded = jsonDecode(normalized);
    if (decoded is! List) {
      throw const FormatException('JSON이 배열([ ]) 형식이 아닙니다.');
    }

    decoded.add(template);
    return _testCaseJsonEncoder.convert(decoded);
  } catch (error) {
    if (!normalized.endsWith(']')) {
      throw FormatException('JSON 문법 오류로 템플릿을 자동으로 추가할 수 없습니다: $error');
    }

    final lastBracketIndex = normalized.lastIndexOf(']');
    final prefix = normalized.substring(0, lastBracketIndex).trim();
    final templateJson = _testCaseJsonEncoder.convert(template);

    if (prefix == '[') {
      return '[\n$templateJson\n]';
    }

    final hasComma = prefix.endsWith(',');
    return '$prefix${hasComma ? '' : ','}\n$templateJson\n]';
  }
}

Map<String, dynamic> buildScenarioTestCaseTemplate(String type) {
  switch (type) {
    case 'ping':
      return {
        'id': 'tc_ping',
        'name': 'gRPC Ping 연결성',
        'step': 'Step 1',
        'type': 'ping',
        'timeout_ms': 3000,
        'enabled': true,
      };
    case 'robot_info':
      return {
        'id': 'tc_robot_info',
        'name': '로봇 정보 조회 및 정합성',
        'step': 'Step 1',
        'type': 'robot_info',
        'timeout_ms': 3000,
        'enabled': true,
      };
    case 'battery':
      return {
        'id': 'tc_battery',
        'name': '배터리 상태 점검',
        'step': 'Step 1',
        'type': 'battery',
        'timeout_ms': 10000,
        'enabled': true,
      };
    case 'camera':
      return {
        'id': 'tc_camera',
        'name': '카메라 이미지 획득',
        'step': 'Step 2',
        'type': 'camera',
        'timeout_ms': 5000,
        'enabled': true,
      };
    case 'map':
      return {
        'id': 'tc_slam_map',
        'name': 'SLAM 지도 맵 수신',
        'step': 'Step 2',
        'type': 'map',
        'timeout_ms': 5000,
        'enabled': true,
      };
    case 'camera_analysis':
      return {
        'id': 'tc_camera_analysis',
        'name': '카메라 이미지 분석 및 전달 스킬',
        'step': 'Step 2',
        'type': 'camera_analysis',
        'timeout_ms': 25000,
        'enabled': true,
      };
    case 'map_analysis':
      return {
        'id': 'tc_map_analysis',
        'name': '맵 이미지 분석 및 전달 스킬',
        'step': 'Step 2',
        'type': 'map_analysis',
        'timeout_ms': 25000,
        'enabled': true,
      };
    case 'navigation':
      return {
        'id': 'tc_guardrail',
        'name': '물리 가드레일 속도 제약',
        'step': 'Step 3',
        'type': 'navigation',
        'timeout_ms': 15000,
        'enabled': true,
        'params': {'mode': 'guardrail', 'speed': 0.05},
      };
    case 'manipulation':
      return {
        'id': 'tc_joint_control',
        'name': '매니퓰레이션 관절 구동 검증',
        'step': 'Step 3',
        'type': 'manipulation',
        'timeout_ms': 15000,
        'enabled': true,
      };
    case 'persona':
      return {
        'id': 'tc_persona',
        'name': 'LLM 페르소나 및 응답 지능',
        'step': 'Step 4',
        'type': 'persona',
        'timeout_ms': 15000,
        'enabled': true,
        'params': {'prompt': '너의 정체성과 성격에 대해 한 문장으로 답변해줘.'},
      };
    case 'custom':
      return {
        'id': 'tc_custom_example',
        'name': '사용자 정의 프롬프트 테스트',
        'step': 'Step 4',
        'type': 'custom',
        'timeout_ms': 15000,
        'enabled': true,
        'params': {
          'prompt': '로봇에게 전달할 프롬프트 입력',
          'expect_success': true,
          'expected_keywords': ['성공키워드1'],
          'fail_keywords': ['실패키워드1'],
        },
      };
  }

  throw ArgumentError.value(type, 'type', '지원하지 않는 테스트 케이스 유형입니다.');
}
