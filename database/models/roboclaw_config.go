package models

import "gorm.io/gorm"

// RoboClawConfig는 로봇 및 환경별 AI 에이전트 설정(Soul, Skill, Troubleshooting 및 env 환경변수)을 담는 GORM 모델입니다.
type RoboClawConfig struct {
	gorm.Model
	// 식별 및 메타데이터
	Name        string `gorm:"not null" json:"name"`              // 설정 프로필 이름 (예: "Butler_Office_Standard")
	RobotName   string `gorm:"index;not null" json:"robot_name"`  // 대상 로봇 식별자 (예: "butler", "former")
	Environment string `gorm:"index;not null" json:"environment"` // 대상 구동 환경 (예: "office", "factory")
	IsActive    bool   `gorm:"default:false" json:"is_active"`    // 해당 로봇/환경에서 이 설정을 활성화할지 여부
	Description string `json:"description"`                       // 설정 설명

	// ── ROS 2 설정 ──
	RosDomainId int    `gorm:"default:0" json:"ros_domain_id"`
	AgentId     string `gorm:"index" json:"agent_id"`

	// ── LLM 기본 설정 ──
	LlmProvider string `gorm:"default:'azure'" json:"llm_provider"` // azure, openai, anthropic, ollama
	LlmModel    string `gorm:"default:'gpt-4o'" json:"llm_model"`

	// ── Azure / API 자격 증명 ──
	AzureOpenaiEndpoint string `json:"azure_openai_endpoint"`
	AzureOpenaiApiKey   string `json:"azure_openai_api_key"`
	OpenaiApiKey        string `json:"openai_api_key"`
	AnthropicApiKey     string `json:"anthropic_api_key"`

	// ── Ollama 상세 설정 ──
	OllamaBaseUrl     string `json:"ollama_base_url"`
	OllamaOptionsJson string `gorm:"type:text" json:"ollama_options_json"` // num_ctx, temperature 등 JSON 저장

	// ── RAG / Qdrant 설정 ──
	EnableRag            bool   `gorm:"default:false" json:"enable_rag"`
	LlmEmbeddingModel    string `json:"llm_embedding_model"`
	LlmEmbeddingProvider string `json:"llm_embedding_provider"`
	LlmEmbeddingBaseUrl  string `json:"llm_embedding_base_url"`
	LlmEmbeddingApiKey   string `json:"llm_embedding_api_key"`
	RagVectorBackend     string `json:"rag_vector_backend"`
	QdrantUrl            string `json:"qdrant_url"`
	QdrantCollection     string `json:"qdrant_collection"`

	// ── 메신저 연동 활성화 설정 ──
	EnableDiscord       bool   `gorm:"default:false" json:"enable_discord"`
	EnableTelegram      bool   `gorm:"default:false" json:"enable_telegram"`
	EnableSlack         bool   `gorm:"default:false" json:"enable_slack"`
	EnableGrpc          bool   `json:"enable_grpc"`
	UseGrpc             bool   `gorm:"default:false" json:"use_grpc"` // robo_claw_grpc 노드(RosGrpc 서비스, 포트 50051) 실행 여부
	EnableGrpcClient    bool   `gorm:"default:false" json:"enable_grpc_client"`
	GrpcPort            int    `gorm:"default:50052" json:"grpc_port"`
	GrpcTargetHost      string `gorm:"default:'127.0.0.1'" json:"grpc_target_host"`
	GrpcPeerToken       string `json:"grpc_peer_token"`
	GrpcTargetPort      int    `gorm:"default:50051" json:"grpc_target_port"`
	GrpcTargetPeersJson string `gorm:"type:text;default:'[]'" json:"grpc_target_peers_json"`
	DiscordBotToken     string `json:"discord_bot_token"`
	SlackAppToken       string `json:"slack_app_token"`
	SlackBotToken       string `json:"slack_bot_token"`
	TelegramBotToken    string `json:"telegram_bot_token"`

	// ── 마크다운 및 JSON 파일 내용 ──
	SoulContent            string `gorm:"type:text" json:"soul_content"`            // ROBOT.md 내용
	SkillsContent          string `gorm:"type:text" json:"skills_content"`          // SKILLS.md 내용
	TroubleshootingContent string `gorm:"type:text" json:"troubleshooting_content"` // TROUBLESHOOTING.md 내용
	LimitsContent          string `gorm:"type:text" json:"limits_content"`          // ROBOT_LIMITS.json 내용

	// ── HTTP API 보안 설정 ──
	HttpHost               string `gorm:"default:'127.0.0.1'" json:"http_host"`
	HttpPort               int    `gorm:"default:8080" json:"http_port"`
	HttpReadonlyToken      string `json:"http_readonly_token"`
	HttpControlToken       string `json:"http_control_token"`
	HttpAllowedCidrsJson   string `gorm:"type:text;default:'[]'" json:"http_allowed_cidrs_json"`
	HttpRateLimitPerMinute int    `gorm:"default:60" json:"http_rate_limit_per_minute"`
	HttpAllowedSkillsJson  string `gorm:"type:text;default:'[]'" json:"http_allowed_skills_json"`
	HttpBlockedSkillsJson  string `gorm:"type:text;default:'[]'" json:"http_blocked_skills_json"`

	// ── Dashboard 웹 노드 설정 ──
	DashboardHost string `gorm:"default:'127.0.0.1'" json:"dashboard_host"` // RC_DASHBOARD_HOST (Dashboard 웹 노드 바인딩 호스트)
	DashboardPort int    `gorm:"default:9090" json:"dashboard_port"`        // RC_DASHBOARD_PORT (Dashboard 웹 노드 HTTP 포트, HTTP 채널 8080과 별개)

	// ── Maestro FleetControl outbound connector (contract v2.2.0) ──
	MaestroIp               string  `json:"maestro_ip"`                                                                        // MAESTRO_IP (빈 값이면 fleet outbound connector 비활성)
	RobotPort               int     `gorm:"default:50053" json:"robot_port"`                                                   // ROBOT_PORT (Maestro FleetControl 서버 포트)
	RobotId                 string  `json:"robot_id"`                                                                          // ROBOT_ID (maestro_ip 설정 시 필수)
	RobotSiteId             string  `json:"robot_site_id"`                                                                     // ROBOT_SITE_ID
	RobotMapId              string  `json:"robot_map_id"`                                                                      // ROBOT_MAP_ID
	RobotMapVersion         string  `json:"robot_map_version"`                                                                 // ROBOT_MAP_VERSION
	RobotMapFrameId         string  `gorm:"default:'map'" json:"robot_map_frame_id"`                                           // ROBOT_MAP_FRAME_ID
	MaestroDisconnectPolicy string  `gorm:"default:'complete'" json:"maestro_disconnect_policy"`                               // MAESTRO_DISCONNECT_POLICY (complete|stop|finish_atomic)
	FleetHeartbeatSec       float64 `gorm:"default:1.0" json:"fleet_heartbeat_sec"`                                            // FLEET_HEARTBEAT_SEC
	FleetCommandJournalPath string  `gorm:"default:'/tmp/robo_claw_fleet_commands.sqlite3'" json:"fleet_command_journal_path"` // FLEET_COMMAND_JOURNAL_PATH
	FleetSkillsGuideFile    string  `json:"skills_guide_file"`                                                                 // RC_SKILLS_GUIDE_FILE (빈 값이면 배포 기본 경로)
	FleetControlTls         bool    `gorm:"default:false" json:"fleet_control_tls"`                                            // FLEET_CONTROL_TLS (mTLS 활성화)
	FleetControlCaCert      string  `json:"fleet_control_ca_cert"`                                                             // FLEET_CONTROL_CA_CERT
	FleetControlClientCert  string  `json:"fleet_control_client_cert"`                                                         // FLEET_CONTROL_CLIENT_CERT
	FleetControlClientKey   string  `json:"fleet_control_client_key"`                                                          // FLEET_CONTROL_CLIENT_KEY

	// ── MCP(Model Context Protocol) 서버 연동 ──
	EnableMcp      bool   `gorm:"default:false" json:"enable_mcp"`
	McpServersJson string `gorm:"type:text;default:'[]'" json:"mcp_servers_json"`

	// ── RAG 추가 설정 ──
	RagTopK           int     `gorm:"default:2" json:"rag_top_k"`
	RagScoreThreshold float64 `gorm:"default:0.7" json:"rag_score_threshold"`
	QdrantApiKey      string  `json:"qdrant_api_key"`
	QdrantTimeoutSec  float64 `gorm:"default:5.0" json:"qdrant_timeout_sec"`
	RagLocalMirror    bool    `gorm:"default:true" json:"rag_local_mirror"` // RC_RAG_LOCAL_MIRROR (Qdrant 사용 시 로컬 동시 저장)
	MemoryDir         string  `json:"memory_dir"`                           // RC_MEMORY_DIR (메모리/로컬 벡터 저장 디렉토리)

	// ── 경로 및 리소스 설정 ──
	AgentWorkspaceDir    string `json:"agent_workspace_dir"`
	ButlerScriptsDir     string `json:"butler_scripts_dir"`
	ButlerSourceDir      string `json:"butler_source_dir"`
	ConfigDir            string `json:"config_dir"`
	SystemPromptFile     string `json:"system_prompt_file"`
	RobotDescriptionFile string `json:"robot_description_file"`

	// ── 카메라 / 비전 설정 ──
	CameraTopic                 string  `json:"camera_topic"`                                       // RC_CAMERA_TOPIC (로봇 프로필 기본값 오버라이드)
	UseVision                   bool    `gorm:"default:false" json:"use_vision"`                    // RC_USE_VISION (ONNX 객체 인식 노드 활성화)
	VisionModelPath             string  `json:"vision_model_path"`                                  // RC_VISION_MODEL_PATH (use_vision=true 시 필수)
	GripperCameraTopic          string  `json:"gripper_camera_topic"`                               // RC_GRIPPER_CAMERA_TOPIC
	GripperDepthTopic           string  `json:"gripper_depth_topic"`                                // RC_GRIPPER_DEPTH_TOPIC
	GripperCameraInfoTopic      string  `json:"gripper_camera_info_topic"`                          // RC_GRIPPER_CAMERA_INFO_TOPIC
	GripperPointcloudTopic      string  `json:"gripper_pointcloud_topic"`                           // RC_GRIPPER_POINTCLOUD_TOPIC
	UseGripperVision            bool    `gorm:"default:false" json:"use_gripper_vision"`            // RC_USE_GRIPPER_VISION
	GripperVisionMaxInferenceHz float64 `gorm:"default:5.0" json:"gripper_vision_max_inference_hz"` // RC_GRIPPER_VISION_MAX_INFERENCE_HZ

	// ── 자가진단용 센서 토픽 ──
	LidarTopic string `json:"lidar_topic"` // RC_LIDAR_TOPIC (자가진단 라이다 토픽, robot_config 기본값 오버라이드)
	ImuTopic   string `json:"imu_topic"`   // RC_IMU_TOPIC (자가진단 IMU 토픽)

	// ── 디버그 설정 ──
	Debug bool `gorm:"default:true" json:"debug"`

	// ── 스킬 자가학습 설정 ──
	EnableSkillLearning             bool    `gorm:"default:false" json:"enable_skill_learning"`
	SkillLearningSuccessSampleRate  float64 `gorm:"default:0.1" json:"skill_learning_success_sample_rate"`
	SkillLearningReflectIntervalSec int     `gorm:"default:1800" json:"skill_learning_reflect_interval_sec"`

	// ── 태스크 큐 / 복합 명령 자동 분해 설정 ──
	TaskQueueMaxSize                  int     `gorm:"default:8" json:"task_queue_max_size"`
	LlmFailFast                       bool    `gorm:"default:false" json:"llm_fail_fast"`
	StrictConfig                      bool    `gorm:"default:false" json:"strict_config"`
	EnableTaskDecomposition           bool    `json:"enable_task_decomposition"`
	TaskDecompositionMaxSteps         int     `gorm:"default:6" json:"task_decomposition_max_steps"`
	TaskStepMaxRetries                int     `gorm:"default:1" json:"task_step_max_retries"`
	TaskDecompositionWaitMarginCapSec float64 `gorm:"default:1800.0" json:"task_decomposition_wait_margin_cap_sec"`

	// ── LangSmith 트레이싱 / 모니터링 설정 ──
	LangsmithTracing     bool   `gorm:"default:false" json:"langsmith_tracing"`            // LANGSMITH_TRACING (트레이싱 활성화)
	LangsmithApiKey      string `json:"langsmith_api_key"`                                 // LANGSMITH_API_KEY (LangSmith API 키)
	LangsmithProject     string `gorm:"default:former-0045-claw" json:"langsmith_project"` // LANGSMITH_PROJECT (프로젝트 이름, 선택)
	LangsmithEndpoint    string `json:"langsmith_endpoint"`                                // LANGSMITH_ENDPOINT (자체 호스팅/프록시 엔드포인트, 선택)
	LangsmithWorkspaceId string `json:"langsmith_workspace_id"`                            // LANGSMITH_WORKSPACE_ID (workspace ID, 선택)

	// ── System 1 Fast Router (contract v2.4.0) ──
	System1Router             string  `gorm:"default:'rule'" json:"system1_router"`          // SYSTEM1_ROUTER
	System1Shadow             bool    `gorm:"default:false" json:"system1_shadow"`           // SYSTEM1_SHADOW
	System1ShadowLog          string  `json:"system1_shadow_log"`                            // SYSTEM1_SHADOW_LOG
	System1Scope              string  `gorm:"default:'readonly'" json:"system1_scope"`       // SYSTEM1_SCOPE
	System1Endpoint           string  `json:"system1_endpoint"`                              // SYSTEM1_ENDPOINT
	System1Provider           string  `gorm:"default:'laya'" json:"system1_provider"`        // SYSTEM1_PROVIDER
	System1TimeoutMs          float64 `gorm:"default:300.0" json:"system1_timeout_ms"`       // SYSTEM1_TIMEOUT_MS
	System1ConfThresholdsJson string  `gorm:"type:text" json:"system1_conf_thresholds_json"` // SYSTEM1_CONF_THRESHOLDS_JSON
	System1Skills             string  `gorm:"type:text" json:"system1_skills"`               // SYSTEM1_SKILLS (comma-separated)
	System1MaxOptions         int     `gorm:"default:12" json:"system1_max_options"`         // SYSTEM1_MAX_OPTIONS
	System1ApiKey             string  `json:"system1_api_key"`                               // SYSTEM1_API_KEY (secret)
}
