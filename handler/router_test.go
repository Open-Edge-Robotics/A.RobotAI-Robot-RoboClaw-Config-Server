package handler

import (
	"encoding/json"
	"strings"
	"testing"

	"ai-config-server/config"
	"ai-config-server/database/models"
	"ai-config-server/testutil"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func init() {
	gin.SetMode(gin.TestMode)
}

// setupRouterTestDB 는 테스트별 DB 와 Handler 를 만든다. 전역 상태를 교체하지
// 않으므로 테스트가 병렬로 돌더라도 서로의 DB 를 덮어쓰지 않는다.
func setupRouterTestDB(t *testing.T) (*Handler, *gorm.DB) {
	t.Helper()
	db := testutil.NewTestDB(t)
	return NewHandler(db), db
}

func TestRouterRejectsMissingAuthenticationInProductionMode(t *testing.T) {
	_, db := setupRouterTestDB(t)
	cfg := &config.Config{}
	cfg.Security.RequireAuth = true
	r := NewRouter(cfg, db)

	w := testutil.PerformJSON(r, "GET", "/api/v1/admin/transfer/export", "", nil)
	if w.Code != 401 {
		t.Fatalf("expected 401 when authentication is not configured, got %d", w.Code)
	}
}

func TestRouterLimitsRequestBody(t *testing.T) {
	_, db := setupRouterTestDB(t)
	r := NewRouter(testutil.NewTestConfig(), db)
	body := map[string]any{"name": strings.Repeat("x", 11<<20)}

	w := testutil.PerformJSON(r, "POST", "/api/v1/admin/configs", "", body)
	if w.Code != 400 {
		t.Fatalf("expected oversized request to be rejected with 400, got %d", w.Code)
	}
}

func TestRouterPing(t *testing.T) {
	_, db := setupRouterTestDB(t)
	r := NewRouter(testutil.NewTestConfig(), db)

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
	_, db := setupRouterTestDB(t)
	r := NewRouter(testutil.NewTestConfig(), db)

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
	_, db := setupRouterTestDB(t)
	cfg := testutil.NewTestConfig(func(c *config.Config) {
		c.Security.AdminToken = "admin-secret"
	})
	r := NewRouter(cfg, db)

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
	_, db := setupRouterTestDB(t)
	cfg := testutil.NewTestConfig(func(c *config.Config) {
		c.Security.AdminToken = "admin-secret"
	})
	r := NewRouter(cfg, db)

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
	_, db := setupRouterTestDB(t)
	cfg := testutil.NewTestConfig(func(c *config.Config) {
		c.Security.AdminToken = "admin-secret"
		c.Security.DeviceToken = "device-secret"
	})
	r := NewRouter(cfg, db)

	db.Create(&models.RoboClawConfig{
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
