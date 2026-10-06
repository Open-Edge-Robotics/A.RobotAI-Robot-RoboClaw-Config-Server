package handler

import (
	"testing"

	"ai-config-server/database"
	"ai-config-server/database/models"
)

// TestConfigTransferKeyHelpers 는 키 생성 헬퍼를 검증한다.
func TestConfigTransferKeyHelpers(t *testing.T) {
	cfg := &models.RoboClawConfig{Name: "n", RobotName: "b", Environment: "e"}
	if got := configKey(cfg); got != "n|b|e" {
		t.Errorf("configKey expected 'n|b|e', got %q", got)
	}
	if got := transferConfigKey("n", "b", "e"); got != "n|b|e" {
		t.Errorf("transferConfigKey expected 'n|b|e', got %q", got)
	}

	sc := &models.TestScenario{Name: "n", RobotName: "b", Environment: "e"}
	if got := scenarioKey(sc); got != "n|b|e" {
		t.Errorf("scenarioKey expected 'n|b|e', got %q", got)
	}
	if got := transferScenarioKey("n", "b", "e"); got != "n|b|e" {
		t.Errorf("transferScenarioKey expected 'n|b|e', got %q", got)
	}
}

// TestLoadConfigKeyMap 은 설정 키맵 로딩을 검증한다.
func TestLoadConfigKeyMap(t *testing.T) {
	setupRouterTestDB(t)
	database.DB.Create(&models.RoboClawConfig{Name: "a", RobotName: "butler", Environment: "office"})
	database.DB.Create(&models.RoboClawConfig{Name: "b", RobotName: "former", Environment: "factory"})

	m, err := loadConfigKeyMap(database.DB)
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
	setupRouterTestDB(t)
	database.DB.Create(&models.TestScenario{Name: "s1", RobotName: "butler", Environment: "office"})

	m, err := loadScenarioKeyMap(database.DB)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(m) != 1 {
		t.Fatalf("expected 1 scenario, got %d", len(m))
	}
}

// TestNameExists 는 이름 존재 여부를 검증한다.
func TestNameExists(t *testing.T) {
	setupRouterTestDB(t)
	database.DB.Create(&models.RoboClawConfig{Name: "exists", RobotName: "b", Environment: "e"})

	if !nameExists(database.DB, &models.RoboClawConfig{}, "exists") {
		t.Error("expected name to exist")
	}
	if nameExists(database.DB, &models.RoboClawConfig{}, "missing") {
		t.Error("expected name to not exist")
	}
}

// TestUniqueImportName 은 중복을 회피하는 이름 생성을 검증한다.
func TestUniqueImportName(t *testing.T) {
	setupRouterTestDB(t)

	if got := uniqueImportName(database.DB, &models.RoboClawConfig{}, "base"); got != "base_import" {
		t.Errorf("expected 'base_import', got %q", got)
	}

	database.DB.Create(&models.RoboClawConfig{Name: "base_import", RobotName: "b", Environment: "e"})
	if got := uniqueImportName(database.DB, &models.RoboClawConfig{}, "base"); got != "base_import_2" {
		t.Errorf("expected 'base_import_2', got %q", got)
	}
}

// TestApplyScenarioImportCopy 는 copy 정책으로 시나리오 복사본 생성을 검증한다.
func TestApplyScenarioImportCopy(t *testing.T) {
	setupRouterTestDB(t)
	database.DB.Create(&models.TestScenario{Name: "s", RobotName: "butler", Environment: "office"})

	doc := BackupDocument{
		Scenarios: []ScenarioTransfer{
			{Name: "s", RobotName: "butler", Environment: "office", TestCases: []TestCaseTransfer{}},
		},
	}
	existing, _ := loadScenarioKeyMap(database.DB)
	res, err := applyScenarioImport(database.DB, doc, ConflictCopy, ActivationInactive, existing)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Created != 1 {
		t.Errorf("expected 1 created copy, got %+v", res)
	}
}

// TestApplyConfigImportKeepExistingActive 는 keep_existing 활성 정책을 검증한다.
func TestApplyConfigImportKeepExistingActive(t *testing.T) {
	setupRouterTestDB(t)
	existing := &models.RoboClawConfig{Name: "c", RobotName: "butler", Environment: "office", IsActive: true}
	database.DB.Create(existing)

	doc := BackupDocument{
		Configs: []ConfigTransfer{
			{Name: "c", RobotName: "butler", Environment: "office", IsActive: false, LimitsContent: "{}"},
		},
	}
	cur, _ := loadConfigKeyMap(database.DB)
	res, err := applyConfigImport(database.DB, doc, ConflictOverwrite, ActivationKeepExisting, cur)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Updated != 1 {
		t.Fatalf("expected 1 updated, got %+v", res)
	}

	var stored models.RoboClawConfig
	database.DB.First(&stored, existing.ID)
	if !stored.IsActive {
		t.Error("expected keep_existing to preserve active state")
	}
}
