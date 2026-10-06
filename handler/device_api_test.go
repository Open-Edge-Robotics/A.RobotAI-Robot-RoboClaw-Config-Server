package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"testing"

	"ai-config-server/database"
	"ai-config-server/database/models"
	"ai-config-server/testutil"
)

func setupDeviceTest(t *testing.T) {
	t.Helper()
	setupRouterTestDB(t)
	clearActiveCache()
}

// TestGetActiveConfig 는 디바이스용 활성 설정 조회를 검증한다.
func TestGetActiveConfig(t *testing.T) {
	setupDeviceTest(t)
	database.DB.Create(&models.RoboClawConfig{
		Name: "active", RobotName: "butler", Environment: "office", IsActive: true,
		SoulContent: "# soul",
	})

	r := NewRouter(testutil.NewTestConfig())
	w := testutil.PerformJSON(r, "GET", "/api/v1/configs/active?robot_name=butler&environment=office", "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	var resp models.RoboClawConfig
	json.Unmarshal(w.Body.Bytes(), &resp)
	if resp.Name != "active" {
		t.Errorf("expected active config, got %q", resp.Name)
	}
}

// TestGetActiveConfigMissingParams 는 필수 파라미터 누락 시 400 을 검증한다.
func TestGetActiveConfigMissingParams(t *testing.T) {
	setupDeviceTest(t)
	r := NewRouter(testutil.NewTestConfig())

	w := testutil.PerformJSON(r, "GET", "/api/v1/configs/active", "", nil)
	if w.Code != 400 {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

// TestGetActiveConfigFile 는 디바이스용 활성 설정 파일 다운로드를 검증한다.
func TestGetActiveConfigFile(t *testing.T) {
	setupDeviceTest(t)
	database.DB.Create(&models.RoboClawConfig{
		Name: "active", RobotName: "butler", Environment: "office", IsActive: true,
		SoulContent: "# soul content",
	})

	r := NewRouter(testutil.NewTestConfig())
	w := testutil.PerformJSON(r, "GET", "/api/v1/configs/active/files/ROBOT.md?robot_name=butler&environment=office", "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	if w.Body.String() != "# soul content" {
		t.Errorf("expected soul content, got %q", w.Body.String())
	}
}

// TestGetConfigFile 은 관리자용 설정 파일 조회를 검증한다.
func TestGetConfigFile(t *testing.T) {
	setupDeviceTest(t)
	cfg := models.RoboClawConfig{
		Name: "cfg", RobotName: "butler", Environment: "office",
		LimitsContent: `{"max_linear_speed":1.0}`,
	}
	database.DB.Create(&cfg)

	r := NewRouter(testutil.NewTestConfig())
	w := testutil.PerformJSON(r, "GET", fmt.Sprintf("/api/v1/admin/configs/%d/files/ROBOT_LIMITS.json", cfg.ID), "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	if !json.Valid(w.Body.Bytes()) {
		t.Errorf("expected valid JSON, got %s", w.Body.String())
	}
}

// TestGetConfigFileNotFound 는 없는 파일명 조회 시 404 를 검증한다.
func TestGetConfigFileNotFound(t *testing.T) {
	setupDeviceTest(t)
	cfg := models.RoboClawConfig{Name: "cfg", RobotName: "butler", Environment: "office"}
	database.DB.Create(&cfg)

	r := NewRouter(testutil.NewTestConfig())
	w := testutil.PerformJSON(r, "GET", fmt.Sprintf("/api/v1/admin/configs/%d/files/UNKNOWN.txt", cfg.ID), "", nil)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

// TestGetActiveTestScenario 는 디바이스용 활성 시나리오 조회를 검증한다.
func TestGetActiveTestScenario(t *testing.T) {
	setupDeviceTest(t)
	database.DB.Create(&models.TestScenario{
		Name: "active", RobotName: "butler", Environment: "office", IsActive: true,
	})

	r := NewRouter(testutil.NewTestConfig())
	w := testutil.PerformJSON(r, "GET", "/api/v1/scenarios/active?robot_name=butler&environment=office", "", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	var resp models.TestScenario
	json.Unmarshal(w.Body.Bytes(), &resp)
	if resp.Name != "active" {
		t.Errorf("expected active scenario, got %q", resp.Name)
	}
}

// TestGetActiveConfigNotFound 는 활성 설정 없음 시 404 를 검증한다.
func TestGetActiveConfigNotFound(t *testing.T) {
	setupDeviceTest(t)
	r := NewRouter(testutil.NewTestConfig())

	w := testutil.PerformJSON(r, "GET", "/api/v1/configs/active?robot_name=butler&environment=office", "", nil)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

// TestGetActiveConfigFileNoActiveConfig 는 활성 설정 없음 시 파일 조회 404 를 검증한다.
func TestGetActiveConfigFileNoActiveConfig(t *testing.T) {
	setupDeviceTest(t)
	r := NewRouter(testutil.NewTestConfig())

	w := testutil.PerformJSON(r, "GET", "/api/v1/configs/active/files/ROBOT.md?robot_name=butler&environment=office", "", nil)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

// TestGetActiveTestScenarioNotFound 는 활성 시나리오 없음 시 404 를 검증한다.
func TestGetActiveTestScenarioNotFound(t *testing.T) {
	setupDeviceTest(t)
	r := NewRouter(testutil.NewTestConfig())

	w := testutil.PerformJSON(r, "GET", "/api/v1/scenarios/active?robot_name=butler&environment=office", "", nil)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}
