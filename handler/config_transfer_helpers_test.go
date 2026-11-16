package handler

import (
	"testing"

	"ai-config-server/database/models"
)

// TestLoadConfigKeyMap 은 설정 키맵 로딩을 검증한다.
// 키 구성/적용 규칙의 단위 테스트는 service/transfer 에 있다.
func TestLoadConfigKeyMap(t *testing.T) {
	_, db := setupRouterTestDB(t)
	db.Create(&models.RoboClawConfig{Name: "a", RobotName: "butler", Environment: "office"})
	db.Create(&models.RoboClawConfig{Name: "b", RobotName: "former", Environment: "factory"})

	m, err := loadConfigKeyMap(db)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(m) != 2 {
		t.Fatalf("expected 2 configs, got %d", len(m))
	}
	if _, ok := m["a|butler|office"]; !ok {
		t.Error("expected key a|butler|office")
	}
}

// TestLoadScenarioKeyMap 은 시나리오 키맵 로딩을 검증한다.
func TestLoadScenarioKeyMap(t *testing.T) {
	_, db := setupRouterTestDB(t)
	db.Create(&models.TestScenario{Name: "s1", RobotName: "butler", Environment: "office"})

	m, err := loadScenarioKeyMap(db)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(m) != 1 {
		t.Fatalf("expected 1 scenario, got %d", len(m))
	}
}
