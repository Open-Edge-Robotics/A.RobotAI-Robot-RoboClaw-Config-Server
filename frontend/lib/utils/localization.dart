// frontend/lib/utils/localization.dart

import 'package:flutter/material.dart';

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
    '1. 기본 정보': '1. Basic Information',
    '2. LLM 및 클라우드 API 자격 증명': '2. LLM & Cloud API Credentials',
    '4. 메신저 & 통신 데몬': '4. Messenger & Communication Daemons',
    '9. 에이전트 마크다운 & 한계 스펙 정의': '9. Agent Markdown & Limit Spec Definition',
    '10. MCP(Model Context Protocol) 서버 연동':
        '10. MCP (Model Context Protocol) Server Integration',

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
  };
}

extension TranslateString on String {
  String get tr => LanguageManager.tr(this);
}
