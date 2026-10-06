package handler

import (
	"testing"

	"ai-config-server/database/models"
)

// TestMaskSensitiveFieldsAll 은 모든 민감 필드 마스킹을 검증한다.
func TestMaskSensitiveFieldsAll(t *testing.T) {
	cfg := models.RoboClawConfig{
		AzureOpenaiApiKey:  "azure",
		OpenaiApiKey:       "openai",
		AnthropicApiKey:    "anthropic",
		LlmEmbeddingApiKey: "embed",
		DiscordBotToken:    "discord",
		SlackAppToken:      "slack-app",
		SlackBotToken:      "slack-bot",
		TelegramBotToken:   "telegram",
		HttpReadonlyToken:  "readonly",
		HttpControlToken:   "control",
		QdrantApiKey:       "qdrant",
		LangsmithApiKey:    "langsmith",
		System1ApiKey:      "system1",
		McpServersJson:     `[{"name":"fs"}]`,
	}

	maskSensitiveFields(&cfg)

	fields := []struct {
		name string
		got  string
	}{
		{"azure", cfg.AzureOpenaiApiKey},
		{"openai", cfg.OpenaiApiKey},
		{"anthropic", cfg.AnthropicApiKey},
		{"embed", cfg.LlmEmbeddingApiKey},
		{"discord", cfg.DiscordBotToken},
		{"slack-app", cfg.SlackAppToken},
		{"slack-bot", cfg.SlackBotToken},
		{"telegram", cfg.TelegramBotToken},
		{"readonly", cfg.HttpReadonlyToken},
		{"control", cfg.HttpControlToken},
		{"qdrant", cfg.QdrantApiKey},
		{"langsmith", cfg.LangsmithApiKey},
		{"system1", cfg.System1ApiKey},
	}
	for _, f := range fields {
		if f.got != MaskValue {
			t.Errorf("expected %s to be masked, got %q", f.name, f.got)
		}
	}

	// MCP 서버는 자격 증명만 가리고 목록 구조는 유지하므로 여기서는 별도로 검증한다.
	// (mcp_masking_test.go 참고)
	if cfg.McpServersJson != `[{"name":"fs"}]` {
		t.Errorf("expected MCP server structure to stay visible, got %q", cfg.McpServersJson)
	}
}

// TestMaskSensitiveFieldsEmpty 유지 - 비어있지 않은 값만 마스킹하는지 검증한다.
func TestMaskSensitiveFieldsEmpty(t *testing.T) {
	cfg := models.RoboClawConfig{
		AzureOpenaiApiKey: "",
		McpServersJson:    "[]",
	}
	maskSensitiveFields(&cfg)
	if cfg.AzureOpenaiApiKey != "" {
		t.Errorf("expected empty azure key to stay empty, got %q", cfg.AzureOpenaiApiKey)
	}
	if cfg.McpServersJson != "[]" {
		t.Errorf("expected empty mcp_servers_json to stay '[]', got %q", cfg.McpServersJson)
	}
}
