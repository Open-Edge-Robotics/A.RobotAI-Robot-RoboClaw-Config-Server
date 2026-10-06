package handler

import (
	"encoding/json"
	"strings"
	"testing"

	"ai-config-server/database"
	"ai-config-server/database/models"
	"ai-config-server/testutil"
	"github.com/gin-gonic/gin"
)

func TestGetActiveConfigMasksSecretsAndDisablesCaching(t *testing.T) {
	setupRouterTestDB(t)
	database.DB.Create(&models.RoboClawConfig{
		Name:              "active",
		RobotName:         "butler",
		Environment:       "office",
		IsActive:          true,
		AzureOpenaiApiKey: "azure-secret",
		HttpControlToken:  "control-secret",
		McpServersJson:    `[{"name":"mcp","headers":{"Authorization":"secret"}}]`,
	})

	r := gin.New()
	r.GET("/active", GetActiveConfig)
	w := testutil.PerformJSON(r, "GET", "/active?robot_name=butler&environment=office", "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	if w.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("expected no-store cache policy, got %q", w.Header().Get("Cache-Control"))
	}

	var response map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	if response["azure_openai_api_key"] != "********" {
		t.Fatalf("expected masked API key, got %v", response["azure_openai_api_key"])
	}
	if response["http_control_token"] != "********" {
		t.Fatalf("expected masked control token, got %v", response["http_control_token"])
	}
	// MCP 는 목록 구조를 유지한 채 자격 증명(env/headers 값)만 마스킹한다.
	mcpJSON, ok := response["mcp_servers_json"].(string)
	if !ok {
		t.Fatalf("expected mcp_servers_json string, got %T", response["mcp_servers_json"])
	}
	if !strings.Contains(mcpJSON, `"name":"mcp"`) {
		t.Fatalf("expected MCP server to stay visible, got %q", mcpJSON)
	}
	if !strings.Contains(mcpJSON, `"Authorization":"********"`) {
		t.Fatalf("expected MCP header credential masked, got %q", mcpJSON)
	}
	if strings.Contains(mcpJSON, "secret") {
		t.Fatalf("expected MCP credential not to leak, got %q", mcpJSON)
	}
}
