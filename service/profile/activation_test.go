package profile

import (
	"testing"

	"gorm.io/gorm"

	"ai-config-server/database/models"
	"ai-config-server/testutil"
)

// configActive 는 저장된 설정의 활성 상태를 읽는다.
func configActive(t *testing.T, db *gorm.DB, id uint) bool {
	t.Helper()
	var cfg models.RoboClawConfig
	if err := db.First(&cfg, id).Error; err != nil {
		t.Fatalf("failed to load config %d: %v", id, err)
	}
	return cfg.IsActive
}

// scenarioActive 는 저장된 시나리오의 활성 상태를 읽는다.
func scenarioActive(t *testing.T, db *gorm.DB, id uint) bool {
	t.Helper()
	var scenario models.TestScenario
	if err := db.First(&scenario, id).Error; err != nil {
		t.Fatalf("failed to load scenario %d: %v", id, err)
	}
	return scenario.IsActive
}

// TestDeactivateOthersKeepsExceptID 는 exceptID 를 제외하고 비활성화하는지 검증한다.
func TestDeactivateOthersKeepsExceptID(t *testing.T) {
	db := testutil.NewTestDB(t)
	first := models.RoboClawConfig{Name: "a", RobotName: "butler", Environment: "office", IsActive: true}
	second := models.RoboClawConfig{Name: "b", RobotName: "butler", Environment: "office", IsActive: true}
	db.Create(&first)
	db.Create(&second)

	if err := DeactivateOthers(db, &models.RoboClawConfig{}, "butler", "office", second.ID); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if configActive(t, db, first.ID) {
		t.Error("expected the other config to be deactivated")
	}
	if !configActive(t, db, second.ID) {
		t.Error("expected the excepted config to stay active")
	}
}

// TestCreateConfigInTxDeactivatesSameRobotEnvOnly 는 같은 로봇/환경만 비활성화하는지 검증한다.
func TestCreateConfigInTxDeactivatesSameRobotEnvOnly(t *testing.T) {
	db := testutil.NewTestDB(t)
	sameScope := models.RoboClawConfig{Name: "a", RobotName: "butler", Environment: "office", IsActive: true}
	otherRobot := models.RoboClawConfig{Name: "b", RobotName: "former", Environment: "office", IsActive: true}
	otherEnv := models.RoboClawConfig{Name: "c", RobotName: "butler", Environment: "factory", IsActive: true}
	db.Create(&sameScope)
	db.Create(&otherRobot)
	db.Create(&otherEnv)

	created := models.RoboClawConfig{Name: "new", RobotName: "butler", Environment: "office", IsActive: true}
	if err := db.Transaction(func(tx *gorm.DB) error { return CreateConfigInTx(tx, &created) }); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if created.ID == 0 {
		t.Fatal("expected the config to be created")
	}
	if configActive(t, db, sameScope.ID) {
		t.Error("expected the same robot/environment config to be deactivated")
	}
	if !configActive(t, db, otherRobot.ID) {
		t.Error("expected another robot's config to stay active")
	}
	if !configActive(t, db, otherEnv.ID) {
		t.Error("expected another environment's config to stay active")
	}
}

// TestCreateConfigInTxInactiveKeepsOthers 는 비활성 생성이 다른 설정을 건드리지 않는지 검증한다.
func TestCreateConfigInTxInactiveKeepsOthers(t *testing.T) {
	db := testutil.NewTestDB(t)
	active := models.RoboClawConfig{Name: "a", RobotName: "butler", Environment: "office", IsActive: true}
	db.Create(&active)

	created := models.RoboClawConfig{Name: "b", RobotName: "butler", Environment: "office"}
	if err := db.Transaction(func(tx *gorm.DB) error { return CreateConfigInTx(tx, &created) }); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !configActive(t, db, active.ID) {
		t.Error("expected the existing active config to stay active")
	}
}

// TestUpdateConfigInTxExcludesSelf 는 수정 시 자기 자신을 비활성화하지 않는지 검증한다.
func TestUpdateConfigInTxExcludesSelf(t *testing.T) {
	db := testutil.NewTestDB(t)
	other := models.RoboClawConfig{Name: "a", RobotName: "butler", Environment: "office", IsActive: true}
	target := models.RoboClawConfig{Name: "b", RobotName: "butler", Environment: "office", IsActive: true}
	db.Create(&other)
	db.Create(&target)

	target.Name = "renamed"
	if err := db.Transaction(func(tx *gorm.DB) error { return UpdateConfigInTx(tx, &target) }); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if !configActive(t, db, target.ID) {
		t.Error("expected the target config to stay active")
	}
	if configActive(t, db, other.ID) {
		t.Error("expected the other config to be deactivated")
	}
	var stored models.RoboClawConfig
	db.First(&stored, target.ID)
	if stored.Name != "renamed" {
		t.Errorf("expected the update to be saved, got %q", stored.Name)
	}
}

// TestActivateConfigInTxActivatesTargetOnly 는 활성화가 대상 하나만 활성으로 만드는지 검증한다.
func TestActivateConfigInTxActivatesTargetOnly(t *testing.T) {
	db := testutil.NewTestDB(t)
	current := models.RoboClawConfig{Name: "a", RobotName: "butler", Environment: "office", IsActive: true}
	target := models.RoboClawConfig{Name: "b", RobotName: "butler", Environment: "office"}
	db.Create(&current)
	db.Create(&target)

	if err := db.Transaction(func(tx *gorm.DB) error { return ActivateConfigInTx(tx, &target) }); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if !configActive(t, db, target.ID) {
		t.Error("expected the target config to be activated")
	}
	if configActive(t, db, current.ID) {
		t.Error("expected the previously active config to be deactivated")
	}
}

// TestCreateScenarioInTxDeactivatesSameRobotEnvOnly 는 시나리오도 같은 규칙을 쓰는지 검증한다.
func TestCreateScenarioInTxDeactivatesSameRobotEnvOnly(t *testing.T) {
	db := testutil.NewTestDB(t)
	sameScope := models.TestScenario{Name: "a", RobotName: "butler", Environment: "office", IsActive: true}
	otherRobot := models.TestScenario{Name: "b", RobotName: "former", Environment: "office", IsActive: true}
	db.Create(&sameScope)
	db.Create(&otherRobot)

	created := models.TestScenario{Name: "new", RobotName: "butler", Environment: "office", IsActive: true}
	if err := db.Transaction(func(tx *gorm.DB) error { return CreateScenarioInTx(tx, &created) }); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if scenarioActive(t, db, sameScope.ID) {
		t.Error("expected the same robot/environment scenario to be deactivated")
	}
	if !scenarioActive(t, db, otherRobot.ID) {
		t.Error("expected another robot's scenario to stay active")
	}
}

// TestUpdateScenarioInTxExcludesSelf 는 시나리오 수정이 자기 자신을 유지하는지 검증한다.
func TestUpdateScenarioInTxExcludesSelf(t *testing.T) {
	db := testutil.NewTestDB(t)
	other := models.TestScenario{Name: "a", RobotName: "butler", Environment: "office", IsActive: true}
	target := models.TestScenario{Name: "b", RobotName: "butler", Environment: "office", IsActive: true}
	db.Create(&other)
	db.Create(&target)

	if err := db.Transaction(func(tx *gorm.DB) error { return UpdateScenarioInTx(tx, &target) }); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !scenarioActive(t, db, target.ID) {
		t.Error("expected the target scenario to stay active")
	}
	if scenarioActive(t, db, other.ID) {
		t.Error("expected the other scenario to be deactivated")
	}
}

// TestActivateScenarioInTxActivatesTargetOnly 는 시나리오 활성화 규칙을 검증한다.
func TestActivateScenarioInTxActivatesTargetOnly(t *testing.T) {
	db := testutil.NewTestDB(t)
	current := models.TestScenario{Name: "a", RobotName: "butler", Environment: "office", IsActive: true}
	target := models.TestScenario{Name: "b", RobotName: "butler", Environment: "office"}
	db.Create(&current)
	db.Create(&target)

	if err := db.Transaction(func(tx *gorm.DB) error { return ActivateScenarioInTx(tx, &target) }); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !scenarioActive(t, db, target.ID) {
		t.Error("expected the target scenario to be activated")
	}
	if scenarioActive(t, db, current.ID) {
		t.Error("expected the previously active scenario to be deactivated")
	}
}
