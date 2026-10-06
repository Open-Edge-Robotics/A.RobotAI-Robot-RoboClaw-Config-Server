package handler

import (
	"encoding/json"
	"testing"

	"ai-config-server/database"
	"ai-config-server/database/models"
	"ai-config-server/testutil"
	"github.com/gin-gonic/gin"
)

func TestGetActiveRuntimeConfigV2ReturnsVersionedEnvelope(t *testing.T) {
	setupRouterTestDB(t)
	database.DB.Create(&models.RoboClawConfig{
		Name: "active", RobotName: "butler", Environment: "office", IsActive: true,
		LlmProvider: "ollama", LlmModel: "llama3.2", OpenaiApiKey: "secret",
	})

	r := gin.New()
	r.GET("/api/v2/device/runtime-config", GetActiveRuntimeConfigV2)
	w := testutil.PerformJSON(r, "GET", "/api/v2/device/runtime-config?robot_name=butler&environment=office", "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	var response map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	if response["schema_version"] != "2.0" || response["robot_name"] != "butler" {
		t.Fatalf("unexpected runtime envelope: %#v", response)
	}
	config := response["config"].(map[string]any)
	if config["openai_api_key"] != "********" {
		t.Fatalf("runtime manifest leaked secret: %#v", config["openai_api_key"])
	}
}
