package transfer_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"gorm.io/gorm"

	"ai-config-server/database/models"
	"ai-config-server/service/transfer"
	"ai-config-server/testutil"
)

// validConfig 는 검증을 통과하는 최소 설정 항목이다.
func validConfig(name string) transfer.ConfigTransfer {
	return transfer.ConfigTransfer{Name: name, RobotName: "butler", Environment: "office", LimitsContent: "{}"}
}

// validScenario 는 검증을 통과하는 최소 시나리오 항목이다.
func validScenario(name string) transfer.ScenarioTransfer {
	return transfer.ScenarioTransfer{
		Name:        name,
		RobotName:   "butler",
		Environment: "office",
		TestCases:   []transfer.TestCaseTransfer{{ID: "tc1", Name: "case", Type: "ping"}},
	}
}

func validDocument(configs []transfer.ConfigTransfer, scenarios []transfer.ScenarioTransfer) transfer.Document {
	return transfer.Document{
		Kind:            transfer.Kind,
		SchemaVersion:   transfer.SchemaVersion,
		ExportedAt:      time.Unix(0, 0).UTC(),
		IncludesSecrets: true,
		Configs:         configs,
		Scenarios:       scenarios,
	}
}

// TestValidateAcceptsWellFormedDocument 는 정상 문서가 경고/오류 없이 통과하는지 검증한다.
func TestValidateAcceptsWellFormedDocument(t *testing.T) {
	doc := validDocument([]transfer.ConfigTransfer{validConfig("cfg-a")}, []transfer.ScenarioTransfer{validScenario("sc-a")})

	res := transfer.Validate(doc, nil, nil)
	if !res.Valid {
		t.Fatalf("expected valid document, got errors: %v", res.Errors)
	}
	if len(res.Errors) != 0 || len(res.Warnings) != 0 {
		t.Fatalf("expected no errors/warnings, got %v / %v", res.Errors, res.Warnings)
	}
	if res.SchemaVersion != transfer.SchemaVersion || !res.IncludesSecrets {
		t.Errorf("expected schema/secrets echoed, got %d/%t", res.SchemaVersion, res.IncludesSecrets)
	}
	if res.Summary.Configs != 1 || res.Summary.Scenarios != 1 {
		t.Errorf("expected totals 1/1, got %+v", res.Summary)
	}
}

// TestValidateRejectsMismatchedKindAndSchema 는 kind/schema 불일치를 오류로 보고하는지 검증한다.
func TestValidateRejectsMismatchedKindAndSchema(t *testing.T) {
	doc := validDocument(nil, nil)
	doc.Kind = "other-backup"
	doc.SchemaVersion = 99

	res := transfer.Validate(doc, nil, nil)
	if res.Valid {
		t.Fatal("expected invalid document")
	}
	if len(res.Errors) != 2 {
		t.Fatalf("expected kind and schema errors, got %v", res.Errors)
	}
}

// TestValidateWarnsWhenSecretsOmitted 는 민감 정보 미포함 경고를 검증한다.
func TestValidateWarnsWhenSecretsOmitted(t *testing.T) {
	doc := validDocument(nil, nil)
	doc.IncludesSecrets = false

	res := transfer.Validate(doc, nil, nil)
	if !res.Valid {
		t.Fatalf("expected valid document, got %v", res.Errors)
	}
	if len(res.Warnings) != 1 {
		t.Fatalf("expected one warning, got %v", res.Warnings)
	}
}

// TestValidateRejectsMissingIdentityFields 는 name/robot_name/environment 누락을 검증한다.
func TestValidateRejectsMissingIdentityFields(t *testing.T) {
	doc := validDocument(
		[]transfer.ConfigTransfer{{Name: "cfg-a", RobotName: "", Environment: "office"}},
		[]transfer.ScenarioTransfer{{Name: "", RobotName: "butler", Environment: "office"}},
	)

	res := transfer.Validate(doc, nil, nil)
	if res.Valid {
		t.Fatal("expected invalid document")
	}
	if len(res.Errors) != 2 {
		t.Fatalf("expected one error per entity, got %v", res.Errors)
	}
}

// TestValidateRejectsDuplicateEntries 는 백업 내부 중복 항목을 검증한다.
func TestValidateRejectsDuplicateEntries(t *testing.T) {
	doc := validDocument(
		[]transfer.ConfigTransfer{validConfig("dup"), validConfig("dup")},
		[]transfer.ScenarioTransfer{validScenario("dup"), validScenario("dup")},
	)

	res := transfer.Validate(doc, nil, nil)
	if res.Valid {
		t.Fatal("expected invalid document")
	}
	if len(res.Errors) != 2 {
		t.Fatalf("expected duplicate errors for config and scenario, got %v", res.Errors)
	}
	// 중복 항목은 집계에서 제외된다.
	if res.Summary.Configs != 1 || res.Summary.Scenarios != 1 {
		t.Errorf("expected duplicates not counted, got %+v", res.Summary)
	}
}

// TestValidateCountsConflictsAgainstExisting 는 기존 데이터 충돌 집계를 검증한다.
func TestValidateCountsConflictsAgainstExisting(t *testing.T) {
	existingConfigs := map[string]*models.RoboClawConfig{
		"cfg-a|butler|office": {Name: "cfg-a", RobotName: "butler", Environment: "office"},
	}
	existingScenarios := map[string]*models.TestScenario{
		"sc-a|butler|office": {Name: "sc-a", RobotName: "butler", Environment: "office"},
	}
	doc := validDocument(
		[]transfer.ConfigTransfer{validConfig("cfg-a"), validConfig("cfg-b")},
		[]transfer.ScenarioTransfer{validScenario("sc-a"), validScenario("sc-b")},
	)

	res := transfer.Validate(doc, existingConfigs, existingScenarios)
	if !res.Valid {
		t.Fatalf("expected valid document, got %v", res.Errors)
	}
	s := res.Summary
	if s.Configs != 2 || s.ConflictingConfigs != 1 || s.NewConfigs != 1 {
		t.Errorf("unexpected config summary: %+v", s)
	}
	if s.Scenarios != 2 || s.ConflictingScenarios != 1 || s.NewScenarios != 1 {
		t.Errorf("unexpected scenario summary: %+v", s)
	}
}

// TestValidateRejectsNestedJSONErrors 는 중첩 JSON 무결성 검증을 확인한다.
func TestValidateRejectsNestedJSONErrors(t *testing.T) {
	cfg := validConfig("cfg-a")
	cfg.LimitsContent = "{bad"
	cfg.GrpcTargetPeersJson = "[bad"
	doc := validDocument([]transfer.ConfigTransfer{cfg}, nil)

	res := transfer.Validate(doc, nil, nil)
	if res.Valid {
		t.Fatal("expected invalid document")
	}
	if len(res.Errors) != 2 {
		t.Fatalf("expected limits and grpc errors, got %v", res.Errors)
	}
}

// TestValidateRejectsMissingTestCaseFields 는 테스트 케이스 필수 필드 검증을 확인한다.
func TestValidateRejectsMissingTestCaseFields(t *testing.T) {
	sc := validScenario("sc-a")
	sc.TestCases = []transfer.TestCaseTransfer{{ID: "tc1", Name: "", Type: ""}}
	doc := validDocument(nil, []transfer.ScenarioTransfer{sc})

	res := transfer.Validate(doc, nil, nil)
	if res.Valid {
		t.Fatal("expected invalid document")
	}
	if len(res.Errors) != 1 {
		t.Fatalf("expected one test case error, got %v", res.Errors)
	}
}

// TestExportRespectsIncludeFlagsAndSecrets 는 내보내기 옵션 처리를 검증한다.
func TestExportRespectsIncludeFlagsAndSecrets(t *testing.T) {
	db := testutil.NewTestDB(t)
	db.Create(&models.RoboClawConfig{Name: "cfg-a", RobotName: "butler", Environment: "office", AzureOpenaiApiKey: "secret"})
	db.Create(&models.TestScenario{Name: "sc-a", RobotName: "butler", Environment: "office"})

	doc, err := transfer.Export(context.Background(), db, false, true, false, time.Unix(10, 0).UTC())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if doc.Kind != transfer.Kind || doc.SchemaVersion != transfer.SchemaVersion {
		t.Errorf("unexpected kind/schema: %s/%d", doc.Kind, doc.SchemaVersion)
	}
	if !doc.ExportedAt.Equal(time.Unix(10, 0)) {
		t.Errorf("expected exportedAt passed through, got %v", doc.ExportedAt)
	}
	if len(doc.Configs) != 1 || len(doc.Scenarios) != 0 {
		t.Fatalf("expected 1 config and 0 scenarios, got %d/%d", len(doc.Configs), len(doc.Scenarios))
	}
	if doc.Configs[0].AzureOpenaiApiKey != nil {
		t.Errorf("expected secrets omitted, got %v", *doc.Configs[0].AzureOpenaiApiKey)
	}

	withSecrets, err := transfer.Export(context.Background(), db, true, true, true, time.Unix(0, 0))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if withSecrets.Configs[0].AzureOpenaiApiKey == nil || *withSecrets.Configs[0].AzureOpenaiApiKey != "secret" {
		t.Errorf("expected secrets included, got %v", withSecrets.Configs[0].AzureOpenaiApiKey)
	}
	if len(withSecrets.Scenarios) != 1 {
		t.Fatalf("expected 1 scenario, got %d", len(withSecrets.Scenarios))
	}
}

// TestImportCreatesFromEmptyServer 는 신규 서버 가져오기를 검증한다.
func TestImportCreatesFromEmptyServer(t *testing.T) {
	db := testutil.NewTestDB(t)
	doc := validDocument([]transfer.ConfigTransfer{validConfig("cfg-a")}, []transfer.ScenarioTransfer{validScenario("sc-a")})

	res, err := transfer.Import(context.Background(), db, doc, transfer.ConflictSkip, transfer.ActivationInactive)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Configs.Created != 1 || res.Scenarios.Created != 1 {
		t.Fatalf("expected created 1/1, got %+v", res)
	}

	var stored models.RoboClawConfig
	if err := db.Where("name = ?", "cfg-a").First(&stored).Error; err != nil {
		t.Fatal(err)
	}
	// butler 로봇은 서비스 기본 경로가 채워진다(handler 위임 래퍼와 동일 동작).
	if stored.ButlerScriptsDir == "" || stored.ButlerSourceDir == "" {
		t.Errorf("expected butler path defaults applied, got %q/%q", stored.ButlerScriptsDir, stored.ButlerSourceDir)
	}
}

// TestImportConflictPolicies 는 skip/overwrite/copy 충돌 정책을 검증한다.
func TestImportConflictPolicies(t *testing.T) {
	db := testutil.NewTestDB(t)
	db.Create(&models.RoboClawConfig{Name: "dup", RobotName: "butler", Environment: "office", Description: "before"})
	db.Create(&models.TestScenario{Name: "dup", RobotName: "butler", Environment: "office"})

	doc := validDocument(
		[]transfer.ConfigTransfer{{Name: "dup", RobotName: "butler", Environment: "office", Description: "after", LimitsContent: "{}"}},
		[]transfer.ScenarioTransfer{validScenario("dup")},
	)

	skipped, err := transfer.Import(context.Background(), db, doc, transfer.ConflictSkip, transfer.ActivationInactive)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if skipped.Configs.Skipped != 1 || skipped.Scenarios.Skipped != 1 {
		t.Fatalf("skip policy: expected skipped 1/1, got %+v", skipped)
	}

	overwritten, err := transfer.Import(context.Background(), db, doc, transfer.ConflictOverwrite, transfer.ActivationInactive)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if overwritten.Configs.Updated != 1 || overwritten.Scenarios.Updated != 1 {
		t.Fatalf("overwrite policy: expected updated 1/1, got %+v", overwritten)
	}
	var stored models.RoboClawConfig
	db.Where("name = ?", "dup").First(&stored)
	if stored.Description != "after" {
		t.Errorf("expected overwrite to update description, got %q", stored.Description)
	}

	copied, err := transfer.Import(context.Background(), db, doc, transfer.ConflictCopy, transfer.ActivationInactive)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if copied.Configs.Created != 1 || copied.Scenarios.Created != 1 {
		t.Fatalf("copy policy: expected created 1/1, got %+v", copied)
	}
	var copiedConfig models.RoboClawConfig
	if err := db.Where("name = ?", "dup_import").First(&copiedConfig).Error; err != nil {
		t.Fatalf("expected copied config 'dup_import': %v", err)
	}
}

// TestImportActivationPolicies 는 inactive/preserve/keep_existing 정책을 검증한다.
func TestImportActivationPolicies(t *testing.T) {
	inactiveDoc := validDocument([]transfer.ConfigTransfer{
		{Name: "cfg-a", RobotName: "butler", Environment: "office", IsActive: true, LimitsContent: "{}"},
	}, nil)

	dbInactive := testutil.NewTestDB(t)
	if _, err := transfer.Import(context.Background(), dbInactive, inactiveDoc, transfer.ConflictSkip, transfer.ActivationInactive); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var inactive models.RoboClawConfig
	dbInactive.Where("name = ?", "cfg-a").First(&inactive)
	if inactive.IsActive {
		t.Error("expected inactive policy to clear is_active")
	}

	dbPreserve := testutil.NewTestDB(t)
	if _, err := transfer.Import(context.Background(), dbPreserve, inactiveDoc, transfer.ConflictSkip, transfer.ActivationPreserve); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var preserved models.RoboClawConfig
	dbPreserve.Where("name = ?", "cfg-a").First(&preserved)
	if !preserved.IsActive {
		t.Error("expected preserve policy to keep backup is_active")
	}

	dbKeep := testutil.NewTestDB(t)
	existing := &models.RoboClawConfig{Name: "cfg-a", RobotName: "butler", Environment: "office", IsActive: true}
	dbKeep.Create(existing)
	keepDoc := validDocument([]transfer.ConfigTransfer{
		{Name: "cfg-a", RobotName: "butler", Environment: "office", IsActive: false, LimitsContent: "{}"},
	}, nil)
	if _, err := transfer.Import(context.Background(), dbKeep, keepDoc, transfer.ConflictOverwrite, transfer.ActivationKeepExisting); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var kept models.RoboClawConfig
	dbKeep.First(&kept, existing.ID)
	if !kept.IsActive {
		t.Error("expected keep_existing policy to preserve stored is_active")
	}
}

// TestImportKeepsSingleActivePerRobotEnvironment 는 활성 배타성을 검증한다.
func TestImportKeepsSingleActivePerRobotEnvironment(t *testing.T) {
	db := testutil.NewTestDB(t)
	db.Create(&models.RoboClawConfig{Name: "old-active", RobotName: "butler", Environment: "office", IsActive: true})

	doc := validDocument([]transfer.ConfigTransfer{
		{Name: "new-active", RobotName: "butler", Environment: "office", IsActive: true, LimitsContent: "{}"},
	}, nil)
	if _, err := transfer.Import(context.Background(), db, doc, transfer.ConflictSkip, transfer.ActivationPreserve); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var activeCount int64
	db.Model(&models.RoboClawConfig{}).
		Where("robot_name = ? AND environment = ? AND is_active = ?", "butler", "office", true).
		Count(&activeCount)
	if activeCount != 1 {
		t.Fatalf("expected exactly one active config, got %d", activeCount)
	}
	var newActive models.RoboClawConfig
	db.Where("name = ?", "new-active").First(&newActive)
	if !newActive.IsActive {
		t.Error("expected imported config to be active under preserve policy")
	}
}

// TestImportRollsBackOnApplyFailure 는 적용 단계 실패 시 전체 롤백을 검증한다.
func TestImportRollsBackOnApplyFailure(t *testing.T) {
	db := testutil.NewTestDB(t)
	// 'boom' 설정 생성 시점에 실패를 주입해 트랜잭션 롤백을 유도한다.
	db.Callback().Create().Before("gorm:create").Register("test:fail_on_boom", func(tx *gorm.DB) {
		if cfg, ok := tx.Statement.Dest.(*models.RoboClawConfig); ok && cfg.Name == "boom" {
			tx.AddError(errors.New("boom"))
		}
	})

	doc := validDocument([]transfer.ConfigTransfer{validConfig("good"), validConfig("boom")}, nil)
	if _, err := transfer.Import(context.Background(), db, doc, transfer.ConflictSkip, transfer.ActivationInactive); err == nil {
		t.Fatal("expected import error")
	}

	var count int64
	db.Model(&models.RoboClawConfig{}).Count(&count)
	if count != 0 {
		t.Fatalf("expected rollback to remove all rows, got %d", count)
	}
}

// TestImportRejectsInvalidDocument 는 사전 검증 실패 시 400 본문용 결과를 반환하는지 검증한다.
func TestImportRejectsInvalidDocument(t *testing.T) {
	db := testutil.NewTestDB(t)
	doc := validDocument(nil, nil)
	doc.SchemaVersion = 99

	_, err := transfer.Import(context.Background(), db, doc, transfer.ConflictSkip, transfer.ActivationInactive)
	if err == nil {
		t.Fatal("expected validation error")
	}
	var invalid *transfer.InvalidDocumentError
	if !errors.As(err, &invalid) {
		t.Fatalf("expected InvalidDocumentError, got %v", err)
	}
	if invalid.Validation.Valid {
		t.Error("expected validation result to be invalid")
	}
	if len(invalid.Validation.Errors) != 1 {
		t.Errorf("expected one schema error, got %v", invalid.Validation.Errors)
	}
}

// TestImportPreservesExistingSecretsWhenBackupOmitsThem 는 민감 값 보존을 검증한다.
func TestImportPreservesExistingSecretsWhenBackupOmitsThem(t *testing.T) {
	db := testutil.NewTestDB(t)
	db.Create(&models.RoboClawConfig{Name: "existing", RobotName: "butler", Environment: "office", AzureOpenaiApiKey: "keep-me"})

	cfg := validConfig("existing")
	cfg.Description = "overwritten"
	doc := validDocument([]transfer.ConfigTransfer{cfg}, nil)
	doc.IncludesSecrets = false

	if _, err := transfer.Import(context.Background(), db, doc, transfer.ConflictOverwrite, transfer.ActivationInactive); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var stored models.RoboClawConfig
	db.Where("name = ?", "existing").First(&stored)
	if stored.AzureOpenaiApiKey != "keep-me" {
		t.Errorf("expected existing secret preserved, got %q", stored.AzureOpenaiApiKey)
	}
	if stored.Description != "overwritten" {
		t.Errorf("expected non-secret field updated, got %q", stored.Description)
	}
}

// TestImportReturnsLoadErrorForBrokenDatabase 는 조회 실패 표식 오류를 검증한다.
func TestImportReturnsLoadErrorForBrokenDatabase(t *testing.T) {
	db := testutil.NewTestDB(t)
	if err := db.Migrator().DropTable(&models.RoboClawConfig{}); err != nil {
		t.Fatalf("failed to drop table: %v", err)
	}

	_, err := transfer.Import(context.Background(), db, validDocument(nil, nil), transfer.ConflictSkip, transfer.ActivationInactive)
	if !errors.Is(err, transfer.ErrConfigsLoad) {
		t.Fatalf("expected ErrConfigsLoad, got %v", err)
	}

	if err := db.Migrator().DropTable(&models.TestScenario{}); err != nil {
		t.Fatalf("failed to drop table: %v", err)
	}
	if err := db.AutoMigrate(&models.RoboClawConfig{}); err != nil {
		t.Fatalf("failed to migrate: %v", err)
	}
	_, err = transfer.Import(context.Background(), db, validDocument(nil, nil), transfer.ConflictSkip, transfer.ActivationInactive)
	if !errors.Is(err, transfer.ErrScenariosLoad) {
		t.Fatalf("expected ErrScenariosLoad, got %v", err)
	}
}
