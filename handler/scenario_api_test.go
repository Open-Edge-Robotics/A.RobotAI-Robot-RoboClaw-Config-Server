package handler

import (
	"encoding/json"
	"fmt"
	"testing"

	"ai-config-server/database"
	"ai-config-server/database/models"
	"ai-config-server/testutil"

	"github.com/gin-gonic/gin"
)

func scenarioAPIRouter() *gin.Engine {
	r := gin.New()
	r.GET("/s/:id", GetTestScenario)
	r.PUT("/s/:id", UpdateTestScenario)
	return r
}

// TestGetTestScenarioNotFound 는 없는 시나리오 조회 시 404 를 검증한다.
func TestGetTestScenarioNotFound(t *testing.T) {
	setupRouterTestDB(t)
	r := scenarioAPIRouter()
	w := testutil.PerformJSON(r, "GET", "/s/9999", "", nil)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

// TestUpdateTestScenario 는 시나리오 수정을 검증한다.
func TestUpdateTestScenario(t *testing.T) {
	setupRouterTestDB(t)
	sc := models.TestScenario{
		Name:        "sc",
		RobotName:   "butler",
		Environment: "office",
		TestCases: []models.TestCase{
			{ID: "tc1", Name: "Ping", Type: "ping", Enabled: true},
		},
	}
	database.DB.Create(&sc)

	r := scenarioAPIRouter()
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
	database.DB.First(&stored, sc.ID)
	if stored.Name != "renamed" {
		t.Errorf("expected name updated to 'renamed', got %q", stored.Name)
	}
}

// TestUpdateTestScenarioNotFound 는 없는 시나리오 수정 시 404 를 검증한다.
func TestUpdateTestScenarioNotFound(t *testing.T) {
	setupRouterTestDB(t)
	r := scenarioAPIRouter()
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
	setupRouterTestDB(t)
	sc := models.TestScenario{Name: "s", RobotName: "butler", Environment: "office"}
	database.DB.Create(&sc)

	r := gin.New()
	r.DELETE("/s/:id", DeleteTestScenario)
	w := testutil.PerformJSON(r, "DELETE", fmt.Sprintf("/s/%d", sc.ID), "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var count int64
	database.DB.Model(&models.TestScenario{}).Where("id = ?", sc.ID).Count(&count)
	if count != 0 {
		t.Errorf("expected scenario deleted, count=%d", count)
	}
}

// TestActivateTestScenarioNotFound 는 없는 시나리오 활성화 시 404 를 검증한다.
func TestActivateTestScenarioNotFound(t *testing.T) {
	setupRouterTestDB(t)
	r := gin.New()
	r.POST("/s/:id/activate", ActivateTestScenario)
	w := testutil.PerformJSON(r, "POST", "/s/9999/activate", "", nil)
	if w.Code != 404 {
		t.Fatalf("expected 404, got %d", w.Code)
	}
}

// TestListTestScenariosFilter 는 robot_name 필터를 검증한다.
func TestListTestScenariosFilter(t *testing.T) {
	setupRouterTestDB(t)
	database.DB.Create(&models.TestScenario{Name: "s1", RobotName: "butler", Environment: "office"})
	database.DB.Create(&models.TestScenario{Name: "s2", RobotName: "former", Environment: "factory"})

	r := gin.New()
	r.GET("/s", ListTestScenarios)
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
