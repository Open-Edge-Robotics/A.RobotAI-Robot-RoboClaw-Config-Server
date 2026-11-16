package profile

import (
	"context"
	"testing"

	"ai-config-server/database/models"
	"ai-config-server/testutil"
)

// TestCloneNameAppendsCopySuffix 는 첫 복제 이름 규칙을 검증한다.
func TestCloneNameAppendsCopySuffix(t *testing.T) {
	db := testutil.NewTestDB(t)
	db.Create(&models.RoboClawConfig{Name: "orig", RobotName: "butler", Environment: "office"})

	if got := CloneName(context.Background(), db, &models.RoboClawConfig{}, "orig"); got != "orig_copy" {
		t.Errorf("expected 'orig_copy', got %q", got)
	}
}

// TestCloneNameIncrementsWhileTaken 는 중복 이름에 번호를 붙이는지 검증한다.
func TestCloneNameIncrementsWhileTaken(t *testing.T) {
	db := testutil.NewTestDB(t)
	db.Create(&models.RoboClawConfig{Name: "orig", RobotName: "butler", Environment: "office"})
	db.Create(&models.RoboClawConfig{Name: "orig_copy", RobotName: "butler", Environment: "office"})

	if got := CloneName(context.Background(), db, &models.RoboClawConfig{}, "orig"); got != "orig_copy_2" {
		t.Errorf("expected 'orig_copy_2', got %q", got)
	}

	db.Create(&models.RoboClawConfig{Name: "orig_copy_2", RobotName: "butler", Environment: "office"})
	if got := CloneName(context.Background(), db, &models.RoboClawConfig{}, "orig"); got != "orig_copy_3" {
		t.Errorf("expected 'orig_copy_3', got %q", got)
	}
}

// TestCloneNameUsesGivenModel 은 조회 대상 모델별로 이름을 계산하는지 검증한다.
func TestCloneNameUsesGivenModel(t *testing.T) {
	db := testutil.NewTestDB(t)
	db.Create(&models.TestScenario{Name: "flow", RobotName: "butler", Environment: "office"})

	if got := CloneName(context.Background(), db, &models.TestScenario{}, "flow"); got != "flow_copy" {
		t.Errorf("expected 'flow_copy', got %q", got)
	}
	// 다른 테이블의 동명 레코드는 복제 이름에 영향을 주지 않는다.
	if got := CloneName(context.Background(), db, &models.RoboClawConfig{}, "flow"); got != "flow_copy" {
		t.Errorf("expected 'flow_copy' for configs, got %q", got)
	}
}
