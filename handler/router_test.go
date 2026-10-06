package handler

import (
	"encoding/json"
	"strings"
	"sync"
	"testing"

	"ai-config-server/config"
	"ai-config-server/database"
	"ai-config-server/database/models"
	"ai-config-server/testutil"

	"github.com/gin-gonic/gin"
)

func init() {
	gin.SetMode(gin.TestMode)
}

// setupRouterTestDB 는 통합 테스트용 DB 를 전역에 연결한다.
// 아직 핸들러가 database.DB 전역을 참조하므로 직렬 실행 전제로 동작한다.
// 전역 Rate Limiter 버킷도 초기화해 테스트 순서 의존성을 제거한다.
func setupRouterTestDB(t *testing.T) {
	t.Helper()
	ipBuckets = sync.Map{}
	database.DB = testutil.NewTestDB(t)
}

func TestRouterRejectsMissingAuthenticationInProductionMode(t *testing.T) {
	setupRouterTestDB(t)
	cfg := &config.Config{}
	cfg.Security.RequireAuth = true
	r := NewRouter(cfg)

	w := testutil.PerformJSON(r, "GET", "/api/v1/admin/transfer/export", "", nil)
	if w.Code != 401 {
		t.Fatalf("expected 401 when authentication is not configured, got %d", w.Code)
	}
}

func TestRouterLimitsRequestBody(t *testing.T) {
	setupRouterTestDB(t)
	r := NewRouter(testutil.NewTestConfig())
	body := map[string]any{"name": strings.Repeat("x", 11<<20)}

	w := testutil.PerformJSON(r, "POST", "/api/v1/admin/configs", "", body)
	if w.Code != 400 {
		t.Fatalf("expected oversized request to be rejected with 400, got %d", w.Code)
	}
}

func TestRouterPing(t *testing.T) {
	setupRouterTestDB(t)
	r := NewRouter(testutil.NewTestConfig())

	w := testutil.PerformJSON(r, "GET", "/ping", "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	var resp map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp["message"] != "pong" {
		t.Errorf("expected pong, got %q", resp["message"])
	}
}

func TestRouterUnknownRouteReturnsJSON404(t *testing.T) {
	setupRouterTestDB(t)
	r := NewRouter(testutil.NewTestConfig())

	w := testutil.PerformJSON(r, "GET", "/no/such/route", "", nil)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
	var resp map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("expected JSON error body, got %s", w.Body.String())
	}
	if resp["error"] == nil {
		t.Errorf("expected error field, got %v", resp)
	}
}

func TestRouterAdminExportRequiresAdminToken(t *testing.T) {
	setupRouterTestDB(t)
	cfg := testutil.NewTestConfig(func(c *config.Config) {
		c.Security.AdminToken = "admin-secret"
	})
	r := NewRouter(cfg)

	// 토큰 없음 → 401
	w := testutil.PerformJSON(r, "GET", "/api/v1/admin/transfer/export", "", nil)
	if w.Code != 401 {
		t.Fatalf("expected 401 without token, got %d", w.Code)
	}

	// 잘못된 토큰 → 401
	w = testutil.PerformJSON(r, "GET", "/api/v1/admin/transfer/export", "wrong", nil)
	if w.Code != 401 {
		t.Fatalf("expected 401 with wrong token, got %d", w.Code)
	}

	// 올바른 토큰 → 200
	w = testutil.PerformJSON(r, "GET", "/api/v1/admin/transfer/export", "admin-secret", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200 with valid token, got %d: %s", w.Code, w.Body.String())
	}
	var doc BackupDocument
	if err := json.Unmarshal(w.Body.Bytes(), &doc); err != nil {
		t.Fatalf("expected valid backup JSON, got %s", w.Body.String())
	}
	if doc.Kind != BackupKind {
		t.Errorf("expected kind %q, got %q", BackupKind, doc.Kind)
	}
}

func TestRouterAdminConfigCreateRequiresAdminToken(t *testing.T) {
	setupRouterTestDB(t)
	cfg := testutil.NewTestConfig(func(c *config.Config) {
		c.Security.AdminToken = "admin-secret"
	})
	r := NewRouter(cfg)

	body := map[string]any{
		"name": "router-cfg", "robot_name": "butler", "environment": "office",
	}
	// 토큰 없음 → 401
	w := testutil.PerformJSON(r, "POST", "/api/v1/admin/configs", "", body)
	if w.Code != 401 {
		t.Fatalf("expected 401 without token, got %d", w.Code)
	}
	// 올바른 토큰 → 201
	w = testutil.PerformJSON(r, "POST", "/api/v1/admin/configs", "admin-secret", body)
	if w.Code != 201 {
		t.Fatalf("expected 201 with token, got %d: %s", w.Code, w.Body.String())
	}
}

func TestRouterDeviceRouteAllowsAdminToken(t *testing.T) {
	setupRouterTestDB(t)
	cfg := testutil.NewTestConfig(func(c *config.Config) {
		c.Security.AdminToken = "admin-secret"
		c.Security.DeviceToken = "device-secret"
	})
	r := NewRouter(cfg)

	database.DB.Create(&models.RoboClawConfig{
		Name: "active", RobotName: "butler", Environment: "office", IsActive: true,
	})

	// 디바이스 토큰으로 활성 설정 조회 → 200
	w := testutil.PerformJSON(r, "GET", "/api/v1/configs/active?robot_name=butler&environment=office", "device-secret", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200 with device token, got %d: %s", w.Code, w.Body.String())
	}
	// 토큰 없음 → 401
	w = testutil.PerformJSON(r, "GET", "/api/v1/configs/active?robot_name=butler&environment=office", "", nil)
	if w.Code != 401 {
		t.Fatalf("expected 401 without token, got %d", w.Code)
	}
}
