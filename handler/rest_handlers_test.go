package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"

	"ai-config-server/database"
	"ai-config-server/database/models"
	"ai-config-server/testutil"

	"github.com/gin-gonic/gin"
)

// ===== Rate Limit =====

func TestLimitRateRejectsOverBurst(t *testing.T) {
	// 전역 버킷 정리 (같은 테스트 IP 영향 방지)
	ipBuckets = sync.Map{}

	router := gin.New()
	router.Use(LimitRate(0, 1)) // refill 0, burst 1 → 두 번째 요청부터 거절
	router.GET("/x", func(c *gin.Context) { c.Status(http.StatusOK) })

	if w := testutil.PerformJSON(router, "GET", "/x", "", nil); w.Code != 200 {
		t.Fatalf("expected 200 on first request, got %d", w.Code)
	}
	if w := testutil.PerformJSON(router, "GET", "/x", "", nil); w.Code != 429 {
		t.Fatalf("expected 429 on second request, got %d", w.Code)
	}
}

func TestLimitRateAllowsUnderBurst(t *testing.T) {
	ipBuckets = sync.Map{}

	router := gin.New()
	router.Use(LimitRate(0, 5))
	router.GET("/x", func(c *gin.Context) { c.Status(http.StatusOK) })

	for i := 0; i < 5; i++ {
		if w := testutil.PerformJSON(router, "GET", "/x", "", nil); w.Code != 200 {
			t.Fatalf("request %d expected 200, got %d", i+1, w.Code)
		}
	}
}

// ===== CORS =====

func TestCORSPreflightReturns204(t *testing.T) {
	cfg := testutil.NewTestConfig()
	router := gin.New()
	router.Use(CORS(cfg))
	router.GET("/x", func(c *gin.Context) { c.Status(http.StatusOK) })

	req := httptest.NewRequest("OPTIONS", "/x", nil)
	req.Header.Set("Origin", "http://localhost:3000")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	if w.Code != http.StatusNoContent {
		t.Fatalf("expected 204 for preflight, got %d", w.Code)
	}
}

func TestCORSAllowsConfiguredOrigin(t *testing.T) {
	cfg := testutil.NewTestConfig()
	cfg.Security.CorsAllowedOrigins = []string{"http://allowed.example"}
	router := gin.New()
	router.Use(CORS(cfg))
	router.GET("/x", func(c *gin.Context) { c.Status(http.StatusOK) })

	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set("Origin", "http://allowed.example")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	if w.Header().Get("Access-Control-Allow-Origin") != "http://allowed.example" {
		t.Errorf("expected allow-origin header for allowed origin")
	}
	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestCORSRejectsDisallowedOrigin(t *testing.T) {
	cfg := testutil.NewTestConfig()
	cfg.Security.CorsAllowedOrigins = []string{"http://allowed.example"}
	router := gin.New()
	router.Use(CORS(cfg))
	router.GET("/x", func(c *gin.Context) { c.Status(http.StatusOK) })

	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set("Origin", "http://evil.example")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	if w.Header().Get("Access-Control-Allow-Origin") != "" {
		t.Errorf("expected no allow-origin header for disallowed origin")
	}
}

// ===== Config 핸들러 (Get/Delete/Activate/Clone) =====

func TestGetConfigReturnsMaskedSecrets(t *testing.T) {
	setupHandlerTestDB(t)
	cfg := models.RoboClawConfig{
		Name: "masked", RobotName: "butler", Environment: "office",
		AzureOpenaiApiKey: "top-secret",
	}
	database.DB.Create(&cfg)

	r := gin.New()
	r.GET("/c/:id", GetConfig)
	w := testutil.PerformJSON(r, "GET", fmt.Sprintf("/c/%d", cfg.ID), "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	var resp models.RoboClawConfig
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp.AzureOpenaiApiKey != MaskValue {
		t.Errorf("expected masked api key, got %q", resp.AzureOpenaiApiKey)
	}
}

func TestGetConfigNotFound(t *testing.T) {
	setupHandlerTestDB(t)
	r := gin.New()
	r.GET("/c/:id", GetConfig)
	w := testutil.PerformJSON(r, "GET", "/c/9999", "", nil)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

func TestDeleteConfigRemovesRecord(t *testing.T) {
	setupHandlerTestDB(t)
	cfg := models.RoboClawConfig{Name: "del", RobotName: "butler", Environment: "office"}
	database.DB.Create(&cfg)

	r := gin.New()
	r.DELETE("/c/:id", DeleteConfig)
	w := testutil.PerformJSON(r, "DELETE", fmt.Sprintf("/c/%d", cfg.ID), "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	var count int64
	database.DB.Model(&models.RoboClawConfig{}).Where("id = ?", cfg.ID).Count(&count)
	if count != 0 {
		t.Errorf("expected record deleted, count=%d", count)
	}
}

func TestActivateConfigDeactivatesOthersInSameRobotEnv(t *testing.T) {
	setupHandlerTestDB(t)
	a := models.RoboClawConfig{Name: "a", RobotName: "butler", Environment: "office", IsActive: true}
	b := models.RoboClawConfig{Name: "b", RobotName: "butler", Environment: "office"}
	database.DB.Create(&a)
	database.DB.Create(&b)

	r := gin.New()
	r.POST("/c/:id/activate", ActivateConfig)
	w := testutil.PerformJSON(r, "POST", fmt.Sprintf("/c/%d/activate", b.ID), "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var activeCount int64
	database.DB.Model(&models.RoboClawConfig{}).
		Where("robot_name = ? AND environment = ? AND is_active = ?", "butler", "office", true).
		Count(&activeCount)
	if activeCount != 1 {
		t.Fatalf("expected exactly 1 active, got %d", activeCount)
	}
	var bReload models.RoboClawConfig
	database.DB.First(&bReload, b.ID)
	if !bReload.IsActive {
		t.Error("expected target to be active")
	}
}

func TestCloneConfigCopiesSecrets(t *testing.T) {
	setupHandlerTestDB(t)
	cfg := models.RoboClawConfig{
		Name: "orig", RobotName: "butler", Environment: "office",
		AzureOpenaiApiKey: "secret", Description: "desc",
	}
	database.DB.Create(&cfg)

	r := gin.New()
	r.POST("/c/:id/clone", CloneConfig)
	w := testutil.PerformJSON(r, "POST", fmt.Sprintf("/c/%d/clone", cfg.ID), "", nil)
	if w.Code != 201 {
		t.Fatalf("expected 201, got %d: %s", w.Code, w.Body.String())
	}
	var resp models.RoboClawConfig
	json.Unmarshal(w.Body.Bytes(), &resp)
	if resp.Name == cfg.Name {
		t.Errorf("expected cloned config to have different name, got %q", resp.Name)
	}
	if resp.AzureOpenaiApiKey != MaskValue {
		t.Errorf("expected clone response api key masked, got %q", resp.AzureOpenaiApiKey)
	}
	var stored models.RoboClawConfig
	database.DB.First(&stored, resp.ID)
	if stored.AzureOpenaiApiKey != "secret" {
		t.Errorf("expected cloned record to preserve secret, got %q", stored.AzureOpenaiApiKey)
	}
}

// ===== Scenario 핸들러 (List/Get/Update/Delete/Clone/Activate/Active) =====

func scenarioRouter() *gin.Engine {
	r := gin.New()
	r.GET("/s", ListTestScenarios)
	r.GET("/s/:id", GetTestScenario)
	r.POST("/s", CreateTestScenario)
	r.PUT("/s/:id", UpdateTestScenario)
	r.DELETE("/s/:id", DeleteTestScenario)
	r.POST("/s/:id/clone", CloneTestScenario)
	r.POST("/s/:id/activate", ActivateTestScenario)
	r.GET("/active", GetActiveTestScenario)
	return r
}

func TestScenarioCRUDLifecycle(t *testing.T) {
	setupHandlerTestDB(t)
	r := scenarioRouter()

	// List (empty)
	w := testutil.PerformJSON(r, "GET", "/s", "", nil)
	if w.Code != 200 {
		t.Fatalf("list expected 200, got %d", w.Code)
	}

	// Create
	createBody := map[string]any{
		"name": "sc-1", "robot_name": "butler", "environment": "office", "is_active": true,
		"test_cases": []map[string]any{
			{"id": "tc1", "name": "Ping", "type": "ping", "timeout_ms": 3000, "enabled": true},
		},
	}
	w = testutil.PerformJSON(r, "POST", "/s", "", createBody)
	if w.Code != 201 {
		t.Fatalf("create expected 201, got %d: %s", w.Code, w.Body.String())
	}
	var created models.TestScenario
	json.Unmarshal(w.Body.Bytes(), &created)

	// Get
	w = testutil.PerformJSON(r, "GET", fmt.Sprintf("/s/%d", created.ID), "", nil)
	if w.Code != 200 || len(created.TestCases) == 0 {
		t.Fatalf("get expected 200, got %d", w.Code)
	}

	// Update
	updateBody := map[string]any{
		"name": "sc-1-renamed", "robot_name": "butler", "environment": "office",
		"test_cases": []map[string]any{},
	}
	w = testutil.PerformJSON(r, "PUT", fmt.Sprintf("/s/%d", created.ID), "", updateBody)
	if w.Code != 200 {
		t.Fatalf("update expected 200, got %d: %s", w.Code, w.Body.String())
	}

	// Clone
	w = testutil.PerformJSON(r, "POST", fmt.Sprintf("/s/%d/clone", created.ID), "", nil)
	if w.Code != 201 {
		t.Fatalf("clone expected 201, got %d: %s", w.Code, w.Body.String())
	}

	// Activate
	w = testutil.PerformJSON(r, "POST", fmt.Sprintf("/s/%d/activate", created.ID), "", nil)
	if w.Code != 200 {
		t.Fatalf("activate expected 200, got %d: %s", w.Code, w.Body.String())
	}

	// GetActive
	w = testutil.PerformJSON(r, "GET", "/active?robot_name=butler&environment=office", "", nil)
	if w.Code != 200 {
		t.Fatalf("get active expected 200, got %d: %s", w.Code, w.Body.String())
	}

	// Delete
	w = testutil.PerformJSON(r, "DELETE", fmt.Sprintf("/s/%d", created.ID), "", nil)
	if w.Code != 200 {
		t.Fatalf("delete expected 200, got %d", w.Code)
	}
	var count int64
	database.DB.Model(&models.TestScenario{}).Where("id = ?", created.ID).Count(&count)
	if count != 0 {
		t.Errorf("expected scenario deleted, count=%d", count)
	}
}
