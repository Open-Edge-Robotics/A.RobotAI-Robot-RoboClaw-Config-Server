import '../models/scenario_model.dart';

const testCaseTypeDescriptions = <String, String>{
  'ping': '로봇 gRPC Ping 연결성 테스트',
  'robot_info': '로봇 정보 조회 API 및 프로필 정합성 검증',
  'battery': '배터리 잔량 확인 (10% 미만 시 경고)',
  'camera': '카메라 스트림 및 이미지 디코딩 검증',
  'map': 'SLAM 맵 데이터 격자 정보 수신 검증',
  'camera_analysis': 'AI 비전 분석 스킬 및 파일 연동 검증',
  'map_analysis': 'AI 지도 분석 스킬 및 파일 연동 검증',
  'navigation': '가드레일 속도 제한 또는 주행 스킬 기동 테스트',
  'manipulation': '매니퓰레이터 관절 구동 및 제어 테스트',
  'persona': 'LLM 페르소나 정체성 및 응답 지능 검증',
  'custom': '사용자 정의 프롬프트 전송 및 키워드 검증',
};

TestCase createTestCaseTemplate(String type, int suffix) {
  switch (type) {
    case 'ping':
      return TestCase(
        id: 'tc_ping_$suffix',
        name: 'gRPC Ping 연결성',
        step: 'Step $suffix',
        type: 'ping',
        timeoutMs: 3000,
      );
    case 'robot_info':
      return TestCase(
        id: 'tc_robot_info_$suffix',
        name: '로봇 정보 조회 및 정합성',
        step: 'Step $suffix',
        type: 'robot_info',
        timeoutMs: 3000,
      );
    case 'battery':
      return TestCase(
        id: 'tc_battery_$suffix',
        name: '배터리 상태 점검',
        step: 'Step $suffix',
        type: 'battery',
        timeoutMs: 10000,
      );
    case 'camera':
      return TestCase(
        id: 'tc_camera_$suffix',
        name: '카메라 이미지 획득',
        step: 'Step $suffix',
        type: 'camera',
        timeoutMs: 5000,
      );
    case 'map':
      return TestCase(
        id: 'tc_slam_map_$suffix',
        name: 'SLAM 지도 맵 수신',
        step: 'Step $suffix',
        type: 'map',
        timeoutMs: 5000,
      );
    case 'camera_analysis':
      return TestCase(
        id: 'tc_camera_analysis_$suffix',
        name: '카메라 이미지 분석 스킬',
        step: 'Step $suffix',
        type: 'camera_analysis',
        timeoutMs: 25000,
      );
    case 'map_analysis':
      return TestCase(
        id: 'tc_map_analysis_$suffix',
        name: '맵 이미지 분석 스킬',
        step: 'Step $suffix',
        type: 'map_analysis',
        timeoutMs: 25000,
      );
    case 'navigation':
      return TestCase(
        id: 'tc_guardrail_$suffix',
        name: '물리 가드레일 속도 제약',
        step: 'Step $suffix',
        type: 'navigation',
        timeoutMs: 15000,
        params: {'mode': 'guardrail', 'speed': 0.05},
      );
    case 'manipulation':
      return TestCase(
        id: 'tc_joint_control_$suffix',
        name: '매니퓰레이션 관절 구동 검증',
        step: 'Step $suffix',
        type: 'manipulation',
        timeoutMs: 15000,
      );
    case 'persona':
      return TestCase(
        id: 'tc_persona_$suffix',
        name: 'LLM 페르소나 검증',
        step: 'Step $suffix',
        type: 'persona',
        timeoutMs: 15000,
        params: {'prompt': '너의 정체성과 성격에 대해 한 문장으로 답변해줘.'},
      );
    case 'custom':
    default:
      return TestCase(
        id: 'tc_custom_$suffix',
        name: '사용자 정의 프롬프트 테스트',
        step: 'Step $suffix',
        type: 'custom',
        timeoutMs: 15000,
        params: {
          'prompt': '로봇에게 전달할 프롬프트 입력',
          'expect_success': true,
          'expected_keywords': ['성공'],
          'fail_keywords': ['실패'],
        },
      );
  }
}

Map<String, dynamic> defaultParamsForTestCaseType(String type) {
  switch (type) {
    case 'navigation':
      return {'mode': 'guardrail', 'speed': 0.05};
    case 'persona':
      return {'prompt': '너의 정체성과 성격에 대해 한 문장으로 답변해줘.'};
    case 'custom':
      return {
        'prompt': '프롬프트 입력',
        'expect_success': true,
        'expected_keywords': [],
        'fail_keywords': [],
      };
    default:
      return {};
  }
}
