package handler

import (
	"fmt"
	"testing"

	"ai-config-server/database"
	"ai-config-server/database/models"
	"ai-config-server/testutil"

	"github.com/gin-gonic/gin"
)

// TestUpdateConfigPreservesAllMaskedFields 는 수정 시 모든 마스킹된 민감 필드 보존을 검증한다.
func TestUpdateConfigPreservesAllMaskedFields(t *testing.T) {
	setupRouterTestDB(t)
	cfg := models.RoboClawConfig{
		Name:               "c",
		RobotName:          "butler",
		Environment:        "office",
		AzureOpenaiApiKey:  "azure-secret",
		OpenaiApiKey:       "openai-secret",
		AnthropicApiKey:    "anthropic-secret",
		LlmEmbeddingApiKey: "embed-secret",
		DiscordBotToken:    "discord-secret",
		SlackAppToken:      "slack-app-secret",
		SlackBotToken:      "slack-bot-secret",
		TelegramBotToken:   "telegram-secret",
		GrpcPeerToken:      "grpc-peer-secret",
		HttpReadonlyToken:  "readonly-secret",
		HttpControlToken:   "control-secret",
		QdrantApiKey:       "qdrant-secret",
		LangsmithApiKey:    "langsmith-secret",
		System1ApiKey:      "system1-secret",
		McpServersJson:     `[{"name":"fs","command":"npx"}]`,
	}
	database.DB.Create(&cfg)

	r := gin.New()
	r.PUT("/c/:id", UpdateConfig)

	body := map[string]any{
		"name": "c", "robot_name": "butler", "environment": "office",
		"azure_openai_api_key":  MaskValue,
		"openai_api_key":        MaskValue,
		"anthropic_api_key":     MaskValue,
		"llm_embedding_api_key": MaskValue,
		"discord_bot_token":     MaskValue,
		"slack_app_token":       MaskValue,
		"slack_bot_token":       MaskValue,
		"telegram_bot_token":    MaskValue,
		"grpc_peer_token":       MaskValue,
		"http_readonly_token":   MaskValue,
		"http_control_token":    MaskValue,
		"qdrant_api_key":        MaskValue,
		"langsmith_api_key":     MaskValue,
		"system1_api_key":       MaskValue,
		"mcp_servers_json":      MaskValue,
	}
	w := testutil.PerformJSON(r, "PUT", fmt.Sprintf("/c/%d", cfg.ID), "", body)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var stored models.RoboClawConfig
	database.DB.First(&stored, cfg.ID)

	checks := []struct {
		name string
		got  string
		want string
	}{
		{"azure", stored.AzureOpenaiApiKey, "azure-secret"},
		{"openai", stored.OpenaiApiKey, "openai-secret"},
		{"anthropic", stored.AnthropicApiKey, "anthropic-secret"},
		{"embed", stored.LlmEmbeddingApiKey, "embed-secret"},
		{"discord", stored.DiscordBotToken, "discord-secret"},
		{"slack-app", stored.SlackAppToken, "slack-app-secret"},
		{"slack-bot", stored.SlackBotToken, "slack-bot-secret"},
		{"telegram", stored.TelegramBotToken, "telegram-secret"},
		{"grpc-peer", stored.GrpcPeerToken, "grpc-peer-secret"},
		{"readonly", stored.HttpReadonlyToken, "readonly-secret"},
		{"control", stored.HttpControlToken, "control-secret"},
		{"qdrant", stored.QdrantApiKey, "qdrant-secret"},
		{"langsmith", stored.LangsmithApiKey, "langsmith-secret"},
		{"system1", stored.System1ApiKey, "system1-secret"},
		{"mcp", stored.McpServersJson, `[{"name":"fs","command":"npx"}]`},
	}
	for _, c := range checks {
		if c.got != c.want {
			t.Errorf("expected %s preserved as %q, got %q", c.name, c.want, c.got)
		}
	}
}

// TestUpdateConfigOverwritesSecretsWhenProvided 는 새 값 제공 시 덮어쓰기를 검증한다.
func TestUpdateConfigOverwritesSecretsWhenProvided(t *testing.T) {
	setupRouterTestDB(t)
	cfg := models.RoboClawConfig{
		Name: "c", RobotName: "butler", Environment: "office",
		AzureOpenaiApiKey: "old-key",
	}
	database.DB.Create(&cfg)

	r := gin.New()
	r.PUT("/c/:id", UpdateConfig)

	body := map[string]any{
		"name": "c", "robot_name": "butler", "environment": "office",
		"azure_openai_api_key": "new-key",
	}
	w := testutil.PerformJSON(r, "PUT", fmt.Sprintf("/c/%d", cfg.ID), "", body)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var stored models.RoboClawConfig
	database.DB.First(&stored, cfg.ID)
	if stored.AzureOpenaiApiKey != "new-key" {
		t.Errorf("expected new key, got %q", stored.AzureOpenaiApiKey)
	}
}
