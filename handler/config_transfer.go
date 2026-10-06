package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"ai-config-server/database"
	"ai-config-server/database/models"
)

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

const (
	BackupKind             = "ai-config-server.portable-backup"
	BackupSchemaVersion    = 1
	MaskValue              = "********"
	ConflictSkip           = "skip"
	ConflictOverwrite      = "overwrite"
	ConflictCopy           = "copy"
	ActivationInactive     = "inactive"
	ActivationPreserve     = "preserve"
	ActivationKeepExisting = "keep_existing"
)

// BackupDocument 백업 파일 최상위 구조.
type BackupDocument struct {
	Kind            string             `json:"kind"`
	SchemaVersion   int                `json:"schema_version"`
	ExportedAt      time.Time          `json:"exported_at"`
	IncludesSecrets bool               `json:"includes_secrets"`
	Configs         []ConfigTransfer   `json:"configs"`
	Scenarios       []ScenarioTransfer `json:"scenarios"`
}

// ConfigTransfer 설정 프로필 전송 DTO.
type ConfigTransfer struct {
	Name        string `json:"name"`
	RobotName   string `json:"robot_name"`
	Environment string `json:"environment"`
	IsActive    bool   `json:"is_active"`
	Description string `json:"description"`

	RosDomainId int    `json:"ros_domain_id"`
	AgentId     string `json:"agent_id"`

	LlmProvider string `json:"llm_provider"`
	LlmModel    string `json:"llm_model"`

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

	EnableDiscord       bool    `json:"enable_discord"`
	EnableTelegram      bool    `json:"enable_telegram"`
	EnableSlack         bool    `json:"enable_slack"`
	EnableGrpc          bool    `json:"enable_grpc"`
	UseGrpc             bool    `json:"use_grpc"`
	EnableGrpcClient    bool    `json:"enable_grpc_client"`
	GrpcTargetHost      string  `json:"grpc_target_host"`
	GrpcTargetPort      int     `json:"grpc_target_port"`
	GrpcTargetPeersJson string  `json:"grpc_target_peers_json"`
	DiscordBotToken     *string `json:"discord_bot_token,omitempty"`
	SlackAppToken       *string `json:"slack_app_token,omitempty"`
	SlackBotToken       *string `json:"slack_bot_token,omitempty"`
	TelegramBotToken    *string `json:"telegram_bot_token,omitempty"`

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

	DashboardHost string `json:"dashboard_host"`
	DashboardPort int    `json:"dashboard_port"`

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

	System1Router             string  `json:"system1_router"`
	System1Shadow             bool    `json:"system1_shadow"`
	System1ShadowLog          string  `json:"system1_shadow_log"`
	System1Scope              string  `json:"system1_scope"`
	System1Endpoint           string  `json:"system1_endpoint"`
	System1Provider           string  `json:"system1_provider"`
	System1TimeoutMs          float64 `json:"system1_timeout_ms"`
	System1ConfThresholdsJson string  `json:"system1_conf_thresholds_json"`
	System1Skills             string  `json:"system1_skills"`
	System1MaxOptions         int     `json:"system1_max_options"`
	System1ApiKey             *string `json:"system1_api_key,omitempty"`

	// ── Maestro FleetControl outbound connector (contract v2.2.0) ──
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

// ExportRequest POST /transfer/export 본문. GET 쿼리 파라미터와 동일 의미.
type ExportRequest struct {
	IncludeSecrets   bool `json:"include_secrets"`
	IncludeConfigs   bool `json:"include_configs"`
	IncludeScenarios bool `json:"include_scenarios"`
}

// ImportOptions 가져오기 옵션.
type ImportOptions struct {
	ConflictPolicy   string `json:"conflict_policy"`   // skip | overwrite | copy
	ActivationPolicy string `json:"activation_policy"` // inactive | preserve | keep_existing
}

// ImportRequest 가져오기 요청 본문.
type ImportRequest struct {
	Document BackupDocument `json:"document"`
	Options  ImportOptions  `json:"options"`
}

// ImportSummary 검증 요약.
type ImportSummary struct {
	Configs              int `json:"configs"`
	Scenarios            int `json:"scenarios"`
	NewConfigs           int `json:"new_configs"`
	ConflictingConfigs   int `json:"conflicting_configs"`
	NewScenarios         int `json:"new_scenarios"`
	ConflictingScenarios int `json:"conflicting_scenarios"`
}

// ImportValidationResult 가져오기 검증 결과.
type ImportValidationResult struct {
	Valid           bool          `json:"valid"`
	SchemaVersion   int           `json:"schema_version"`
	IncludesSecrets bool          `json:"includes_secrets"`
	Summary         ImportSummary `json:"summary"`
	Warnings        []string      `json:"warnings"`
	Errors          []string      `json:"errors"`
}

// ImportActionResult 가져오기 실행 단위 결과.
type ImportActionResult struct {
	Created int `json:"created"`
	Updated int `json:"updated"`
	Skipped int `json:"skipped"`
}

// ImportResult 가져오기 실행 전체 결과.
type ImportResult struct {
	Configs   ImportActionResult `json:"configs"`
	Scenarios ImportActionResult `json:"scenarios"`
}

// ============================================================================
// 변환 헬퍼
// ============================================================================

func strPtr(s string) *string { return new(s) }

// configToTransfer는 DB 원본(마스킹 전)을 전송 DTO로 변환한다.
// includeSecrets=false 이면 민감 필드를 생략한다.
func configToTransfer(cfg *models.RoboClawConfig, includeSecrets bool) ConfigTransfer {
	t := ConfigTransfer{
		Name:                              cfg.Name,
		RobotName:                         cfg.RobotName,
		Environment:                       cfg.Environment,
		IsActive:                          cfg.IsActive,
		Description:                       cfg.Description,
		RosDomainId:                       cfg.RosDomainId,
		AgentId:                           cfg.AgentId,
		LlmProvider:                       cfg.LlmProvider,
		LlmModel:                          cfg.LlmModel,
		AzureOpenaiEndpoint:               cfg.AzureOpenaiEndpoint,
		OllamaBaseUrl:                     cfg.OllamaBaseUrl,
		OllamaOptionsJson:                 cfg.OllamaOptionsJson,
		EnableRag:                         cfg.EnableRag,
		LlmEmbeddingModel:                 cfg.LlmEmbeddingModel,
		LlmEmbeddingProvider:              cfg.LlmEmbeddingProvider,
		LlmEmbeddingBaseUrl:               cfg.LlmEmbeddingBaseUrl,
		RagVectorBackend:                  cfg.RagVectorBackend,
		QdrantUrl:                         cfg.QdrantUrl,
		QdrantCollection:                  cfg.QdrantCollection,
		EnableDiscord:                     cfg.EnableDiscord,
		EnableTelegram:                    cfg.EnableTelegram,
		EnableSlack:                       cfg.EnableSlack,
		EnableGrpc:                        cfg.EnableGrpc,
		UseGrpc:                           cfg.UseGrpc,
		EnableGrpcClient:                  cfg.EnableGrpcClient,
		GrpcTargetHost:                    cfg.GrpcTargetHost,
		GrpcTargetPort:                    cfg.GrpcTargetPort,
		GrpcTargetPeersJson:               cfg.GrpcTargetPeersJson,
		SoulContent:                       cfg.SoulContent,
		SkillsContent:                     cfg.SkillsContent,
		TroubleshootingContent:            cfg.TroubleshootingContent,
		LimitsContent:                     cfg.LimitsContent,
		HttpHost:                          cfg.HttpHost,
		HttpPort:                          cfg.HttpPort,
		HttpAllowedCidrsJson:              cfg.HttpAllowedCidrsJson,
		HttpRateLimitPerMinute:            cfg.HttpRateLimitPerMinute,
		HttpAllowedSkillsJson:             cfg.HttpAllowedSkillsJson,
		HttpBlockedSkillsJson:             cfg.HttpBlockedSkillsJson,
		DashboardHost:                     cfg.DashboardHost,
		DashboardPort:                     cfg.DashboardPort,
		EnableMcp:                         cfg.EnableMcp,
		RagTopK:                           cfg.RagTopK,
		RagScoreThreshold:                 cfg.RagScoreThreshold,
		QdrantTimeoutSec:                  cfg.QdrantTimeoutSec,
		RagLocalMirror:                    cfg.RagLocalMirror,
		MemoryDir:                         cfg.MemoryDir,
		AgentWorkspaceDir:                 cfg.AgentWorkspaceDir,
		ButlerScriptsDir:                  cfg.ButlerScriptsDir,
		ButlerSourceDir:                   cfg.ButlerSourceDir,
		ConfigDir:                         cfg.ConfigDir,
		SystemPromptFile:                  cfg.SystemPromptFile,
		RobotDescriptionFile:              cfg.RobotDescriptionFile,
		CameraTopic:                       cfg.CameraTopic,
		UseVision:                         cfg.UseVision,
		VisionModelPath:                   cfg.VisionModelPath,
		GripperCameraTopic:                cfg.GripperCameraTopic,
		GripperDepthTopic:                 cfg.GripperDepthTopic,
		GripperCameraInfoTopic:            cfg.GripperCameraInfoTopic,
		GripperPointcloudTopic:            cfg.GripperPointcloudTopic,
		UseGripperVision:                  cfg.UseGripperVision,
		GripperVisionMaxInferenceHz:       cfg.GripperVisionMaxInferenceHz,
		LidarTopic:                        cfg.LidarTopic,
		ImuTopic:                          cfg.ImuTopic,
		Debug:                             cfg.Debug,
		EnableSkillLearning:               cfg.EnableSkillLearning,
		SkillLearningSuccessSampleRate:    cfg.SkillLearningSuccessSampleRate,
		SkillLearningReflectIntervalSec:   cfg.SkillLearningReflectIntervalSec,
		TaskQueueMaxSize:                  cfg.TaskQueueMaxSize,
		LlmFailFast:                       cfg.LlmFailFast,
		StrictConfig:                      cfg.StrictConfig,
		EnableTaskDecomposition:           cfg.EnableTaskDecomposition,
		TaskDecompositionMaxSteps:         cfg.TaskDecompositionMaxSteps,
		TaskStepMaxRetries:                cfg.TaskStepMaxRetries,
		TaskDecompositionWaitMarginCapSec: cfg.TaskDecompositionWaitMarginCapSec,
		LangsmithTracing:                  cfg.LangsmithTracing,
		LangsmithProject:                  cfg.LangsmithProject,
		LangsmithEndpoint:                 cfg.LangsmithEndpoint,
		LangsmithWorkspaceId:              cfg.LangsmithWorkspaceId,
		System1Router:                     cfg.System1Router,
		System1Shadow:                     cfg.System1Shadow,
		System1ShadowLog:                  cfg.System1ShadowLog,
		System1Scope:                      cfg.System1Scope,
		System1Endpoint:                   cfg.System1Endpoint,
		System1Provider:                   cfg.System1Provider,
		System1TimeoutMs:                  cfg.System1TimeoutMs,
		System1ConfThresholdsJson:         cfg.System1ConfThresholdsJson,
		System1Skills:                     cfg.System1Skills,
		System1MaxOptions:                 cfg.System1MaxOptions,
		MaestroIp:                         cfg.MaestroIp,
		RobotPort:                         cfg.RobotPort,
		RobotId:                           cfg.RobotId,
		RobotSiteId:                       cfg.RobotSiteId,
		RobotMapId:                        cfg.RobotMapId,
		RobotMapVersion:                   cfg.RobotMapVersion,
		RobotMapFrameId:                   cfg.RobotMapFrameId,
		MaestroDisconnectPolicy:           cfg.MaestroDisconnectPolicy,
		FleetHeartbeatSec:                 cfg.FleetHeartbeatSec,
		FleetCommandJournalPath:           cfg.FleetCommandJournalPath,
		FleetSkillsGuideFile:              cfg.FleetSkillsGuideFile,
		FleetControlTls:                   cfg.FleetControlTls,
		FleetControlCaCert:                cfg.FleetControlCaCert,
		FleetControlClientCert:            cfg.FleetControlClientCert,
		FleetControlClientKey:             cfg.FleetControlClientKey,
	}

	if includeSecrets {
		t.AzureOpenaiApiKey = strPtr(cfg.AzureOpenaiApiKey)
		t.OpenaiApiKey = strPtr(cfg.OpenaiApiKey)
		t.AnthropicApiKey = strPtr(cfg.AnthropicApiKey)
		t.LlmEmbeddingApiKey = strPtr(cfg.LlmEmbeddingApiKey)
		t.DiscordBotToken = strPtr(cfg.DiscordBotToken)
		t.SlackAppToken = strPtr(cfg.SlackAppToken)
		t.SlackBotToken = strPtr(cfg.SlackBotToken)
		t.TelegramBotToken = strPtr(cfg.TelegramBotToken)
		t.HttpReadonlyToken = strPtr(cfg.HttpReadonlyToken)
		t.HttpControlToken = strPtr(cfg.HttpControlToken)
		t.QdrantApiKey = strPtr(cfg.QdrantApiKey)
		t.LangsmithApiKey = strPtr(cfg.LangsmithApiKey)
		t.System1ApiKey = strPtr(cfg.System1ApiKey)
		t.McpServersJson = strPtr(cfg.McpServersJson)
	}
	return t
}

// toModel은 전송 DTO를 DB 모델로 변환한다.
// 민감 필드가 nil(백업에 없음)이고 기존 레코드가 있으면 기존 값을 보존한다.
func (t ConfigTransfer) toModel(existing *models.RoboClawConfig) models.RoboClawConfig {
	resolve := func(p *string, cur string) string {
		if p == nil {
			return cur
		}
		return *p
	}
	// existing 이 없으면 기본 빈 문자열로 처리
	var cur *models.RoboClawConfig
	if existing != nil {
		cur = existing
	}
	curStr := func(get func(c *models.RoboClawConfig) string) string {
		if cur == nil {
			return ""
		}
		return get(cur)
	}

	cfg := models.RoboClawConfig{
		Name:                              t.Name,
		RobotName:                         t.RobotName,
		Environment:                       t.Environment,
		IsActive:                          t.IsActive,
		Description:                       t.Description,
		RosDomainId:                       t.RosDomainId,
		AgentId:                           t.AgentId,
		LlmProvider:                       t.LlmProvider,
		LlmModel:                          t.LlmModel,
		AzureOpenaiEndpoint:               t.AzureOpenaiEndpoint,
		AzureOpenaiApiKey:                 resolve(t.AzureOpenaiApiKey, curStr(func(c *models.RoboClawConfig) string { return c.AzureOpenaiApiKey })),
		OpenaiApiKey:                      resolve(t.OpenaiApiKey, curStr(func(c *models.RoboClawConfig) string { return c.OpenaiApiKey })),
		AnthropicApiKey:                   resolve(t.AnthropicApiKey, curStr(func(c *models.RoboClawConfig) string { return c.AnthropicApiKey })),
		OllamaBaseUrl:                     t.OllamaBaseUrl,
		OllamaOptionsJson:                 t.OllamaOptionsJson,
		EnableRag:                         t.EnableRag,
		LlmEmbeddingModel:                 t.LlmEmbeddingModel,
		LlmEmbeddingProvider:              t.LlmEmbeddingProvider,
		LlmEmbeddingBaseUrl:               t.LlmEmbeddingBaseUrl,
		LlmEmbeddingApiKey:                resolve(t.LlmEmbeddingApiKey, curStr(func(c *models.RoboClawConfig) string { return c.LlmEmbeddingApiKey })),
		RagVectorBackend:                  t.RagVectorBackend,
		QdrantUrl:                         t.QdrantUrl,
		QdrantCollection:                  t.QdrantCollection,
		EnableDiscord:                     t.EnableDiscord,
		EnableTelegram:                    t.EnableTelegram,
		EnableSlack:                       t.EnableSlack,
		EnableGrpc:                        t.EnableGrpc,
		UseGrpc:                           t.UseGrpc,
		EnableGrpcClient:                  t.EnableGrpcClient,
		GrpcTargetHost:                    t.GrpcTargetHost,
		GrpcTargetPort:                    t.GrpcTargetPort,
		GrpcTargetPeersJson:               t.GrpcTargetPeersJson,
		DiscordBotToken:                   resolve(t.DiscordBotToken, curStr(func(c *models.RoboClawConfig) string { return c.DiscordBotToken })),
		SlackAppToken:                     resolve(t.SlackAppToken, curStr(func(c *models.RoboClawConfig) string { return c.SlackAppToken })),
		SlackBotToken:                     resolve(t.SlackBotToken, curStr(func(c *models.RoboClawConfig) string { return c.SlackBotToken })),
		TelegramBotToken:                  resolve(t.TelegramBotToken, curStr(func(c *models.RoboClawConfig) string { return c.TelegramBotToken })),
		SoulContent:                       t.SoulContent,
		SkillsContent:                     t.SkillsContent,
		TroubleshootingContent:            t.TroubleshootingContent,
		LimitsContent:                     t.LimitsContent,
		HttpHost:                          t.HttpHost,
		HttpPort:                          t.HttpPort,
		HttpReadonlyToken:                 resolve(t.HttpReadonlyToken, curStr(func(c *models.RoboClawConfig) string { return c.HttpReadonlyToken })),
		HttpControlToken:                  resolve(t.HttpControlToken, curStr(func(c *models.RoboClawConfig) string { return c.HttpControlToken })),
		HttpAllowedCidrsJson:              t.HttpAllowedCidrsJson,
		HttpRateLimitPerMinute:            t.HttpRateLimitPerMinute,
		HttpAllowedSkillsJson:             t.HttpAllowedSkillsJson,
		HttpBlockedSkillsJson:             t.HttpBlockedSkillsJson,
		DashboardHost:                     t.DashboardHost,
		DashboardPort:                     t.DashboardPort,
		EnableMcp:                         t.EnableMcp,
		McpServersJson:                    resolve(t.McpServersJson, curStr(func(c *models.RoboClawConfig) string { return c.McpServersJson })),
		RagTopK:                           t.RagTopK,
		RagScoreThreshold:                 t.RagScoreThreshold,
		QdrantApiKey:                      resolve(t.QdrantApiKey, curStr(func(c *models.RoboClawConfig) string { return c.QdrantApiKey })),
		QdrantTimeoutSec:                  t.QdrantTimeoutSec,
		RagLocalMirror:                    t.RagLocalMirror,
		MemoryDir:                         t.MemoryDir,
		AgentWorkspaceDir:                 t.AgentWorkspaceDir,
		ButlerScriptsDir:                  t.ButlerScriptsDir,
		ButlerSourceDir:                   t.ButlerSourceDir,
		ConfigDir:                         t.ConfigDir,
		SystemPromptFile:                  t.SystemPromptFile,
		RobotDescriptionFile:              t.RobotDescriptionFile,
		CameraTopic:                       t.CameraTopic,
		UseVision:                         t.UseVision,
		VisionModelPath:                   t.VisionModelPath,
		GripperCameraTopic:                t.GripperCameraTopic,
		GripperDepthTopic:                 t.GripperDepthTopic,
		GripperCameraInfoTopic:            t.GripperCameraInfoTopic,
		GripperPointcloudTopic:            t.GripperPointcloudTopic,
		UseGripperVision:                  t.UseGripperVision,
		GripperVisionMaxInferenceHz:       t.GripperVisionMaxInferenceHz,
		LidarTopic:                        t.LidarTopic,
		ImuTopic:                          t.ImuTopic,
		Debug:                             t.Debug,
		EnableSkillLearning:               t.EnableSkillLearning,
		SkillLearningSuccessSampleRate:    t.SkillLearningSuccessSampleRate,
		SkillLearningReflectIntervalSec:   t.SkillLearningReflectIntervalSec,
		TaskQueueMaxSize:                  t.TaskQueueMaxSize,
		LlmFailFast:                       t.LlmFailFast,
		StrictConfig:                      t.StrictConfig,
		EnableTaskDecomposition:           t.EnableTaskDecomposition,
		TaskDecompositionMaxSteps:         t.TaskDecompositionMaxSteps,
		TaskStepMaxRetries:                t.TaskStepMaxRetries,
		TaskDecompositionWaitMarginCapSec: t.TaskDecompositionWaitMarginCapSec,
		LangsmithTracing:                  t.LangsmithTracing,
		LangsmithApiKey:                   resolve(t.LangsmithApiKey, curStr(func(c *models.RoboClawConfig) string { return c.LangsmithApiKey })),
		LangsmithProject:                  t.LangsmithProject,
		LangsmithEndpoint:                 t.LangsmithEndpoint,
		LangsmithWorkspaceId:              t.LangsmithWorkspaceId,
		System1Router:                     t.System1Router,
		System1Shadow:                     t.System1Shadow,
		System1ShadowLog:                  t.System1ShadowLog,
		System1Scope:                      t.System1Scope,
		System1Endpoint:                   t.System1Endpoint,
		System1Provider:                   t.System1Provider,
		System1TimeoutMs:                  t.System1TimeoutMs,
		System1ConfThresholdsJson:         t.System1ConfThresholdsJson,
		System1Skills:                     t.System1Skills,
		System1MaxOptions:                 t.System1MaxOptions,
		System1ApiKey:                     resolve(t.System1ApiKey, curStr(func(c *models.RoboClawConfig) string { return c.System1ApiKey })),
		MaestroIp:                         t.MaestroIp,
		RobotPort:                         t.RobotPort,
		RobotId:                           t.RobotId,
		RobotSiteId:                       t.RobotSiteId,
		RobotMapId:                        t.RobotMapId,
		RobotMapVersion:                   t.RobotMapVersion,
		RobotMapFrameId:                   t.RobotMapFrameId,
		MaestroDisconnectPolicy:           t.MaestroDisconnectPolicy,
		FleetHeartbeatSec:                 t.FleetHeartbeatSec,
		FleetCommandJournalPath:           t.FleetCommandJournalPath,
		FleetSkillsGuideFile:              t.FleetSkillsGuideFile,
		FleetControlTls:                   t.FleetControlTls,
		FleetControlCaCert:                t.FleetControlCaCert,
		FleetControlClientCert:            t.FleetControlClientCert,
		FleetControlClientKey:             t.FleetControlClientKey,
	}
	return cfg
}

func scenarioToTransfer(s *models.TestScenario) ScenarioTransfer {
	tc := make([]TestCaseTransfer, 0, len(s.TestCases))
	for _, c := range s.TestCases {
		tc = append(tc, TestCaseTransfer{
			ID:        c.ID,
			Name:      c.Name,
			Step:      c.Step,
			Type:      c.Type,
			TimeoutMs: c.TimeoutMs,
			Enabled:   c.Enabled,
			Params:    c.Params,
		})
	}
	return ScenarioTransfer{
		Name:        s.Name,
		Description: s.Description,
		RobotName:   s.RobotName,
		Environment: s.Environment,
		IsActive:    s.IsActive,
		TestCases:   tc,
	}
}

func (t ScenarioTransfer) toModel() models.TestScenario {
	tc := make(models.TestCaseList, 0, len(t.TestCases))
	for _, c := range t.TestCases {
		tc = append(tc, models.TestCase{
			ID:        c.ID,
			Name:      c.Name,
			Step:      c.Step,
			Type:      c.Type,
			TimeoutMs: c.TimeoutMs,
			Enabled:   c.Enabled,
			Params:    c.Params,
		})
	}
	return models.TestScenario{
		Name:        t.Name,
		Description: t.Description,
		RobotName:   t.RobotName,
		Environment: t.Environment,
		IsActive:    t.IsActive,
		TestCases:   tc,
	}
}

// ============================================================================
// 키 구성 (name + robot_name + environment)
// ============================================================================

func configKey(cfg *models.RoboClawConfig) string {
	return cfg.Name + "|" + cfg.RobotName + "|" + cfg.Environment
}

func transferConfigKey(name, robot, env string) string {
	return name + "|" + robot + "|" + env
}

func scenarioKey(s *models.TestScenario) string {
	return s.Name + "|" + s.RobotName + "|" + s.Environment
}

func transferScenarioKey(name, robot, env string) string {
	return name + "|" + robot + "|" + env
}

func loadConfigKeyMap(tx *gorm.DB) (map[string]*models.RoboClawConfig, error) {
	var configs []models.RoboClawConfig
	if err := tx.Find(&configs).Error; err != nil {
		return nil, err
	}
	m := make(map[string]*models.RoboClawConfig, len(configs))
	for i := range configs {
		m[configKey(&configs[i])] = &configs[i]
	}
	return m, nil
}

func loadScenarioKeyMap(tx *gorm.DB) (map[string]*models.TestScenario, error) {
	var scenarios []models.TestScenario
	if err := tx.Find(&scenarios).Error; err != nil {
		return nil, err
	}
	m := make(map[string]*models.TestScenario, len(scenarios))
	for i := range scenarios {
		m[scenarioKey(&scenarios[i])] = &scenarios[i]
	}
	return m, nil
}

// ============================================================================
// 내보내기 API
// ============================================================================

// ExportBackup GET|POST /api/v1/admin/transfer/export
// DB 원본(마스킹 전) 값을 읽어 이식용 백업 JSON을 생성한다.
func ExportBackup(c *gin.Context) {
	var req ExportRequest
	if c.Request.Method == http.MethodPost {
		if err := c.ShouldBindJSON(&req); err != nil {
			LogAndRespondError(c, http.StatusBadRequest, "내보내기 요청 JSON 유효성 검증에 실패했습니다.", err)
			return
		}
	} else {
		req.IncludeSecrets = c.Query("include_secrets") == "true"
		req.IncludeConfigs = c.Query("include_configs") != "false"
		req.IncludeScenarios = c.Query("include_scenarios") != "false"
	}

	doc := BackupDocument{
		Kind:            BackupKind,
		SchemaVersion:   BackupSchemaVersion,
		ExportedAt:      time.Now(),
		IncludesSecrets: req.IncludeSecrets,
		Configs:         []ConfigTransfer{},
		Scenarios:       []ScenarioTransfer{},
	}

	if req.IncludeConfigs {
		var configs []models.RoboClawConfig
		if err := database.DB.Find(&configs).Error; err != nil {
			LogAndRespondError(c, http.StatusInternalServerError, "설정 데이터를 조회하는 중 오류가 발생했습니다.", err)
			return
		}
		for i := range configs {
			doc.Configs = append(doc.Configs, configToTransfer(&configs[i], req.IncludeSecrets))
		}
	}

	if req.IncludeScenarios {
		var scenarios []models.TestScenario
		if err := database.DB.Find(&scenarios).Error; err != nil {
			LogAndRespondError(c, http.StatusInternalServerError, "테스트 시나리오 데이터를 조회하는 중 오류가 발생했습니다.", err)
			return
		}
		for i := range scenarios {
			doc.Scenarios = append(doc.Scenarios, scenarioToTransfer(&scenarios[i]))
		}
	}

	LogInfo("[SUCCESS] 백업 내보내기 완료 | configs=%d, scenarios=%d, secrets=%t", len(doc.Configs), len(doc.Scenarios), req.IncludeSecrets)

	filename := fmt.Sprintf("ai-config-backup-%s.json", time.Now().Format("20060102-150405"))
	if req.IncludeSecrets {
		filename = fmt.Sprintf("ai-config-backup-with-secrets-%s.json", time.Now().Format("20060102-150405"))
	}
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%q", filename))
	c.JSON(http.StatusOK, doc)
}

// ============================================================================
// 검증 로직
// ============================================================================

// validateBackupDocument는 백업 문서의 구조/중복/JSON 무결성을 검증한다.
// DB와의 충돌 여부는 existingConfigs/existingScenarios 를 전달받아 판정한다.
func validateBackupDocument(doc *BackupDocument, existingConfigs map[string]*models.RoboClawConfig, existingScenarios map[string]*models.TestScenario) ImportValidationResult {
	res := ImportValidationResult{
		Valid:           true,
		SchemaVersion:   doc.SchemaVersion,
		IncludesSecrets: doc.IncludesSecrets,
		Warnings:        []string{},
		Errors:          []string{},
	}

	// kind 검증
	if doc.Kind != BackupKind {
		res.Errors = append(res.Errors, fmt.Sprintf("지원하지 않는 백업 종류입니다: %q (기대: %q)", doc.Kind, BackupKind))
	}
	// schema version 검증
	if doc.SchemaVersion != BackupSchemaVersion {
		res.Errors = append(res.Errors, fmt.Sprintf("지원하지 않는 스키마 버전입니다: %d (지원: %d)", doc.SchemaVersion, BackupSchemaVersion))
	}

	if !doc.IncludesSecrets {
		res.Warnings = append(res.Warnings, "민감 정보(ApiKey/Token)가 포함되지 않은 백업입니다. 덮어쓰기 시 기존 서버의 민감 값이 유지됩니다.")
	}

	// 설정 내부 중복 탐지
	seenConfigs := map[string]bool{}
	for _, cfg := range doc.Configs {
		if strings.TrimSpace(cfg.Name) == "" || strings.TrimSpace(cfg.RobotName) == "" || strings.TrimSpace(cfg.Environment) == "" {
			res.Errors = append(res.Errors, fmt.Sprintf("설정 항목에 name/robot_name/environment 가 모두 필요합니다. (name=%q, robot=%q, env=%q)", cfg.Name, cfg.RobotName, cfg.Environment))
			continue
		}
		key := transferConfigKey(cfg.Name, cfg.RobotName, cfg.Environment)
		if seenConfigs[key] {
			res.Errors = append(res.Errors, fmt.Sprintf("백업 내에 설정 항목이 중복됩니다: %s", key))
			continue
		}
		seenConfigs[key] = true

		// 중첩 JSON 무결성 검증
		if err := validateJSONFields(cfg.LimitsContent, cfg.OllamaOptionsJson, cfg.HttpAllowedCidrsJson, cfg.HttpAllowedSkillsJson, cfg.HttpBlockedSkillsJson, strOr(cfg.McpServersJson), "", cfg.System1ConfThresholdsJson); err != nil {
			res.Errors = append(res.Errors, fmt.Sprintf("설정 %q: %v", cfg.Name, err))
		}
		if cfg.GrpcTargetPeersJson != "" && !json.Valid([]byte(cfg.GrpcTargetPeersJson)) {
			res.Errors = append(res.Errors, fmt.Sprintf("설정 %q: grpc_target_peers_json 필드의 JSON 형식이 올바르지 않습니다.", cfg.Name))
		}

		if existingConfigs != nil {
			if _, exists := existingConfigs[key]; exists {
				res.Summary.ConflictingConfigs++
			} else {
				res.Summary.NewConfigs++
			}
		}
		res.Summary.Configs++
	}

	// 시나리오 내부 중복 탐지
	seenScenarios := map[string]bool{}
	for _, sc := range doc.Scenarios {
		if strings.TrimSpace(sc.Name) == "" || strings.TrimSpace(sc.RobotName) == "" || strings.TrimSpace(sc.Environment) == "" {
			res.Errors = append(res.Errors, fmt.Sprintf("시나리오 항목에 name/robot_name/environment 가 모두 필요합니다. (name=%q, robot=%q, env=%q)", sc.Name, sc.RobotName, sc.Environment))
			continue
		}
		key := transferScenarioKey(sc.Name, sc.RobotName, sc.Environment)
		if seenScenarios[key] {
			res.Errors = append(res.Errors, fmt.Sprintf("백업 내에 시나리오 항목이 중복됩니다: %s", key))
			continue
		}
		seenScenarios[key] = true

		// 테스트 케이스 필수 필드 검증
		for i, tc := range sc.TestCases {
			if strings.TrimSpace(tc.ID) == "" || strings.TrimSpace(tc.Name) == "" || strings.TrimSpace(tc.Type) == "" {
				res.Errors = append(res.Errors, fmt.Sprintf("시나리오 %q 의 %d번째 테스트 케이스에 id/name/type 가 모두 필요합니다.", sc.Name, i+1))
			}
		}

		if existingScenarios != nil {
			if _, exists := existingScenarios[key]; exists {
				res.Summary.ConflictingScenarios++
			} else {
				res.Summary.NewScenarios++
			}
		}
		res.Summary.Scenarios++
	}

	if len(res.Errors) > 0 {
		res.Valid = false
	}
	return res
}

func strOr(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

// ============================================================================
// 가져오기 검증 API
// ============================================================================

// ValidateImport POST /api/v1/admin/transfer/import/validate
func ValidateImport(c *gin.Context) {
	var req ImportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "검증 요청 JSON 유효성 검증에 실패했습니다.", err)
		return
	}

	existingConfigs, err := loadConfigKeyMap(database.DB)
	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "기존 설정을 조회하는 중 오류가 발생했습니다.", err)
		return
	}
	existingScenarios, err := loadScenarioKeyMap(database.DB)
	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "기존 시나리오를 조회하는 중 오류가 발생했습니다.", err)
		return
	}

	result := validateBackupDocument(&req.Document, existingConfigs, existingScenarios)
	if !result.Valid {
		// 검증 실패 시에도 200 으로 결과를 반환해 프론트엔드가 오류 목록을 표시할 수 있게 한다.
		c.JSON(http.StatusOK, result)
		return
	}
	c.JSON(http.StatusOK, result)
}

// ============================================================================
// 가져오기 실행 API
// ============================================================================

// ImportBackup POST /api/v1/admin/transfer/import
func ImportBackup(c *gin.Context) {
	var req ImportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "가져오기 요청 JSON 유효성 검증에 실패했습니다.", err)
		return
	}

	conflict := req.Options.ConflictPolicy
	if conflict == "" {
		conflict = ConflictSkip
	}
	activation := req.Options.ActivationPolicy
	if activation == "" {
		activation = ActivationInactive
	}
	if conflict != ConflictSkip && conflict != ConflictOverwrite && conflict != ConflictCopy {
		LogAndRespondError(c, http.StatusBadRequest, "지원하지 않는 충돌 정책입니다. (skip | overwrite | copy)", nil)
		return
	}
	if activation != ActivationInactive && activation != ActivationPreserve && activation != ActivationKeepExisting {
		LogAndRespondError(c, http.StatusBadRequest, "지원하지 않는 활성 정책입니다. (inactive | preserve | keep_existing)", nil)
		return
	}

	// 사전 검증 (DB 상태 포함)
	existingConfigs, err := loadConfigKeyMap(database.DB)
	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "기존 설정을 조회하는 중 오류가 발생했습니다.", err)
		return
	}
	existingScenarios, err := loadScenarioKeyMap(database.DB)
	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "기존 시나리오를 조회하는 중 오류가 발생했습니다.", err)
		return
	}
	if vr := validateBackupDocument(&req.Document, existingConfigs, existingScenarios); !vr.Valid {
		c.JSON(http.StatusBadRequest, vr)
		return
	}

	result := ImportResult{
		Configs:   ImportActionResult{},
		Scenarios: ImportActionResult{},
	}

	// 전체를 하나의 트랜잭션으로 처리 (중간 실패 시 전체 롤백)
	err = database.DB.Transaction(func(tx *gorm.DB) error {
		// 최신화된 기존 데이터맵 (덮어쓰기/활성 처리에 사용)
		curConfigs, err := loadConfigKeyMap(tx)
		if err != nil {
			return err
		}
		curScenarios, err := loadScenarioKeyMap(tx)
		if err != nil {
			return err
		}

		cfgResult, err := applyConfigImport(tx, req.Document, conflict, activation, curConfigs)
		if err != nil {
			return err
		}
		result.Configs = cfgResult

		scResult, err := applyScenarioImport(tx, req.Document, conflict, activation, curScenarios)
		if err != nil {
			return err
		}
		result.Scenarios = scResult
		return nil
	})

	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "백업 가져오기 중 오류가 발생하여 전체가 롤백되었습니다.", err)
		return
	}

	LogInfo("[SUCCESS] 백업 가져오기 완료 | configs(created=%d, updated=%d, skipped=%d), scenarios(created=%d, updated=%d, skipped=%d)",
		result.Configs.Created, result.Configs.Updated, result.Configs.Skipped,
		result.Scenarios.Created, result.Scenarios.Updated, result.Scenarios.Skipped)

	clearActiveCache() // 가져온 설정이 즉시 반영되도록 캐시 무효화
	c.JSON(http.StatusOK, result)
}

// applyConfigImport는 설정 항목들을 트랜잭션 내에서 적용한다.
func applyConfigImport(tx *gorm.DB, doc BackupDocument, conflict, activation string, existing map[string]*models.RoboClawConfig) (ImportActionResult, error) {
	res := ImportActionResult{}

	for _, t := range doc.Configs {
		key := transferConfigKey(t.Name, t.RobotName, t.Environment)
		cur := existing[key]

		switch conflict {
		case ConflictSkip:
			if cur != nil {
				res.Skipped++
				continue
			}
		case ConflictCopy:
			if cur != nil {
				newName := uniqueImportName(tx, &models.RoboClawConfig{}, t.Name)
				t.Name = newName
				key = transferConfigKey(newName, t.RobotName, t.Environment)
				cur = nil
			}
		case ConflictOverwrite:
			// cur 유지 (nil이면 신규 생성)
		}

		effectiveActive := t.IsActive
		switch activation {
		case ActivationInactive:
			effectiveActive = false
		case ActivationKeepExisting:
			if cur != nil {
				effectiveActive = cur.IsActive
			} else {
				effectiveActive = false
			}
		}

		model := t.toModel(cur)
		model.IsActive = effectiveActive
		applyButlerPathDefaults(&model)

		// 활성화 대상이면 같은 로봇/환경의 기존 활성 항목을 비활성화
		if effectiveActive {
			if err := tx.Model(&models.RoboClawConfig{}).
				Where("robot_name = ? AND environment = ?", model.RobotName, model.Environment).
				Update("is_active", false).Error; err != nil {
				return res, err
			}
		}

		if cur != nil && conflict != ConflictCopy {
			model.ID = cur.ID
			if err := tx.Save(&model).Error; err != nil {
				return res, err
			}
			res.Updated++
		} else {
			model.ID = 0
			if err := tx.Create(&model).Error; err != nil {
				return res, err
			}
			res.Created++
		}
	}
	return res, nil
}

// applyScenarioImport는 시나리오 항목들을 트랜잭션 내에서 적용한다.
func applyScenarioImport(tx *gorm.DB, doc BackupDocument, conflict, activation string, existing map[string]*models.TestScenario) (ImportActionResult, error) {
	res := ImportActionResult{}

	for _, t := range doc.Scenarios {
		key := transferScenarioKey(t.Name, t.RobotName, t.Environment)
		cur := existing[key]

		switch conflict {
		case ConflictSkip:
			if cur != nil {
				res.Skipped++
				continue
			}
		case ConflictCopy:
			if cur != nil {
				newName := uniqueImportName(tx, &models.TestScenario{}, t.Name)
				t.Name = newName
				key = transferScenarioKey(newName, t.RobotName, t.Environment)
				cur = nil
			}
		case ConflictOverwrite:
			// cur 유지
		}

		effectiveActive := t.IsActive
		switch activation {
		case ActivationInactive:
			effectiveActive = false
		case ActivationKeepExisting:
			if cur != nil {
				effectiveActive = cur.IsActive
			} else {
				effectiveActive = false
			}
		}

		model := t.toModel()
		model.IsActive = effectiveActive

		if effectiveActive {
			if err := tx.Model(&models.TestScenario{}).
				Where("robot_name = ? AND environment = ?", model.RobotName, model.Environment).
				Update("is_active", false).Error; err != nil {
				return res, err
			}
		}

		if cur != nil && conflict != ConflictCopy {
			model.ID = cur.ID
			if err := tx.Save(&model).Error; err != nil {
				return res, err
			}
			res.Updated++
		} else {
			model.ID = 0
			if err := tx.Create(&model).Error; err != nil {
				return res, err
			}
			res.Created++
		}
	}
	return res, nil
}

// uniqueImportName은 base 이름이 이미 존재하면 base_import, base_import_2 ... 를 만든다.
func uniqueImportName(tx *gorm.DB, model any, base string) string {
	candidate := base + "_import"
	if !nameExists(tx, model, candidate) {
		return candidate
	}
	for i := 2; ; i++ {
		c := fmt.Sprintf("%s_%d", candidate, i)
		if !nameExists(tx, model, c) {
			return c
		}
	}
}

func nameExists(tx *gorm.DB, model any, name string) bool {
	var count int64
	tx.Model(model).Where("name = ?", name).Count(&count)
	return count > 0
}
