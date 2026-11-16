package transfer

import (
	"ai-config-server/database/models"
)

func strPtr(s string) *string { return new(s) }
func boolPtr(v bool) *bool    { return new(v) }

// ConfigFromModel은 DB 원본(마스킹 전)을 전송 DTO로 변환한다.
// includeSecrets=false 이면 민감 필드를 생략한다.
func ConfigFromModel(cfg *models.RoboClawConfig, includeSecrets bool) ConfigTransfer {
	cleanupDemoEnabled := true
	if cfg.CloidCleanupDemoEnabled != nil {
		cleanupDemoEnabled = *cfg.CloidCleanupDemoEnabled
	}
	cloidExpressionEnabled := false
	if cfg.CloidExpressionEnabled != nil {
		cloidExpressionEnabled = *cfg.CloidExpressionEnabled
	}
	cloidNavigationPoseEnabled := false
	if cfg.CloidNavigationPoseEnabled != nil {
		cloidNavigationPoseEnabled = *cfg.CloidNavigationPoseEnabled
	}
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
		LlmToolCalling:                    cfg.LlmToolCalling,
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
		GrpcPort:                          new(cfg.GrpcPort),
		GrpcTargetHost:                    cfg.GrpcTargetHost,
		GrpcTargetPort:                    cfg.GrpcTargetPort,
		GrpcTargetPeersJson:               cfg.GrpcTargetPeersJson,
		CloidCleanupDemoEnabled:           boolPtr(cleanupDemoEnabled),
		CloidCleanupDemoMotionIDsJson:     cfg.CloidCleanupDemoMotionIDsJson,
		CloidExpressionEnabled:            boolPtr(cloidExpressionEnabled),
		CloidNavigationPoseEnabled:        boolPtr(cloidNavigationPoseEnabled),
		CleanupRunLogPath:                 cfg.CleanupRunLogPath,
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
		DashboardEnabled:                  cfg.DashboardEnabled,
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
		System1StepRouting:                cfg.System1StepRouting,
		System1Scope:                      cfg.System1Scope,
		System1Endpoint:                   cfg.System1Endpoint,
		System1Provider:                   cfg.System1Provider,
		System1TimeoutMs:                  cfg.System1TimeoutMs,
		System1ConfThresholdsJson:         cfg.System1ConfThresholdsJson,
		System1Skills:                     cfg.System1Skills,
		System1MaxOptions:                 cfg.System1MaxOptions,
		MaestroEnabled:                    cfg.MaestroEnabled,
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
		t.GrpcPeerToken = strPtr(cfg.GrpcPeerToken)
		t.HttpReadonlyToken = strPtr(cfg.HttpReadonlyToken)
		t.HttpControlToken = strPtr(cfg.HttpControlToken)
		t.QdrantApiKey = strPtr(cfg.QdrantApiKey)
		t.LangsmithApiKey = strPtr(cfg.LangsmithApiKey)
		t.System1ApiKey = strPtr(cfg.System1ApiKey)
		t.McpServersJson = strPtr(cfg.McpServersJson)
	}
	return t
}

// ToModel은 전송 DTO를 DB 모델로 변환한다.
// 민감 필드가 nil(백업에 없음)이고 기존 레코드가 있으면 기존 값을 보존한다.
func (t ConfigTransfer) ToModel(existing *models.RoboClawConfig) models.RoboClawConfig {
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

	cleanupDemoEnabled := true
	if cur != nil && cur.CloidCleanupDemoEnabled != nil {
		cleanupDemoEnabled = *cur.CloidCleanupDemoEnabled
	}
	if t.CloidCleanupDemoEnabled != nil {
		cleanupDemoEnabled = *t.CloidCleanupDemoEnabled
	}

	cloidExpressionEnabled := false
	if cur != nil && cur.CloidExpressionEnabled != nil {
		cloidExpressionEnabled = *cur.CloidExpressionEnabled
	}
	if t.CloidExpressionEnabled != nil {
		cloidExpressionEnabled = *t.CloidExpressionEnabled
	}

	cloidNavigationPoseEnabled := false
	if cur != nil && cur.CloidNavigationPoseEnabled != nil {
		cloidNavigationPoseEnabled = *cur.CloidNavigationPoseEnabled
	}
	if t.CloidNavigationPoseEnabled != nil {
		cloidNavigationPoseEnabled = *t.CloidNavigationPoseEnabled
	}

	grpcPort := 50052
	if cur != nil {
		grpcPort = cur.GrpcPort
	}
	if t.GrpcPort != nil {
		grpcPort = *t.GrpcPort
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
		LlmToolCalling:                    t.LlmToolCalling,
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
		GrpcPort:                          grpcPort,
		GrpcPeerToken:                     resolve(t.GrpcPeerToken, curStr(func(c *models.RoboClawConfig) string { return c.GrpcPeerToken })),
		GrpcTargetHost:                    t.GrpcTargetHost,
		GrpcTargetPort:                    t.GrpcTargetPort,
		GrpcTargetPeersJson:               t.GrpcTargetPeersJson,
		CloidCleanupDemoEnabled:           boolPtr(cleanupDemoEnabled),
		CloidCleanupDemoMotionIDsJson:     t.CloidCleanupDemoMotionIDsJson,
		CloidExpressionEnabled:            boolPtr(cloidExpressionEnabled),
		CloidNavigationPoseEnabled:        boolPtr(cloidNavigationPoseEnabled),
		CleanupRunLogPath:                 t.CleanupRunLogPath,
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
		DashboardEnabled:                  t.DashboardEnabled,
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
		System1StepRouting:                t.System1StepRouting,
		System1Scope:                      t.System1Scope,
		System1Endpoint:                   t.System1Endpoint,
		System1Provider:                   t.System1Provider,
		System1TimeoutMs:                  t.System1TimeoutMs,
		System1ConfThresholdsJson:         t.System1ConfThresholdsJson,
		System1Skills:                     t.System1Skills,
		System1MaxOptions:                 t.System1MaxOptions,
		System1ApiKey:                     resolve(t.System1ApiKey, curStr(func(c *models.RoboClawConfig) string { return c.System1ApiKey })),
		MaestroEnabled:                    t.MaestroEnabled,
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
