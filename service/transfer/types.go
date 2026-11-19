package transfer

// ============================================================================
// 이식용 백업(Export/Import) 전용 전송 포맷 정의
//
// DB 모델을 그대로 직렬화하지 않고 별도 DTO를 사용하는 이유:
//   1) GORM ID 및 CreatedAt/UpdatedAt/DeletedAt 등 가져오기 시 충돌을 유발하는
//      메타데이터를 제외한다.
//   2) 민감 정보(ApiKey, Token, MCP 서버 설정)의 포함 여부를 제어할 수 있다.
//   3) DB 스키마가 바뀌어도 백업 파일 포맷을 독립적으로 유지할 수 있다.
//   4) 민감 필드는 *string 으로 선언하여 "백업에 없음(nil)"과 "빈 문자열"을
//      구분하고, 덮어쓰기 시 기존 서버의 값을 보존할 수 있게 한다.
// ============================================================================

// ConfigTransfer 설정 프로필 전송 DTO.
type ConfigTransfer struct {
	Name        string `json:"name"`
	RobotName   string `json:"robot_name"`
	Environment string `json:"environment"`
	IsActive    bool   `json:"is_active"`
	Description string `json:"description"`

	RosDomainId int    `json:"ros_domain_id"`
	AgentId     string `json:"agent_id"`

	LlmProvider    string `json:"llm_provider"`
	LlmModel       string `json:"llm_model"`
	LlmToolCalling bool   `json:"llm_tool_calling"`

	AzureOpenaiEndpoint string  `json:"azure_openai_endpoint"`
	AzureOpenaiApiKey   *string `json:"azure_openai_api_key,omitempty"`
	OpenaiApiKey        *string `json:"openai_api_key,omitempty"`
	AnthropicApiKey     *string `json:"anthropic_api_key,omitempty"`

	OllamaBaseUrl     string `json:"ollama_base_url"`
	OllamaOptionsJson string `json:"ollama_options_json"`

	EnableRag            bool    `json:"enable_rag"`
	LlmEmbeddingModel    string  `json:"llm_embedding_model"`
	LlmEmbeddingProvider string  `json:"llm_embedding_provider"`
	LlmEmbeddingBaseUrl  string  `json:"llm_embedding_base_url"`
	LlmEmbeddingApiKey   *string `json:"llm_embedding_api_key,omitempty"`
	RagVectorBackend     string  `json:"rag_vector_backend"`
	QdrantUrl            string  `json:"qdrant_url"`
	QdrantCollection     string  `json:"qdrant_collection"`

	EnableDiscord                 bool    `json:"enable_discord"`
	EnableTelegram                bool    `json:"enable_telegram"`
	EnableSlack                   bool    `json:"enable_slack"`
	EnableGrpc                    bool    `json:"enable_grpc"`
	UseGrpc                       bool    `json:"use_grpc"`
	EnableGrpcClient              bool    `json:"enable_grpc_client"`
	GrpcPort                      *int    `json:"grpc_port,omitempty"`
	GrpcPeerToken                 *string `json:"grpc_peer_token,omitempty"`
	GrpcTargetHost                string  `json:"grpc_target_host"`
	GrpcTargetPort                int     `json:"grpc_target_port"`
	GrpcTargetPeersJson           string  `json:"grpc_target_peers_json"`
	CloidCleanupDemoEnabled       *bool   `json:"cloid_cleanup_demo_enabled,omitempty"`
	CloidCleanupDemoMotionIDsJson string  `json:"cloid_cleanup_demo_motion_ids_json"`
	CloidExpressionEnabled        *bool   `json:"cloid_expression_enabled,omitempty"`
	CloidNavigationPoseEnabled    *bool   `json:"cloid_navigation_pose_enabled,omitempty"`
	CleanupRunLogPath             string  `json:"cleanup_run_log_path"`
	DiscordBotToken               *string `json:"discord_bot_token,omitempty"`
	SlackAppToken                 *string `json:"slack_app_token,omitempty"`
	SlackBotToken                 *string `json:"slack_bot_token,omitempty"`
	TelegramBotToken              *string `json:"telegram_bot_token,omitempty"`

	SoulContent            string `json:"soul_content"`
	SkillsContent          string `json:"skills_content"`
	TroubleshootingContent string `json:"troubleshooting_content"`
	LimitsContent          string `json:"limits_content"`

	HttpHost               string  `json:"http_host"`
	HttpPort               int     `json:"http_port"`
	HttpReadonlyToken      *string `json:"http_readonly_token,omitempty"`
	HttpControlToken       *string `json:"http_control_token,omitempty"`
	HttpAllowedCidrsJson   string  `json:"http_allowed_cidrs_json"`
	HttpRateLimitPerMinute int     `json:"http_rate_limit_per_minute"`
	HttpAllowedSkillsJson  string  `json:"http_allowed_skills_json"`
	HttpBlockedSkillsJson  string  `json:"http_blocked_skills_json"`

	DashboardEnabled bool   `json:"use_dashboard"`
	DashboardHost    string `json:"dashboard_host"`
	DashboardPort    int    `json:"dashboard_port"`

	EnableMcp      bool    `json:"enable_mcp"`
	McpServersJson *string `json:"mcp_servers_json,omitempty"`

	RagTopK           int     `json:"rag_top_k"`
	RagScoreThreshold float64 `json:"rag_score_threshold"`
	QdrantApiKey      *string `json:"qdrant_api_key,omitempty"`
	QdrantTimeoutSec  float64 `json:"qdrant_timeout_sec"`
	RagLocalMirror    bool    `json:"rag_local_mirror"`
	MemoryDir         string  `json:"memory_dir"`

	AgentWorkspaceDir    string `json:"agent_workspace_dir"`
	ButlerScriptsDir     string `json:"butler_scripts_dir"`
	ButlerSourceDir      string `json:"butler_source_dir"`
	ConfigDir            string `json:"config_dir"`
	SystemPromptFile     string `json:"system_prompt_file"`
	RobotDescriptionFile string `json:"robot_description_file"`

	CameraTopic                 string  `json:"camera_topic"`
	UseVision                   bool    `json:"use_vision"`
	VisionModelPath             string  `json:"vision_model_path"`
	GripperCameraTopic          string  `json:"gripper_camera_topic"`
	GripperDepthTopic           string  `json:"gripper_depth_topic"`
	GripperCameraInfoTopic      string  `json:"gripper_camera_info_topic"`
	GripperPointcloudTopic      string  `json:"gripper_pointcloud_topic"`
	UseGripperVision            bool    `json:"use_gripper_vision"`
	GripperVisionMaxInferenceHz float64 `json:"gripper_vision_max_inference_hz"`

	LidarTopic string `json:"lidar_topic"`
	ImuTopic   string `json:"imu_topic"`

	Debug bool `json:"debug"`

	EnableSkillLearning             bool    `json:"enable_skill_learning"`
	SkillLearningSuccessSampleRate  float64 `json:"skill_learning_success_sample_rate"`
	SkillLearningReflectIntervalSec int     `json:"skill_learning_reflect_interval_sec"`

	TaskQueueMaxSize                  int     `json:"task_queue_max_size"`
	LlmFailFast                       bool    `json:"llm_fail_fast"`
	StrictConfig                      bool    `json:"strict_config"`
	EnableTaskDecomposition           bool    `json:"enable_task_decomposition"`
	TaskDecompositionMaxSteps         int     `json:"task_decomposition_max_steps"`
	TaskStepMaxRetries                int     `json:"task_step_max_retries"`
	TaskDecompositionWaitMarginCapSec float64 `json:"task_decomposition_wait_margin_cap_sec"`

	LangsmithTracing     bool    `json:"langsmith_tracing"`
	LangsmithApiKey      *string `json:"langsmith_api_key,omitempty"`
	LangsmithProject     string  `json:"langsmith_project"`
	LangsmithEndpoint    string  `json:"langsmith_endpoint"`
	LangsmithWorkspaceId string  `json:"langsmith_workspace_id"`

	LangfuseTracing   bool    `json:"langfuse_tracing"`
	LangfusePublicKey *string `json:"langfuse_public_key,omitempty"`
	LangfuseSecretKey *string `json:"langfuse_secret_key,omitempty"`
	LangfuseHost      string  `json:"langfuse_host"`

	System1Router             string  `json:"system1_router"`
	System1Shadow             bool    `json:"system1_shadow"`
	System1ShadowLog          string  `json:"system1_shadow_log"`
	System1StepRouting        string  `json:"system1_step_routing"`
	System1Scope              string  `json:"system1_scope"`
	System1Endpoint           string  `json:"system1_endpoint"`
	System1Provider           string  `json:"system1_provider"`
	System1TimeoutMs          float64 `json:"system1_timeout_ms"`
	System1ConfThresholdsJson string  `json:"system1_conf_thresholds_json"`
	System1Skills             string  `json:"system1_skills"`
	System1MaxOptions         int     `json:"system1_max_options"`
	System1ApiKey             *string `json:"system1_api_key,omitempty"`

	// ── Maestro FleetControl outbound connector (contract v2.2.0) ──
	MaestroEnabled          bool    `json:"maestro_enabled"`
	MaestroIp               string  `json:"maestro_ip"`
	RobotPort               int     `json:"robot_port"`
	RobotId                 string  `json:"robot_id"`
	RobotSiteId             string  `json:"robot_site_id"`
	RobotMapId              string  `json:"robot_map_id"`
	RobotMapVersion         string  `json:"robot_map_version"`
	RobotMapFrameId         string  `json:"robot_map_frame_id"`
	MaestroDisconnectPolicy string  `json:"maestro_disconnect_policy"`
	FleetHeartbeatSec       float64 `json:"fleet_heartbeat_sec"`
	FleetCommandJournalPath string  `json:"fleet_command_journal_path"`
	FleetSkillsGuideFile    string  `json:"skills_guide_file"`
	FleetControlTls         bool    `json:"fleet_control_tls"`
	FleetControlCaCert      string  `json:"fleet_control_ca_cert"`
	FleetControlClientCert  string  `json:"fleet_control_client_cert"`
	FleetControlClientKey   string  `json:"fleet_control_client_key"`
}

// ScenarioTransfer 테스트 시나리오 전송 DTO.
type ScenarioTransfer struct {
	Name        string             `json:"name"`
	Description string             `json:"description"`
	RobotName   string             `json:"robot_name"`
	Environment string             `json:"environment"`
	IsActive    bool               `json:"is_active"`
	TestCases   []TestCaseTransfer `json:"test_cases"`
}

// TestCaseTransfer 개별 테스트 케이스 전송 DTO.
type TestCaseTransfer struct {
	ID        string         `json:"id"`
	Name      string         `json:"name"`
	Step      string         `json:"step"`
	Type      string         `json:"type"`
	TimeoutMs int            `json:"timeout_ms"`
	Enabled   bool           `json:"enabled"`
	Params    map[string]any `json:"params,omitempty"`
}
