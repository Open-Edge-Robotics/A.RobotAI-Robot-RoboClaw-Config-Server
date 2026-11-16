package transfer_test

import (
	"testing"

	"ai-config-server/database/models"
	"ai-config-server/service/transfer"
	"ai-config-server/testutil"
)

// TestKeys 는 항목 키 구성 규칙(name|robot|env)을 고정한다.
func TestKeys(t *testing.T) {
	cfg := &models.RoboClawConfig{Name: "n", RobotName: "b", Environment: "e"}
	if got := transfer.ConfigKey(cfg); got != "n|b|e" {
		t.Errorf("ConfigKey expected 'n|b|e', got %q", got)
	}
	if got := transfer.TransferConfigKey("n", "b", "e"); got != "n|b|e" {
		t.Errorf("TransferConfigKey expected 'n|b|e', got %q", got)
	}

	sc := &models.TestScenario{Name: "n", RobotName: "b", Environment: "e"}
	if got := transfer.ScenarioKey(sc); got != "n|b|e" {
		t.Errorf("ScenarioKey expected 'n|b|e', got %q", got)
	}
	if got := transfer.TransferScenarioKey("n", "b", "e"); got != "n|b|e" {
		t.Errorf("TransferScenarioKey expected 'n|b|e', got %q", got)
	}
}

// TestNameExists 는 이름 존재 여부 판정을 고정한다.
func TestNameExists(t *testing.T) {
	db := testutil.NewTestDB(t)
	db.Create(&models.RoboClawConfig{Name: "exists", RobotName: "b", Environment: "e"})

	if !transfer.NameExists(db, &models.RoboClawConfig{}, "exists") {
		t.Error("expected name to exist")
	}
	if transfer.NameExists(db, &models.RoboClawConfig{}, "missing") {
		t.Error("expected name to not exist")
	}
}

// TestUniqueImportName 은 중복을 회피하는 이름 생성을 고정한다.
func TestUniqueImportName(t *testing.T) {
	db := testutil.NewTestDB(t)

	if got := transfer.UniqueImportName(db, &models.RoboClawConfig{}, "base"); got != "base_import" {
		t.Errorf("expected 'base_import', got %q", got)
	}

	db.Create(&models.RoboClawConfig{Name: "base_import", RobotName: "b", Environment: "e"})
	if got := transfer.UniqueImportName(db, &models.RoboClawConfig{}, "base"); got != "base_import_2" {
		t.Errorf("expected 'base_import_2', got %q", got)
	}
}

// TestApplyScenarioImportCopy 는 copy 정책으로 시나리오 복사본 생성을 고정한다.
func TestApplyScenarioImportCopy(t *testing.T) {
	db := testutil.NewTestDB(t)
	db.Create(&models.TestScenario{Name: "s", RobotName: "butler", Environment: "office"})

	doc := transfer.Document{
		Scenarios: []transfer.ScenarioTransfer{
			{Name: "s", RobotName: "butler", Environment: "office", TestCases: []transfer.TestCaseTransfer{}},
		},
	}
	existing, err := transfer.LoadScenarioKeyMap(db)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	res, err := transfer.ApplyScenarioImport(db, doc, transfer.ConflictCopy, transfer.ActivationInactive, existing)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Created != 1 {
		t.Errorf("expected 1 created copy, got %+v", res)
	}
	if !transfer.NameExists(db, &models.TestScenario{}, "s_import") {
		t.Error("expected the copied scenario to use the unique import name")
	}
}

// TestApplyConfigImportKeepExistingActive 는 keep_existing 활성 정책을 고정한다.
func TestApplyConfigImportKeepExistingActive(t *testing.T) {
	db := testutil.NewTestDB(t)
	existing := &models.RoboClawConfig{Name: "c", RobotName: "butler", Environment: "office", IsActive: true}
	db.Create(existing)

	doc := transfer.Document{
		Configs: []transfer.ConfigTransfer{
			{Name: "c", RobotName: "butler", Environment: "office", IsActive: false, LimitsContent: "{}"},
		},
	}
	cur, err := transfer.LoadConfigKeyMap(db)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	res, err := transfer.ApplyConfigImport(db, doc, transfer.ConflictOverwrite, transfer.ActivationKeepExisting, cur)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Updated != 1 {
		t.Fatalf("expected 1 updated, got %+v", res)
	}

	var stored models.RoboClawConfig
	db.First(&stored, existing.ID)
	if !stored.IsActive {
		t.Error("expected keep_existing to preserve active state")
	}
}
