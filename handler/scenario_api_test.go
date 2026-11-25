package handler

import (
	"encoding/json"
	"fmt"
	"testing"

	"ai-config-server/database/models"
	"ai-config-server/testutil"

	"github.com/gin-gonic/gin"
)

func scenarioAPIRouter(h *Handler) *gin.Engine {
	r := gin.New()
	r.GET("/s/:id", h.GetTestScenario)
	r.PUT("/s/:id", h.UpdateTestScenario)
	return r
}

// TestGetTestScenarioNotFound 는 없는 시나리오 조회 시 404 를 검증한다.
func TestGetTestScenarioNotFound(t *testing.T) {
	h, _ := setupRouterTestDB(t)
	r := scenarioAPIRouter(h)
	w := testutil.PerformJSON(r, "GET", "/s/9999", "", nil)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

// TestUpdateTestScenario 는 시나리오 수정을 검증한다.
func TestUpdateTestScenario(t *testing.T) {
	h, db := setupRouterTestDB(t)
	sc := models.TestScenario{
		Name:        "sc",
		RobotName:   "butler",
		Environment: "office",
		TestCases: []models.TestCase{
			{ID: "tc1", Name: "Ping", Type: "ping", Enabled: true},
		},
	}
	db.Create(&sc)

	r := scenarioAPIRouter(h)
	body := map[string]any{
		"name":        "renamed",
		"robot_name":  "butler",
		"environment": "office",
		"test_cases": []map[string]any{
			{"id": "tc1", "name": "Ping", "type": "ping", "enabled": true},
		},
	}
	w := testutil.PerformJSON(r, "PUT", fmt.Sprintf("/s/%d", sc.ID), "", body)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var stored models.TestScenario
	db.First(&stored, sc.ID)
	if stored.Name != "renamed" {
		t.Errorf("expected name updated to 'renamed', got %q", stored.Name)
	}
}

// TestUpdateTestScenarioNotFound 는 없는 시나리오 수정 시 404 를 검증한다.
func TestUpdateTestScenarioNotFound(t *testing.T) {
	h, _ := setupRouterTestDB(t)
	r := scenarioAPIRouter(h)
	body := map[string]any{
		"name": "x", "robot_name": "butler", "environment": "office", "test_cases": []any{},
	}
	w := testutil.PerformJSON(r, "PUT", "/s/9999", "", body)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

// TestDeleteTestScenario 는 시나리오 삭제를 검증한다.
func TestDeleteTestScenario(t *testing.T) {
	h, db := setupRouterTestDB(t)
	sc := models.TestScenario{Name: "s", RobotName: "butler", Environment: "office"}
	db.Create(&sc)

	r := gin.New()
	r.DELETE("/s/:id", h.DeleteTestScenario)
	w := testutil.PerformJSON(r, "DELETE", fmt.Sprintf("/s/%d", sc.ID), "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var count int64
	db.Model(&models.TestScenario{}).Where("id = ?", sc.ID).Count(&count)
	if count != 0 {
		t.Errorf("expected scenario deleted, count=%d", count)
	}
}

// TestActivateTestScenarioNotFound 는 없는 시나리오 활성화 시 404 를 검증한다.
func TestActivateTestScenarioNotFound(t *testing.T) {
	h, _ := setupRouterTestDB(t)
	r := gin.New()
	r.POST("/s/:id/activate", h.ActivateTestScenario)
	w := testutil.PerformJSON(r, "POST", "/s/9999/activate", "", nil)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

// TestListTestScenariosFilter 는 robot_name 필터를 검증한다.
func TestListTestScenariosFilter(t *testing.T) {
	h, db := setupRouterTestDB(t)
	db.Create(&models.TestScenario{Name: "s1", RobotName: "butler", Environment: "office"})
	db.Create(&models.TestScenario{Name: "s2", RobotName: "former", Environment: "factory"})

	r := gin.New()
	r.GET("/s", h.ListTestScenarios)
	w := testutil.PerformJSON(r, "GET", "/s?robot_name=butler", "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	var list []models.TestScenario
	if err := json.Unmarshal(w.Body.Bytes(), &list); err != nil {
		t.Fatalf("failed to unmarshal: %v", err)
	}
	if len(list) != 1 {
		t.Fatalf("expected 1 scenario, got %d", len(list))
	}
}

// TestPatchTestScenarioPartialUpdate 는 PATCH 로 일부 필드만 수정할 때 기존 필드와 is_active 가 보존되는지 검증한다.
func TestPatchTestScenarioPartialUpdate(t *testing.T) {
	h, db := setupRouterTestDB(t)
	sc := models.TestScenario{
		Name:        "sc-orig",
		Description: "desc-orig",
		RobotName:   "butler",
		Environment: "office",
		IsActive:    true,
		TestCases: models.TestCaseList{
			{ID: "tc1", Name: "Ping", Type: "ping", TimeoutMs: 1000, Enabled: true},
		},
	}
	db.Create(&sc)

	r := gin.New()
	r.PATCH("/s/:id", h.PatchTestScenario)

	w := testutil.PerformJSON(r, "PATCH", fmt.Sprintf("/s/%d", sc.ID), "", map[string]any{
		"description": "desc-patched",
		"is_active":   false,
	})
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var stored models.TestScenario
	db.First(&stored, sc.ID)
	if stored.Description != "desc-patched" {
		t.Errorf("expected description patched, got %q", stored.Description)
	}
	if stored.Name != "sc-orig" || stored.RobotName != "butler" || len(stored.TestCases) != 1 {
		t.Errorf("expected unmentioned fields preserved, got %+v", stored)
	}
	if !stored.IsActive {
		t.Errorf("expected is_active preserved")
	}
}

// TestPatchTestScenarioErrors 는 PATCH 의 잘못된 ID, 없는 리소스, 타입 오류 응답을 검증한다.
func TestPatchTestScenarioErrors(t *testing.T) {
	h, db := setupRouterTestDB(t)
	sc := models.TestScenario{Name: "sc", RobotName: "butler", Environment: "office"}
	db.Create(&sc)

	r := gin.New()
	r.PATCH("/s/:id", h.PatchTestScenario)

	if w := testutil.PerformJSON(r, "PATCH", "/s/abc", "", map[string]any{"name": "x"}); w.Code != 400 {
		t.Fatalf("expected 400 for invalid id, got %d", w.Code)
	}
	if w := testutil.PerformJSON(r, "PATCH", "/s/9999", "", map[string]any{"name": "x"}); w.Code != 404 {
		t.Fatalf("expected 404 for missing scenario, got %d", w.Code)
	}
	if w := testutil.PerformJSON(r, "PATCH", fmt.Sprintf("/s/%d", sc.ID), "", map[string]any{"test_cases": "invalid"}); w.Code != 400 {
		t.Fatalf("expected 400 for invalid field type, got %d: %s", w.Code, w.Body.String())
	}
}
