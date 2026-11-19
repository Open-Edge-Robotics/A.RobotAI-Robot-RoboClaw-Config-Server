// frontend/lib/utils/localization.dart
//
// 위젯이 번역 문구를 읽는 전역 파사드.
// 언어 선택의 소유자는 LanguageController 이며, 이 클래스는 현재 코드 값을
// 노출하고 번역을 제공하는 얇은 어댑터로만 동작한다.

import 'package:material_ui/material_ui.dart';

class LanguageManager {
  static final ValueNotifier<String> languageCodeNotifier =
      ValueNotifier<String>('ko');

  static String get languageCode => languageCodeNotifier.value;

  static set languageCode(String code) {
    languageCodeNotifier.value = code;
  }

  static bool get isKo => languageCode == 'ko';

  static String tr(String text) {
    if (isKo) return text;
    return _translations[text] ?? text;
  }

  /// `{name}` 자리표시자를 가진 문구를 번역한 뒤 실제 값을 채운다.
  ///
  /// 값이 보간된 문자열은 번역 표의 키와 일치하지 않으므로, 보간 전
  /// 템플릿을 키로 넘겨야 한다.
  static String trTemplate(String template, Map<String, Object?> values) {
    var text = tr(template);
    values.forEach((key, value) {
      text = text.replaceAll('{$key}', '${value ?? ''}');
    });
    return text;
  }

  /// 번역 표에 [text] 키가 있는지 확인한다(테스트 감사용).
  static bool hasTranslation(String text) => _translations.containsKey(text);

  /// 번역 표 전체(읽기 전용). 테스트에서 값 검증에 쓴다.
  static Map<String, String> get allTranslations =>
      Map<String, String>.unmodifiable(_translations);

  static final Map<String, String> _translations = {
    // Dashboard Header / Navigation
    'AI 에이전트 설정 대시보드': 'AI Agent Config Dashboard',
    'AI Agent Config Dashboard': 'AI Agent Config Dashboard',
    '설정 관리': 'Configs',
    '시나리오': 'Scenarios',
    '라이트 모드 전환': 'Switch to Light Mode',
    '다크 모드 전환': 'Switch to Dark Mode',
    '관리자 토큰 설정': 'Admin Token Settings',
    '새로고침': 'Refresh',

    // Auth Dialog
    '관리자 인증 토큰 입력': 'Enter Admin Auth Token',
    '서버 API 보안 인증이 활성화되어 있습니다.\n대시보드 데이터를 가져오기 위해 admin_token을 입력해 주세요.':
        'Server API security authentication is enabled.\nPlease enter admin_token to retrieve dashboard data.',
    'admin_token 값을 입력하세요': 'Enter admin_token value',
    '토큰 소거': 'Clear Token',
    '취소': 'Cancel',
    '저장 및 적용': 'Save & Apply',
    '인증 오류: 올바르지 않거나 만료된 관리자 토큰입니다.':
        'Auth Error: Invalid or expired admin token.',
    '서버 오류: ': 'Server Error: ',
    '상세내용: ': 'Details: ',
    '네트워크 요청 중 예상치 못한 에러 발생: ': 'Unexpected network error: ',
    '복제 실패: ': 'Clone Failed: ',
    '활성화 실패: ': 'Activation Failed: ',
    '삭제 실패: ': 'Delete Failed: ',
    '저장 실패: ': 'Save Failed: ',

    // Common Button Labels
    '추가': 'Add',
    '삭제': 'Delete',
    '복제': 'Clone',
    '활성화': 'Activate',
    '저장': 'Save',
    '내보내기': 'Export',
    '가져오기': 'Import',
    '수정': 'Edit',
    '상세': 'Details',

    // Config Panel List & Search
    '설정 프로필 목록': 'Config Profile List',
    '로봇명 검색': 'Search Robot',
    '환경 검색': 'Search Env',
    '등록된 설정이 없습니다.': 'No configs registered.',
    'Active': 'Active',

    // Config Detail Tab
    '조회할 설정을 선택하거나 추가 버튼을 누르세요.': 'Select a config to view or click Add.',
    '신규 에이전트 설정 추가': 'Add New Agent Config',
    '설정 상세': 'Config Details',
    '설정 파일 내보내기': 'Export Config File',
    '프로필·ROS 환경': 'Profile & ROS Environment',
    'AI 모델·지식': 'AI Models & Knowledge',
    '로봇 기능·센서': 'Robot Capabilities & Sensors',
    '에이전트 동작·자료': 'Agent Behavior & Resources',
    '외부 연동': 'Integrations',
    '서버·보안·관측': 'Server, Security & Observability',
    '설정 활성화': 'Activate Config',
    '설정 복제': 'Clone Config',
    '설정 파일 업로드 완료': 'Config Upload Success',
    '설정이 성공적으로 활성화되었습니다.': 'Configuration successfully activated.',
    '설정 삭제': 'Delete Config',
    '정말로 이 설정을 삭제하시겠습니까?':
        'Are you sure you want to delete this configuration?',
    '설정이 복제되었습니다: ': 'Configuration cloned: ',
    '설정 압축 파일 생성 중 에러 발생: ': 'Error generating config zip: ',

    // Config Basic Section
    '설정 프로필 이름 *': 'Config Profile Name *',
    '설정 설명': 'Description',
    '기본 정보': 'Basic Information',
    '로봇명 (Robot Name) *': 'Robot Name *',
    '환경 (Environment) *': 'Environment *',
    '에이전트 이름 (Agent Name) *': 'Agent Name *',

    // Config Form Sections
    '1. LLM 연동 설정': '1. LLM Integration Settings',
    '2. MCP 서버 연동': '2. MCP Server Integration',
    '3. RAG 및 벡터 DB 설정': '3. RAG & Vector DB Settings',
    '4. 로봇 정보 수신 피어 (gRPC)': '4. Robot Info Reception Peers (gRPC)',
    '5. HTTP API 보안 설정': '5. HTTP API Security Settings',
    '6. 로컬 환경 경로 및 리소스 설정': '6. Local Paths & Resources Settings',
    '7. 카메라 / 비전 / 센서 설정': '7. Camera / Vision / Sensor Settings',
    '8. 스킬 자가학습 설정 (RAG)': '8. Skill Self-Learning Settings (RAG)',
    '9. 디버그 및 로깅 설정': '9. Debug & Logging Settings',

    // LLM Section
    'LLM 제공자 (Provider)': 'LLM Provider',
    'Ollama API 엔드포인트': 'Ollama API Endpoint',
    'LLM 모델명 (Model Name)': 'LLM Model Name',
    '시스템 프롬프트 (System Prompt)': 'System Prompt',
    '최대 토큰 크기 (Context Window)': 'Max Token Size (Context Window)',
    'Ollama Options 상세 설정': 'Detailed Ollama Options',
    'SLM 지연 시 off 권장. 미설정 시 모델 기본값':
        'Off recommended if SLM lags. Default if unset',
    '기본값 (미설정)': 'Default (Unset)',
    '시스템 지침 (System Instruction)': 'System Instruction',

    // MCP Section
    'MCP 서버 목록': 'MCP Server List',
    '추가하기': 'Add',

    // RAG Section
    'RAG 활성화': 'Enable RAG',
    '베타 기능': 'Beta',
    '벡터 DB 엔드포인트': 'Vector DB Endpoint',
    '콜렉션 이름': 'Collection Name',
    '동시 조회 도큐먼트 수 (Limit)': 'Limit (Top K)',
    '유사도 컷오프 임계치 (Threshold)': 'Similarity Threshold',

    // gRPC Section
    '동료 로봇 피어 설정': 'Peer Robots config',
    '동료 로봇 IP/Port 목록': 'Peer Robot IP/Port List',

    // HTTP Security Section
    'API 보안 키 검증 사용': 'Enable API Key Validation',
    '관리자 권한 토큰 (Admin Token)': 'Admin Auth Token (Admin Token)',
    '클라이언트 요청용 API Key': 'Client Request API Key',

    // Paths Section
    '로봇 설정 호스트 디렉토리 (RC_CONFIG_DIR)':
        'Robot Config Host Directory (RC_CONFIG_DIR)',
    '데이터 및 스토리지 경로 (RC_DATA_DIR)': 'Data & Storage Path (RC_DATA_DIR)',
    '워크스페이스 기준 경로 (RC_WORKSPACE_DIR)': 'Workspace Base Path (RC_WORKSPACE_DIR)',

    // Camera Section
    '비디오 스트리밍 주소 (RTSP/HTTP)': 'Video Streaming URL (RTSP/HTTP)',
    '이미지 캡처 해상도 가로 (Width)': 'Image Width',
    '이미지 캡처 해상도 세로 (Height)': 'Image Height',
    '카메라 FPS 설정': 'Camera FPS',
    '카메라 노출값': 'Camera Exposure',

    // Skill Learning Section
    '자가학습 데이터 수집 디렉토리': 'Self-Learning Data Collection Directory',
    '임계 신뢰도 점수': 'Threshold Confidence Score',
    '자동 자가학습 주기 (초)': 'Auto Self-Learning Interval (sec)',

    // Debug Section
    '콘솔 디버그 로그 출력 (VERBOSE)': 'Verbose Console Debug Logs',
    '성능 메트릭 모니터링 활성화': 'Enable Performance Metrics',
    '로깅 레벨': 'Logging Level',

    // Scenario Panel List & Search
    '테스트 시나리오 목록': 'Test Scenarios List',
    '등록된 시나리오가 없습니다.': 'No scenarios registered.',
    '시나리오 상세': 'Scenario Details',
    '신규 시나리오 추가': 'Add New Scenario',
    '시나리오 수정': 'Edit Scenario',
    '시나리오 목록': 'Scenario List',

    // Scenario Detail Panel
    '시나리오 명칭 *': 'Scenario Name *',
    '테스트 로봇 모델 *': 'Test Robot Model *',
    '테스트 대상 환경 *': 'Test Target Env *',
    '시나리오 설명': 'Scenario Description',
    '테스트 케이스': 'Test Cases',
    '편집': 'Edit',
    '활성화됨': 'Activated',
    '시나리오 저장': 'Save Scenario',
    '시나리오 복제': 'Clone Scenario',
    '시나리오가 성공적으로 활성화되었습니다.': 'Scenario successfully activated.',
    '시나리오 삭제': 'Delete Scenario',
    '정말로 이 시나리오를 삭제하시겠습니까?': 'Are you sure you want to delete this scenario?',
    '시나리오 복제 완료: ': 'Scenario cloned: ',
    '시나리오 삭제 완료': 'Scenario deleted',

    // GUI / JSON Modes
    'GUI 모드': 'GUI Mode',
    'JSON 모드': 'JSON Mode',
    'JSON 구문 오류로 인해 GUI 에디터로 전환할 수 없습니다.\n오류: ':
        'Cannot switch to GUI Editor due to JSON syntax error.\nError: ',
    '편집 모드일 때만 템플릿을 추가할 수 있습니다.': 'Templates can only be added in edit mode.',
    ' 템플릿이 리스트에 추가되었습니다.': ' template added to list.',

    // ===== Config Detail: Section Headers =====
    '프로필 기본 정보': 'Profile Basics',
    'LLM 및 클라우드 API 자격 증명': 'LLM & Cloud API Credentials',
    '메신저 및 통신 데몬': 'Messaging & Communication Daemons',
    '에이전트 문서 및 한계 설정': 'Agent Documents & Limits',
    'MCP 서버 연동': 'MCP Server Integration',
    'RAG 및 벡터 DB 설정': 'RAG & Vector DB Settings',
    'HTTP API 보안 설정': 'HTTP API Security Settings',
    '로컬 경로 및 리소스': 'Local Paths & Resources',
    '카메라·비전·센서': 'Camera, Vision & Sensors',
    '스킬 자가학습': 'Skill Self-Learning',
    '태스크 큐·명령 자동 분해': 'Task Queue & Command Decomposition',

    // ===== Config Tab: Dialogs / Export / Messages =====
    '.env (환경 변수)': '.env (Environment Variables)',
    'SKILLS.md (스킬 가이드)': 'SKILLS.md (Skill Guide)',
    'TROUBLESHOOTING.md (장애 대응)': 'TROUBLESHOOTING.md (Troubleshooting)',
    'ROBOT_LIMITS.json (스펙 제한)': 'ROBOT_LIMITS.json (Spec Limits)',
    '삭제되었습니다.': 'Deleted.',
    '활성화 처리 중 에러 발생: ': 'Error during activation: ',
    '삭제 처리 중 에러 발생: ': 'Error during deletion: ',
    '복제 처리 중 에러 발생: ': 'Error during clone: ',
    '저장 처리 중 에러 발생: ': 'Error during save: ',
    '성공적으로 저장되었습니다.': 'Saved successfully.',
    '.env 파일 조회 실패: ': 'Failed to fetch .env file: ',
    '.env 파일 조회 중 에러 발생: ': 'Error fetching .env file: ',
    'Test Cases JSON 형식이 올바르지 않습니다: ': 'Test Cases JSON format is invalid: ',
    '최소 하나 이상의 테스트 케이스가 필요합니다.': 'At least one test case is required.',

    // ===== Config Detail: Common =====
    '필수 입력입니다': 'This field is required',
    '로봇 식별자 (robot_name) *': 'Robot Identifier (robot_name) *',
    '구동 환경 (environment) *': 'Environment (environment) *',

    // ===== Config Basic Section =====
    'ROS 2 Domain ID (ROS_DOMAIN_ID) *': 'ROS 2 Domain ID (ROS_DOMAIN_ID) *',
    '0 ~ 232 사이의 정수만 허용됩니다': 'Only integers between 0 and 232 are allowed',
    'ROS 2 Debug 로깅 활성화': 'Enable ROS 2 Debug Logging',

    // ===== Config LLM Section =====
    '모델명 (llm_model)': 'Model Name (llm_model)',
    'Ollama Base URL (예: http://localhost:11434)':
        'Ollama Base URL (e.g. http://localhost:11434)',
    'Context 크기 (num_ctx)': 'Context Size (num_ctx)',
    'Temperature (창의성)': 'Temperature (Creativity)',
    'Seed (난수 시드)': 'Seed (Random Seed)',
    'Top K (필터링)': 'Top K (Filtering)',
    'Top P (확률 필터링)': 'Top P (Probability Filtering)',
    'Min P (최소 확률)': 'Min P (Minimum Probability)',
    'Think (Qwen3 추론 단계)': 'Think (Qwen3 Reasoning Level)',
    'off (false) — SLM 권장': 'off (false) — SLM recommended',

    // ===== Config LLM: Ollama Guide =====
    'Ollama 옵션 JSON 가이드': 'Ollama Options JSON Guide',
    '기본 템플릿 입력': 'Insert Default Template',
    '컨텍스트 윈도우 크기 (기본: 2048)': 'Context window size (default: 2048)',
    '모델 창의성/무작위성 (기본: 0.8)': 'Model creativity/randomness (default: 0.8)',
    '최대 생성 토큰 수 (-1: 무제한)': 'Max generated tokens (-1: unlimited)',
    '반복 토큰 감점 비율 (기본: 1.1)': 'Repeat token penalty ratio (default: 1.1)',
    '반복 방지용 되돌아볼 토큰 수 (기본: 64)':
        'Look-back tokens for repeat prevention (default: 64)',
    '출력 고정용 무작위 시드값 (기본: 0)': 'Random seed for fixed output (default: 0)',
    '무의미한 토큰 생성 억제값 (기본: 40)':
        'Suppresses meaningless token generation (default: 40)',
    '누적 확률 기반 필터링 비율 (기본: 0.9)':
        'Cumulative probability filtering ratio (default: 0.9)',
    '최소 확률 임계치 필터링 (기본: 0.0)':
        'Minimum probability threshold filter (default: 0.0)',
    'Qwen3 등 thinking 모델 추론 단계 제어. false=끔(빠름), true/low~max=단계. options 와 별개 최상위 파라미터':
        'Controls reasoning level for thinking models like Qwen3. false=off (fast), true/low~max=level. Top-level parameter separate from options',

    // ===== Config RAG Section =====
    'RAG (Retrieval-Augmented Generation) 활성화':
        'Enable RAG (Retrieval-Augmented Generation)',
    '임베딩 Provider (예: openai, azure, ollama)':
        'Embedding Provider (e.g. openai, azure, ollama)',
    '임베딩 모델명': 'Embedding Model Name',
    '임베딩 Base URL (선택사항)': 'Embedding Base URL (optional)',
    '임베딩 API Key (선택사항)': 'Embedding API Key (optional)',
    '벡터 DB 백엔드 (예: qdrant)': 'Vector DB Backend (e.g. qdrant)',
    'Qdrant Collection 이름': 'Qdrant Collection Name',
    'Qdrant API Key (선택사항)': 'Qdrant API Key (optional)',
    'Qdrant 타임아웃 (초, 기본: 5.0)': 'Qdrant Timeout (sec, default: 5.0)',
    'RAG Top-K (기본: 2)': 'RAG Top-K (default: 2)',
    'RAG Score 임계값 (0.0~1.0, 기본: 0.7)':
        'RAG Score Threshold (0.0~1.0, default: 0.7)',
    'RAG 로컬 미러 (원격 다운 대비 로컬 동시 저장)':
        'RAG Local Mirror (save locally in case of remote outage)',
    '메모리/로컬 미러 저장 디렉토리 (RC_MEMORY_DIR)':
        'Memory/Local Mirror Directory (RC_MEMORY_DIR)',

    // ===== Config Messenger Section =====
    'gRPC Client (동료 로봇)': 'gRPC Client (Peer Robots)',

    // ===== Config HTTP Security Section =====
    'HTTP 바인딩 호스트 (기본: 127.0.0.1)': 'HTTP Bind Host (default: 127.0.0.1)',
    'HTTP 포트 (기본: 8080)': 'HTTP Port (default: 8080)',
    'Read-only 접근 토큰 (조회용)': 'Read-only Access Token (for queries)',
    'Control 제어 토큰 (기동/정지용)': 'Control Token (for start/stop)',
    '허용 IP 대역 CIDR JSON (예: ["127.0.0.1/32"])':
        'Allowed IP CIDR JSON (e.g. ["127.0.0.1/32"])',
    '분당 요청 제한 (Rate Limit)': 'Requests per Minute (Rate Limit)',
    '허용 스킬 JSON (빈 배열은 전체 허용)': 'Allowed Skills JSON (empty array allows all)',
    '차단 스킬 JSON (예: ["emergency_stop"])':
        'Blocked Skills JSON (e.g. ["emergency_stop"])',

    // ===== Config Dashboard Section =====
    'Dashboard 웹 노드 설정': 'Dashboard Web Node Settings',
    'HTTP API 채널 포트(8080)와 별개로 동작하는 Dashboard 웹 노드 주소입니다.':
        'Dashboard web node address, separate from the HTTP API channel port (8080).',
    'Dashboard 바인딩 호스트 (RC_DASHBOARD_HOST, 기본: 127.0.0.1)':
        'Dashboard Bind Host (RC_DASHBOARD_HOST, default: 127.0.0.1)',
    'Dashboard 포트 (RC_DASHBOARD_PORT, 기본: 9090)':
        'Dashboard Port (RC_DASHBOARD_PORT, default: 9090)',
    '선택 — API Key가 여러 workspace에 접근할 때 지정합니다':
        'Optional — specify when the API key can access multiple workspaces',

    // ===== Config Path Section =====
    '에이전트 작업 공간 호스트 디렉토리 (RC_AGENT_WORKSPACE_DIR)':
        'Agent Workspace Host Directory (RC_AGENT_WORKSPACE_DIR)',
    'Butler 스크립트 디렉토리 (RC_BUTLER_SCRIPTS_DIR)':
        'Butler Scripts Directory (RC_BUTLER_SCRIPTS_DIR)',
    'Butler 소싱 워크스페이스 (RC_BUTLER_SOURCE_DIR)':
        'Butler Source Workspace (RC_BUTLER_SOURCE_DIR)',
    '시스템 프롬프트 파일 경로 (RC_SYSTEM_PROMPT_FILE)':
        'System Prompt File Path (RC_SYSTEM_PROMPT_FILE)',
    '로봇 URDF 설명 파일 경로 (RC_ROBOT_DESCRIPTION_FILE)':
        'Robot URDF Description File Path (RC_ROBOT_DESCRIPTION_FILE)',

    // ===== Config Camera Section =====
    '카메라 이미지 토픽 (RC_CAMERA_TOPIC)': 'Camera Image Topic (RC_CAMERA_TOPIC)',
    '비워두면 로봇 프로필 기본값 사용 (예: /oakd/rgb/preview/image_raw)':
        'Leave empty to use robot profile default (e.g. /oakd/rgb/preview/image_raw)',
    'Stretch3 그리퍼 RGB 토픽 (RC_GRIPPER_CAMERA_TOPIC)':
        'Stretch3 Gripper RGB Topic (RC_GRIPPER_CAMERA_TOPIC)',
    '예: /gripper_camera/color/image_rect_raw':
        'e.g. /gripper_camera/color/image_rect_raw',
    '그리퍼 Depth 토픽 (RC_GRIPPER_DEPTH_TOPIC)':
        'Gripper Depth Topic (RC_GRIPPER_DEPTH_TOPIC)',
    '그리퍼 CameraInfo (RC_GRIPPER_CAMERA_INFO_TOPIC)':
        'Gripper CameraInfo (RC_GRIPPER_CAMERA_INFO_TOPIC)',
    '그리퍼 PointCloud 토픽 (RC_GRIPPER_POINTCLOUD_TOPIC)':
        'Gripper PointCloud Topic (RC_GRIPPER_POINTCLOUD_TOPIC)',
    '예: /gripper_camera/depth/color/points':
        'e.g. /gripper_camera/depth/color/points',
    '그리퍼 카메라 ONNX 객체 인식 활성화 (RC_USE_GRIPPER_VISION)':
        'Enable Gripper Camera ONNX Object Detection (RC_USE_GRIPPER_VISION)',
    '그리퍼 비전 최대 추론 Hz (RC_GRIPPER_VISION_MAX_INFERENCE_HZ)':
        'Gripper Vision Max Inference Hz (RC_GRIPPER_VISION_MAX_INFERENCE_HZ)',
    '예: 5.0': 'e.g. 5.0',
    'ONNX 객체 인식 비전 노드 활성화 (RC_USE_VISION)':
        'Enable ONNX Object Detection Vision Node (RC_USE_VISION)',
    'ONNX 모델 파일 경로 (RC_VISION_MODEL_PATH)':
        'ONNX Model File Path (RC_VISION_MODEL_PATH)',
    'use_vision=true 시 필수 (예: /ros2_ws/models/yolov8n.onnx)':
        'Required when use_vision=true (e.g. /ros2_ws/models/yolov8n.onnx)',
    '자가진단 라이다 토픽 (RC_LIDAR_TOPIC)':
        'Self-Diagnosis LiDAR Topic (RC_LIDAR_TOPIC)',
    '비워두면 robot_config 사용 (예: /scan)':
        'Leave empty to use robot_config (e.g. /scan)',
    '자가진단 IMU 토픽 (RC_IMU_TOPIC)': 'Self-Diagnosis IMU Topic (RC_IMU_TOPIC)',
    '비워두면 robot_config 사용 (예: /imu/data)':
        'Leave empty to use robot_config (e.g. /imu/data)',

    // ===== Config Learning Section =====
    '자가학습 활성화 (RC_ENABLE_SKILL_LEARNING)':
        'Enable Self-Learning (RC_ENABLE_SKILL_LEARNING)',
    '성공 경험 샘플링 비율 (RC_SKILL_LEARNING_SUCCESS_SAMPLE_RATE)':
        'Success Experience Sampling Rate (RC_SKILL_LEARNING_SUCCESS_SAMPLE_RATE)',
    '예: 0.1 (10%)': 'e.g. 0.1 (10%)',
    '자가학습 교훈 추출 자동 주기(초) (RC_SKILL_LEARNING_REFLECT_INTERVAL_SEC)':
        'Self-Learning Reflection Interval (sec) (RC_SKILL_LEARNING_REFLECT_INTERVAL_SEC)',
    '예: 1800 (초)': 'e.g. 1800 (sec)',

    // ===== Config Markdown Section =====
    '로봇 개성 및 스타일 정의...': 'Define robot personality and style...',
    '에이전트 쉘 스크립트 스킬 가이드...': 'Agent shell script skill guide...',
    '장애 극복 대응 매뉴얼...': 'Troubleshooting response manual...',
    '로봇 가동 제한치 JSON 정의...': 'Robot operation limits JSON definition...',
    '올바르지 않은 JSON 포맷입니다.': 'Invalid JSON format.',

    // ===== Config MCP Section =====
    'MCP 사용': 'Enable MCP',
    '보안을 위해 MCP 자격 증명(env/headers) 값은 마스킹되어 있습니다. 마스킹된 값을 그대로 두고 저장하면 기존 값이 유지됩니다.':
        'MCP credentials (env/headers values) are masked for security. Saving without changing a masked value keeps the existing value.',
    '등록된 MCP 서버가 없습니다.': 'No MCP servers registered.',
    'MCP 서버 추가': 'Add MCP Server',
    'MCP 서버 #': 'MCP Server #',
    '서버 이름': 'Server Name',
    '예: filesystem': 'e.g. filesystem',
    '실행 명령어 (command)': 'Run Command (command)',
    '예: npx': 'e.g. npx',
    '인자 (args, 쉼표로 구분)': 'Arguments (args, comma-separated)',
    '예: -y, @modelcontextprotocol/server-filesystem':
        'e.g. -y, @modelcontextprotocol/server-filesystem',
    '작업 디렉토리 (cwd, 선택)': 'Working Directory (cwd, optional)',
    '환경 변수 (env)': 'Environment Variables (env)',
    '헤더 (headers)': 'Headers (headers)',
    '예: https://example.com/mcp/sse': 'e.g. https://example.com/mcp/sse',

    // ===== CLOi Cleanup Demo Section =====
    'CLOi 정리 시연 설정': 'CLOi Cleanup Demonstration Settings',
    '정리 시연 기능 사용': 'Enable cleanup demonstration',
    '정리 시연 허용 모션 ID (JSON 배열)': 'Allowed cleanup-demo motion IDs (JSON array)',
    '예: [22,60]': 'e.g. [22,60]',
    '빈 값은 승인된 기본값 [22,60]을 사용합니다. 모션 ID는 개체마다 다르므로 해당 로봇 catalog에서 승인된 ID를 직접 지정하세요. []는 시연을 끕니다. catalog pre_id가 있는 모션은 실행하지 않습니다.':
        'Empty uses the approved default [22,60]. Motion IDs differ per robot, so specify IDs approved in that robot catalog. [] disables the demo. Motions with catalog pre_id are never run.',

    // ===== gRPC Peers Input Form =====
    '등록된 동료 로봇이 없습니다.': 'No peer robots registered.',
    '동료 로봇 추가': 'Add Peer Robot',
    '로봇 #': 'Robot #',
    '로봇 이름': 'Robot Name',
    '예: Robot_A': 'e.g. Robot_A',
    '호스트 (IP/도메인)': 'Host (IP/Domain)',
    '예: 192.168.1.100': 'e.g. 192.168.1.100',
    '포트 번호': 'Port Number',
    '로봇 설명 (사전 정보)': 'Robot Description (prior info)',
    '예: 집게 팔 장착 매니퓰레이터': 'e.g. Manipulator with gripper arm',
    '역할 / 타입': 'Role / Type',
    '예: manipulator': 'e.g. manipulator',
    '기능 목록 (쉼표로 구분)': 'Capabilities (comma-separated)',
    '예: cleanup_demo, navigation': 'e.g. cleanup_demo, navigation',
    '정리 시연 기능은 cleanup_demo로 지정합니다. manipulation과 구분됩니다.':
        'Set cleanup_demo for the cleanup demonstration; it is distinct from manipulation.',

    // ===== Scenario Detail Panel =====
    '조회할 테스트 시나리오를 선택하거나 추가 버튼을 누르세요.':
        'Select a test scenario to view or click Add.',
    '신규 테스트 시나리오 추가': 'Add New Test Scenario',
    '1. 시나리오 정보': '1. Scenario Information',
    '시나리오 이름 *': 'Scenario Name *',
    '2. 테스트 케이스 목록 정의': '2. Test Case List Definition',
    'GUI 폼 에디터 (권장)': 'GUI Form Editor (Recommended)',
    'JSON 텍스트 에디터': 'JSON Text Editor',
    '💡 지원되는 테스트 유형 (Type) 및 매개변수 가이드':
        '💡 Supported Test Types & Parameter Guide',
    '테스트 케이스 JSON을 입력해 주세요.': 'Please enter test case JSON.',
    'JSON 파싱 에러: ': 'JSON parse error: ',
    '클릭하여 에디터 아래에 템플릿 추가': 'Click to add template below the editor',

    // ===== Test Case List Editor =====
    '정의된 테스트 케이스가 없습니다.': 'No test cases defined.',
    '※ 항목 왼쪽의 아이콘을 드래그하여 순서를 변경할 수 있습니다.':
        '※ Drag the icon on the left of each item to reorder.',
    '템플릿 테스트 케이스 추가': 'Add Template Test Case',
    '테스트 케이스 추가': 'Add Test Case',
    '(이름 없음)': '(No Name)',
    '테스트 매개변수 (Params)': 'Test Parameters (Params)',
    '테스트 ID *': 'Test ID *',
    '테스트 이름 *': 'Test Name *',
    '수행 단계 (Step) *': 'Step *',
    '테스트 유형 (Type) *': 'Test Type (Type) *',
    '타임아웃 (ms) *': 'Timeout (ms) *',

    // ===== Test Case Params Editor =====
    'LLM 검증 프롬프트 (prompt)': 'LLM Validation Prompt (prompt)',
    '주행 모드 (mode)': 'Driving Mode (mode)',
    'guardrail (가드레일 속도 제한)': 'guardrail (guardrail speed limit)',
    'motion (자연어 주행 지시)': 'motion (natural language driving command)',
    '제한 속도 (speed - m/s)': 'Speed Limit (speed - m/s)',
    '주행 지시 프롬프트 (command)': 'Driving Command Prompt (command)',
    '프롬프트 입력 (prompt) *': 'Prompt Input (prompt) *',
    '성공 기대 여부 (expect_success): ': 'Expect Success (expect_success): ',
    '포함될 키워드 목록 (expected_keywords - 쉼표로 구분)':
        'Expected Keywords (expected_keywords - comma-separated)',
    '포함되지 않아야 할 키워드 목록 (fail_keywords - 쉼표로 구분)':
        'Fail Keywords (fail_keywords - comma-separated)',
    '키워드1, 키워드2': 'keyword1, keyword2',
    '이 테스트 유형은 기본적으로 부가 파라미터가 필요하지 않습니다.\n커스텀 매개변수를 추가하려면 아래에 JSON 객체 형식을 입력해 주세요.':
        'This test type needs no additional parameters by default.\nTo add custom parameters, enter a JSON object below.',
    '커스텀 매개변수 JSON (params)': 'Custom Parameters JSON (params)',
    'JSON 객체(Map) 형식이어야 합니다.': 'Must be a JSON object (Map) format.',
    'JSON 문법 오류': 'JSON syntax error',

    // ===== Test Case Type Guide Descriptions (short) =====
    '로봇 gRPC Ping 연결성 테스트': 'Robot gRPC Ping connectivity test',
    '로봇 정보 조회 API 및 프로필 정합성 검증':
        'Robot info query API and profile consistency check',
    '배터리 잔량 확인 (10% 미만 시 경고)': 'Battery level check (warning below 10%)',
    '카메라 스트림 및 이미지 디코딩 검증': 'Camera stream and image decoding check',
    'SLAM 맵 데이터 격자 정보 수신 검증': 'SLAM map data grid info reception check',
    'AI 비전 분석 스킬 및 파일 연동 검증':
        'AI vision analysis skill and file integration check',
    'AI 지도 분석 스킬 및 파일 연동 검증':
        'AI map analysis skill and file integration check',
    '가드레일 속도 제한 또는 주행 스킬 기동 테스트':
        'Guardrail speed limit or driving skill activation test',
    '매니퓰레이터 관절 구동 및 제어 테스트': 'Manipulator joint actuation and control test',
    'LLM 페르소나 정체성 및 응답 지능 검증':
        'LLM persona identity and response intelligence check',
    '사용자 정의 프롬프트 전송 및 키워드 검증':
        'Custom prompt submission and keyword verification',

    // ===== Scenario Test Type Guide Descriptions (long) =====
    '로봇 gRPC Ping 연결성 테스트 (실패 시 메신저 대체 통신)':
        'Robot gRPC Ping connectivity test (falls back to messenger on failure)',
    '로봇 정보 조회 API 호출 및 프로필 비교 정합성 테스트 (RosGrpc 전용)':
        'Robot info query API call and profile comparison consistency test (RosGrpc only)',
    '로봇 배터리 상태 점검 (10% 미만 시 WARNING 분류)':
        'Robot battery status check (classified WARNING below 10%)',
    '카메라 이미지 수신 및 디코딩 검증': 'Camera image reception and decoding check',
    'SLAM 맵 데이터 및 격자 정보 수신 검증 (RosGrpc 전용)':
        'SLAM map data and grid info reception check (RosGrpc only)',
    '메신저 채널을 통해 카메라 이미지 분석 AI 스킬 및 파일 연동 검증':
        'Verify camera image analysis AI skill and file integration via messenger channel',
    '메신저 채널을 통해 지도 이미지 분석 AI 스킬 및 파일 연동 검증':
        'Verify map image analysis AI skill and file integration via messenger channel',
    '가드레일 속도 제한 검증 또는 자연어 주행 스킬 기동 테스트\n'
            '- Params:\n'
            '  • mode: "guardrail" 또는 "motion"\n'
            '  • speed (double): "guardrail" 모드 시 속도 제한 (m/s)\n'
            '  • command (string): "motion" 모드 시 로봇 이동 지시 자연어':
        'Guardrail speed limit check or natural-language driving skill activation test\n'
        '- Params:\n'
        '  • mode: "guardrail" or "motion"\n'
        '  • speed (double): speed limit in "guardrail" mode (m/s)\n'
        '  • command (string): natural-language move command in "motion" mode',
    '로봇 매니퓰레이터 관절 구동 및 제어 동작 테스트\n'
            '- Params:\n'
            '  • command (string): 메신저 챗 모드 시 매니퓰레이터 기동 자연어':
        'Robot manipulator joint actuation and control test\n'
        '- Params:\n'
        '  • command (string): natural-language manipulator command in messenger chat mode',
    'LLM 에이전트 정체성(성격) 검증\n'
            '- Params:\n'
            '  • prompt (string): 에이전트에게 전달할 정체성 질문 텍스트':
        'LLM agent identity (persona) verification\n'
        '- Params:\n'
        '  • prompt (string): identity question text sent to the agent',
    '사용자 정의 임의 프롬프트 전송 및 검증\n'
            '- Params:\n'
            '  • prompt (string): 로봇 에이전트에 전달할 자연어 프롬프트 (필수)\n'
            '  • expect_success (bool): 성공 여부 기대값 (선택, 기본: true)\n'
            '  • expected_keywords (List<String>): 포함되어야 하는 키워드 목록 (선택)\n'
            '  • fail_keywords (List<String>): 포함되지 않아야 하는 키워드 목록 (선택)':
        'Custom arbitrary prompt submission and verification\n'
        '- Params:\n'
        '  • prompt (string): natural-language prompt sent to the robot agent (required)\n'
        '  • expect_success (bool): expected success value (optional, default: true)\n'
        '  • expected_keywords (List<String>): keywords that must be present (optional)\n'
        '  • fail_keywords (List<String>): keywords that must not be present (optional)',

    // ===== Config System 1 Section =====
    // SYSTEM1_ROUTER 만 필수이고 나머지는 선택 + 기본값을 라벨에 표시한다.
    'System 1 router (SYSTEM1_ROUTER) *': 'System 1 router (SYSTEM1_ROUTER) *',
    'Shadow mode (SYSTEM1_SHADOW, 선택, 기본: false)':
        'Shadow mode (SYSTEM1_SHADOW, optional, default: false)',
    'Shadow log path (SYSTEM1_SHADOW_LOG, 선택, 기본: 없음)':
        'Shadow log path (SYSTEM1_SHADOW_LOG, optional, default: none)',
    'Shadow mode가 켜져 있을 때 비교 기록을 저장할 파일 경로입니다. 비우면 노드 로그에만 남습니다.':
        'File path that stores the comparison records while Shadow mode is on. Leave it empty to keep them in the node log only.',
    '선택되지 않은 라우터(rule ↔ laya)의 판단도 백그라운드로 실행해 비교 기록합니다. 실행에는 영향이 없습니다. rule 모드에서는 System 1 endpoint가 필요합니다.':
        'Also runs the router that is not selected (rule ↔ laya) in the background and records both decisions for comparison. Does not affect execution. Requires the System 1 endpoint in rule mode.',
    '파일 경로를 입력하세요 (켜기/끄기 값이 아닙니다)':
        'Enter a file path (this is not an on/off value)',
    '절대 경로를 입력하세요 (예: /ws/agent_workspace/system1_shadow.jsonl)':
        'Enter an absolute path (e.g. /ws/agent_workspace/system1_shadow.jsonl)',
    'Step routing (SYSTEM1_STEP_ROUTING, 선택, 기본: shadow)':
        'Step routing (SYSTEM1_STEP_ROUTING, optional, default: shadow)',
    '복합 명령을 분해한 하위 단계에도 사전 라우터를 적용합니다. off: 모든 단계 LLM, shadow: 판정만 기록, on: 혼자 완결되는 단계를 직접 처리.':
        'Applies the pre-router to the sub-steps of a decomposed compound command. off: every step goes to the LLM, shadow: only records the decision, on: runs self-contained steps directly.',
    'System 1 scope (SYSTEM1_SCOPE, 선택, 기본: readonly)':
        'System 1 scope (SYSTEM1_SCOPE, optional, default: readonly)',
    'System 1 endpoint (SYSTEM1_ENDPOINT, 선택, 기본: 없음)':
        'System 1 endpoint (SYSTEM1_ENDPOINT, optional, default: none)',
    'System 1 provider (SYSTEM1_PROVIDER, 선택, 기본: laya)':
        'System 1 provider (SYSTEM1_PROVIDER, optional, default: laya)',
    'Timeout ms (SYSTEM1_TIMEOUT_MS, 선택, 기본: 300)':
        'Timeout ms (SYSTEM1_TIMEOUT_MS, optional, default: 300)',
    'Confidence thresholds JSON (SYSTEM1_CONF_THRESHOLDS_JSON, 선택, 기본: intent별 기본 임계치)':
        'Confidence thresholds JSON (SYSTEM1_CONF_THRESHOLDS_JSON, optional, default: per-intent thresholds)',
    'Candidate skills (SYSTEM1_SKILLS, 선택, 기본: 자동 선택)':
        'Candidate skills (SYSTEM1_SKILLS, optional, default: automatic)',
    'Max options (SYSTEM1_MAX_OPTIONS, 선택, 기본: 12)':
        'Max options (SYSTEM1_MAX_OPTIONS, optional, default: 12)',
    'System 1 API Key (SYSTEM1_API_KEY, 선택, 기본: 없음)':
        'System 1 API Key (SYSTEM1_API_KEY, optional, default: none)',

    // ===== Backup / Export / Import =====
    '백업 (내보내기/가져오기)': 'Backup (Export/Import)',
    '전체 설정 내보내기': 'Export All Settings',
    '백업 파일 가져오기': 'Import Backup File',
    '설정 프로필 포함': 'Include Config Profiles',
    '테스트 시나리오 포함': 'Include Test Scenarios',
    'API Key와 토큰 포함': 'Include API Keys & Tokens',
    '이 옵션을 켜면 민감 정보가 평문으로 파일에 포함됩니다.':
        'Enabling this will include sensitive information as plain text in the file.',
    '경고: 이 백업에는 API Key와 인증 토큰이 평문으로 포함됩니다. 안전한 위치에 보관하고 사용 후 삭제하세요.':
        'Warning: This backup contains API keys and auth tokens in plain text. Store it securely and delete it after use.',
    '적어도 하나의 항목을 선택해야 합니다.': 'At least one item must be selected.',
    '백업 파일이 다운로드되었습니다.': 'Backup file downloaded.',
    '백업 내보내기 실패: ': 'Backup export failed: ',
    '백업 내보내기 처리 중 에러 발생: ': 'Error during backup export: ',
    '내보내는 중...': 'Exporting...',
    '선택한 파일이 올바른 JSON 백업 파일이 아닙니다.':
        'The selected file is not a valid JSON backup file.',
    '백업 검증 실패: ': 'Backup validation failed: ',
    '백업 검증 처리 중 에러 발생: ': 'Error during backup validation: ',
    '이 백업에는 민감 정보가 포함되어 있습니다.': 'This backup includes sensitive information.',
    '이 백업에는 민감 정보가 포함되지 않았습니다.':
        'This backup does not include sensitive information.',
    '충돌 처리 정책': 'Conflict Policy',
    '건너뛰기 (기존 유지)': 'Skip (Keep Existing)',
    '덮어쓰기': 'Overwrite',
    '복사본 생성': 'Create Copy',
    '활성 상태 정책': 'Activation Policy',
    '모두 비활성으로 가져오기 (권장)': 'Import as Inactive (Recommended)',
    '내보낸 활성 상태 유지': 'Preserve Exported Active State',
    '기존 활성 상태 유지': 'Keep Existing Active State',
    '가져올 수 없음': 'Cannot Import',
    '백업 가져오기 실패: ': 'Backup import failed: ',
    '백업 가져오기 처리 중 에러 발생: ': 'Error during backup import: ',

    // ===== Maestro FleetControl =====
    'Maestro FleetControl 연동': 'Maestro FleetControl Integration',
    'Maestro 연동 사용 (MAESTRO_ENABLED)':
        'Enable Maestro integration (MAESTRO_ENABLED)',
    '끄면 MAESTRO_IP를 지정해도 로봇의 outbound connector를 시작하지 않습니다.':
        'When off, the robot does not start its outbound connector even if MAESTRO_IP is set.',
    'Maestro 서버 IP (MAESTRO_IP)': 'Maestro Server IP (MAESTRO_IP)',
    '비워두면 fleet outbound connector 비활성':
        'Leave empty to disable the fleet outbound connector',
    'Maestro 서버 포트 (ROBOT_PORT)': 'Maestro Server Port (ROBOT_PORT)',
    '로봇 ID (ROBOT_ID)': 'Robot ID (ROBOT_ID)',
    'MAESTRO_IP 설정 시 필수': 'Required when MAESTRO_IP is set',
    '사이트 ID (ROBOT_SITE_ID)': 'Site ID (ROBOT_SITE_ID)',
    '맵 ID (ROBOT_MAP_ID)': 'Map ID (ROBOT_MAP_ID)',
    '맵 버전 (ROBOT_MAP_VERSION)': 'Map Version (ROBOT_MAP_VERSION)',
    '맵 TF frame (ROBOT_MAP_FRAME_ID)': 'Map TF Frame (ROBOT_MAP_FRAME_ID)',
    '연결 단절 정책 (MAESTRO_DISCONNECT_POLICY)':
        'Disconnect Policy (MAESTRO_DISCONNECT_POLICY)',
    '하트비트 주기(초) (FLEET_HEARTBEAT_SEC)':
        'Heartbeat Interval (sec) (FLEET_HEARTBEAT_SEC)',
    '명령 저널 경로 (FLEET_COMMAND_JOURNAL_PATH)':
        'Command Journal Path (FLEET_COMMAND_JOURNAL_PATH)',
    '스킬 가이드 파일 (RC_SKILLS_GUIDE_FILE)':
        'Skill Guide File (RC_SKILLS_GUIDE_FILE)',
    '비워두면 배포 기본 경로(config/SKILLS.md) 사용':
        'Leave empty to use the deployment default (config/SKILLS.md)',
    'FleetControl mTLS 활성화 (FLEET_CONTROL_TLS)':
        'Enable FleetControl mTLS (FLEET_CONTROL_TLS)',
    'CA 인증서 (FLEET_CONTROL_CA_CERT)': 'CA Certificate (FLEET_CONTROL_CA_CERT)',
    '클라이언트 인증서 (FLEET_CONTROL_CLIENT_CERT)':
        'Client Certificate (FLEET_CONTROL_CLIENT_CERT)',
    '클라이언트 키 (FLEET_CONTROL_CLIENT_KEY)':
        'Client Key (FLEET_CONTROL_CLIENT_KEY)',

    // ===== LangSmith Tracing =====
    'LangSmith 트레이싱 / 모니터링': 'LangSmith Tracing / Monitoring',
    'LangSmith 트레이싱 활성화 (LANGSMITH_TRACING)':
        'Enable LangSmith tracing (LANGSMITH_TRACING)',
    '트레이싱 활성화 시 필수. 미설정 시 트레이스 업로드 안 됨':
        'Required when tracing is enabled. Traces are not uploaded if unset',
    '프로젝트 이름 (LANGSMITH_PROJECT)': 'Project Name (LANGSMITH_PROJECT)',
    '선택 — 미설정 시 "default"': 'Optional — defaults to "default"',
    '엔드포인트 (LANGSMITH_ENDPOINT)': 'Endpoint (LANGSMITH_ENDPOINT)',
    '선택 — 자체 호스팅/프록시 엔드포인트': 'Optional — self-hosted or proxy endpoint',

    // ===== Langfuse Tracing =====
    'Langfuse 트레이싱 / 모니터링': 'Langfuse Tracing / Monitoring',
    'Langfuse 트레이싱 활성화 (LANGFUSE_TRACING)':
        'Enable Langfuse tracing (LANGFUSE_TRACING)',
    '선택 — 자체 호스팅 Langfuse 서버 주소': 'Optional — self-hosted Langfuse server URL',

    // ===== Task Queue / Decomposition =====
    '태스크 큐 최대 대기열 크기 (RC_TASK_QUEUE_MAX_SIZE)':
        'Max Task Queue Size (RC_TASK_QUEUE_MAX_SIZE)',
    '예: 8 (0=큐 비활성화)': 'e.g. 8 (0 disables the queue)',
    '시작 시 LLM 검증 실패 기동 중단 (RC_LLM_FAIL_FAST)':
        'Abort Startup on LLM Validation Failure (RC_LLM_FAIL_FAST)',
    '필수 설정 파일 누락 시 기동 중단 (RC_STRICT_CONFIG)':
        'Abort Startup on Missing Required Config (RC_STRICT_CONFIG)',
    '복합 명령 자동 분해 활성화 (RC_ENABLE_TASK_DECOMPOSITION)':
        'Enable Automatic Command Decomposition (RC_ENABLE_TASK_DECOMPOSITION)',
    '분해 최대 단계 수 (RC_TASK_DECOMPOSITION_MAX_STEPS)':
        'Max Decomposed Steps (RC_TASK_DECOMPOSITION_MAX_STEPS)',
    '예: 6': 'e.g. 6',
    '단계 실패 재시도 횟수 (RC_TASK_STEP_MAX_RETRIES)':
        'Step Failure Retry Count (RC_TASK_STEP_MAX_RETRIES)',
    '예: 1': 'e.g. 1',
    '액션 대기 여유 시간 상한(초) (RC_TASK_DECOMPOSITION_WAIT_MARGIN_CAP_SEC)':
        'Action Wait Margin Cap (sec) (RC_TASK_DECOMPOSITION_WAIT_MARGIN_CAP_SEC)',
    '예: 1800.0 (30분)': 'e.g. 1800.0 (30 minutes)',

    // ===== Dashboard Web Node =====
    '사용 스위치를 끄면 host/port 를 지정해도 웹 노드를 실행하지 않습니다.':
        'When this switch is off, the web node does not run even if host/port are set.',
    '대시보드 웹 노드 사용 (RC_USE_DASHBOARD)':
        'Enable Dashboard Web Node (RC_USE_DASHBOARD)',

    // ===== CLOi Cleanup Demo (expression / pose) =====
    '상황별 표현 모션 자동 재생': 'Auto-play expression motion by situation',
    'CLOiD가 태스크를 마친 뒤 상황(인사·대화·탐색·실패)에 맞는 등록 모션을 한 번 재생합니다. 주행이 포함된 태스크에서는 재생하지 않습니다. 표현 모션이 부자연스러운 개체는 끄면 됩니다.':
        'After CLOiD finishes a task, it plays a registered motion once to match the situation (greeting, conversation, exploration, failure). It does not play for tasks that include driving. Turn this off for robots whose expression motions look unnatural.',
    '주행 전 boxing 자세 자동 정렬': 'Auto-align to Boxing Pose Before Driving',
    '베이스 이동 스킬 직전에 CLOiD를 최소 부피(boxing) 자세로 한 번 정렬하고, 실패하면 주행을 거부합니다. 주행 후 자세는 자동 복원되지 않습니다. cloid 프로필 전용입니다.':
        'Aligns CLOiD to the minimum-volume (boxing) pose once right before the base-move skill and refuses to drive if that fails. The pose is not restored after driving. cloid profile only.',

    // ===== System 1 Section Helpers =====
    'Intent별 confidence threshold를 JSON 객체로 지정합니다.':
        'Set per-intent confidence thresholds as a JSON object.',
    '비워두면 조건에 맞는 읽기 전용 스킬을 자동 선택합니다.':
        'Leave empty to automatically select matching read-only skills.',
    'Hosted provider가 인증을 요구할 때만 지정합니다.':
        'Set this only when the hosted provider requires authentication.',

    // ===== Basic / LLM / Path / Messenger =====
    '에이전트 ID (agent_id)': 'Agent ID (agent_id)',
    '예: Former0047': 'e.g. Former0047',
    '스킬 선택에 네이티브 도구 호출 사용 (RC_LLM_TOOL_CALLING)':
        'Use Native Tool Calling for Skill Selection (RC_LLM_TOOL_CALLING)',
    '켜면 복합 명령도 하나의 도구 대화에서 LLM이 단계를 이어갑니다. 끄면 JSON 응답을 강제하고 복합 명령을 명령 분해기가 처리합니다. provider가 도구 호출을 지원하지 않으면 자동으로 JSON 경로를 씁니다.':
        'When on, the LLM continues compound commands as steps inside a single tool conversation. When off, JSON responses are enforced and the command decomposer handles compound commands. If the provider does not support tool calling, the JSON path is used automatically.',
    '정리 태스크 실험 계측 run log 경로 (RC_CLEANUP_RUN_LOG_PATH)':
        'Cleanup Task Instrumentation Run Log Path (RC_CLEANUP_RUN_LOG_PATH)',
    '비우면 기록하지 않습니다. 예: /ros2_ws/agent_workspace/cleanup_runs.jsonl':
        'Leave empty to record nothing. e.g. /ros2_ws/agent_workspace/cleanup_runs.jsonl',
    'Maestro 사용 중에는 로봇 간 협업(gRPC 서버/클라이언트, peer 목록)이 비활성화됩니다. 동료 작업은 Maestro가 중계합니다.':
        'While Maestro is enabled, robot-to-robot collaboration (gRPC server/client, peer list) is disabled. Peer tasks are relayed by Maestro.',
    'gRPC Peer Token (GRPC_PEER_TOKEN — 외부 접속 시 필수)':
        'gRPC Peer Token (GRPC_PEER_TOKEN — required for external access)',
    '기본 50052 — 50051은 RosGrpc 텔레메트리 전용':
        'Default 50052 — 50051 is reserved for RosGrpc telemetry',

    // ===== MCP Catalog Dialog / Server Form =====
    'MCP 서버 찾아보기': 'Browse MCP Servers',
    '닫기': 'Close',
    '이름/설명으로 검색 (예: git, filesystem)':
        'Search by name/description (e.g. git, filesystem)',
    '카탈로그 조회 실패': 'Failed to load the catalog',
    '다시 시도': 'Retry',
    '검색 결과가 없습니다.': 'No search results.',
    '예: https://example.com/mcp': 'e.g. https://example.com/mcp',

    // ===== Scenario / Backup Screens =====
    '모두 받기 (ZIP)': 'Download All (ZIP)',
    '정말로 이 테스트 시나리오를 삭제하시겠습니까?':
        'Are you sure you want to delete this test scenario?',
    'gRPC Ping 연결성': 'gRPC Ping connectivity',
    '설정 프로필 {configs}건, 시나리오 {scenarios}건 (신규 설정 {newConfigs}건 / 충돌 {conflictingConfigs}건, 신규 시나리오 {newScenarios}건 / 충돌 {conflictingScenarios}건)':
        'Config profiles: {configs}, scenarios: {scenarios} (new configs: {newConfigs} / conflicts: {conflictingConfigs}, new scenarios: {newScenarios} / conflicts: {conflictingScenarios})',
    '가져오기 완료: 설정(생성 {created}, 갱신 {updated}, 건너뜀 {skipped}), 시나리오(생성 {sCreated}, 갱신 {sUpdated}, 건너뜀 {sSkipped})':
        'Import complete: configs (created {created}, updated {updated}, skipped {skipped}), scenarios (created {sCreated}, updated {sUpdated}, skipped {sSkipped})',

    // ===== Scenario Editor Errors =====
    '최상위 노드는 배열(List) 형식이어야 합니다.':
        'The top-level node must be an array (List).',
    'JSON이 배열([ ]) 형식이 아닙니다.': 'The JSON is not in array ([ ]) form.',
    'JSON 문법 오류로 템플릿을 자동으로 추가할 수 없습니다: {error}':
        'Templates cannot be added automatically due to a JSON syntax error: {error}',
    '지원하지 않는 테스트 케이스 유형입니다.': 'Unsupported test case type.',
  };
}

extension TranslateString on String {
  String get tr => LanguageManager.tr(this);
}
