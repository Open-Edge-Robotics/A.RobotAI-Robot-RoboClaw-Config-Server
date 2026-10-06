package handler

import (
	"testing"

	"ai-config-server/database"
	"ai-config-server/database/models"
	"ai-config-server/testutil"

	"github.com/gin-gonic/gin"
)

// TestActivateConfigNotFound 는 없는 설정 활성화 시 404 를 검증한다.
func TestActivateConfigNotFound(t *testing.T) {
	setupRouterTestDB(t)
	r := gin.New()
	r.POST("/c/:id/activate", ActivateConfig)

	w := testutil.PerformJSON(r, "POST", "/c/9999/activate", "", nil)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

// TestUpdateConfigNotFound 는 없는 설정 수정 시 404 를 검증한다.
func TestUpdateConfigNotFound(t *testing.T) {
	setupRouterTestDB(t)
	r := gin.New()
	r.PUT("/c/:id", UpdateConfig)

	body := map[string]any{"name": "x", "robot_name": "butler", "environment": "office"}
	w := testutil.PerformJSON(r, "PUT", "/c/9999", "", body)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

// TestCloneConfigNotFound 는 없는 설정 복제 시 404 를 검증한다.
func TestCloneConfigNotFound(t *testing.T) {
	setupRouterTestDB(t)
	r := gin.New()
	r.POST("/c/:id/clone", CloneConfig)

	w := testutil.PerformJSON(r, "POST", "/c/9999/clone", "", nil)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

// TestGenerateUniqueCloneName 은 복제 이름 중복 회피를 검증한다.
func TestGenerateUniqueCloneName(t *testing.T) {
	setupRouterTestDB(t)
	database.DB.Create(&models.RoboClawConfig{Name: "orig", RobotName: "butler", Environment: "office"})

	if got := generateUniqueCloneName(&models.RoboClawConfig{}, "orig"); got != "orig_copy" {
		t.Errorf("expected 'orig_copy', got %q", got)
	}

	database.DB.Create(&models.RoboClawConfig{Name: "orig_copy", RobotName: "butler", Environment: "office"})
	if got := generateUniqueCloneName(&models.RoboClawConfig{}, "orig"); got != "orig_copy_2" {
		t.Errorf("expected 'orig_copy_2', got %q", got)
	}
}

// TestUpdateConfigJSONValidationError 는 잘못된 중첩 JSON 수정 시 400 을 검증한다.
func TestUpdateConfigJSONValidationError(t *testing.T) {
	setupRouterTestDB(t)
	cfg := models.RoboClawConfig{Name: "c", RobotName: "butler", Environment: "office"}
	database.DB.Create(&cfg)

	r := gin.New()
	r.PUT("/c/:id", UpdateConfig)

	body := map[string]any{
		"name": "c", "robot_name": "butler", "environment": "office",
		"limits_content": "{bad json",
	}
	w := testutil.PerformJSON(r, "PUT", "/c/1", "", body)
	if w.Code != 400 {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestUpdateConfigPeerJSONValidationError(t *testing.T) {
	setupRouterTestDB(t)
	cfg := models.RoboClawConfig{Name: "c", RobotName: "butler", Environment: "office"}
	database.DB.Create(&cfg)

	r := gin.New()
	r.PUT("/c/:id", UpdateConfig)

	body := map[string]any{
		"name": "c", "robot_name": "butler", "environment": "office",
		"grpc_target_peers_json": "{bad json",
	}
	w := testutil.PerformJSON(r, "PUT", "/c/1", "", body)
	if w.Code != 400 {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestUpdateConfigJSONShapeValidationError(t *testing.T) {
	setupRouterTestDB(t)
	cfg := models.RoboClawConfig{Name: "c", RobotName: "butler", Environment: "office"}
	database.DB.Create(&cfg)

	r := gin.New()
	r.PUT("/c/:id", UpdateConfig)
	body := map[string]any{
		"name": "c", "robot_name": "butler", "environment": "office",
		"http_allowed_cidrs_json": `{"cidr":"127.0.0.1/32"}`,
	}
	w := testutil.PerformJSON(r, "PUT", "/c/1", "", body)
	if w.Code != 400 {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestUpdateConfigRuntimeValueValidationError(t *testing.T) {
	setupRouterTestDB(t)
	cfg := models.RoboClawConfig{Name: "c", RobotName: "butler", Environment: "office"}
	database.DB.Create(&cfg)

	r := gin.New()
	r.PUT("/c/:id", UpdateConfig)
	body := map[string]any{
		"name": "c", "robot_name": "butler", "environment": "office",
		"llm_provider": "unsupported",
	}
	w := testutil.PerformJSON(r, "PUT", "/c/1", "", body)
	if w.Code != 400 {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestUpdateConfigDashboardPortValidationError(t *testing.T) {
	setupRouterTestDB(t)
	cfg := models.RoboClawConfig{Name: "c", RobotName: "butler", Environment: "office"}
	database.DB.Create(&cfg)

	r := gin.New()
	r.PUT("/c/:id", UpdateConfig)
	body := map[string]any{
		"name": "c", "robot_name": "butler", "environment": "office",
		"dashboard_port": 70000,
	}
	w := testutil.PerformJSON(r, "PUT", "/c/1", "", body)
	if w.Code != 400 {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestUpdateConfigPreservesActiveState(t *testing.T) {
	setupRouterTestDB(t)
	cfg := models.RoboClawConfig{
		Name:        "active",
		RobotName:   "butler",
		Environment: "office",
		IsActive:    true,
	}
	database.DB.Create(&cfg)

	r := gin.New()
	r.PUT("/c/:id", UpdateConfig)
	w := testutil.PerformJSON(r, "PUT", "/c/1", "", map[string]any{
		"name": "renamed", "robot_name": "butler", "environment": "office",
	})
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var updated models.RoboClawConfig
	if err := database.DB.First(&updated, cfg.ID).Error; err != nil {
		t.Fatal(err)
	}
	if !updated.IsActive {
		t.Fatal("updating an active profile must not deactivate it")
	}
}
