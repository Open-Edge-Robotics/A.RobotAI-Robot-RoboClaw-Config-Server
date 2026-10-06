package database

import (
	"path/filepath"
	"testing"

	"ai-config-server/database/models"
)

// TestInitSeedsData 는 초기 시드 데이터 생성을 검증한다.
func TestInitSeedsData(t *testing.T) {
	dsn := filepath.Join(t.TempDir(), "test.db")
	if err := Init(dsn); err != nil {
		t.Fatalf("Init failed: %v", err)
	}
	defer func() {
		if sqlDB, err := DB.DB(); err == nil {
			sqlDB.Close()
		}
	}()

	var cfgCount int64
	if err := DB.Model(&models.RoboClawConfig{}).Count(&cfgCount).Error; err != nil {
		t.Fatalf("count configs failed: %v", err)
	}
	if cfgCount < 2 {
		t.Errorf("expected at least 2 seeded configs, got %d", cfgCount)
	}

	var scCount int64
	if err := DB.Model(&models.TestScenario{}).Count(&scCount).Error; err != nil {
		t.Fatalf("count scenarios failed: %v", err)
	}
	if scCount < 3 {
		t.Errorf("expected at least 3 seeded scenarios, got %d", scCount)
	}
}

// TestInitDoesNotReseed 는 재초기화 시 중복 시드를 방지함을 검증한다.
func TestInitDoesNotReseed(t *testing.T) {
	dsn := filepath.Join(t.TempDir(), "test.db")
	if err := Init(dsn); err != nil {
		t.Fatalf("first Init failed: %v", err)
	}
	if sqlDB, err := DB.DB(); err == nil {
		sqlDB.Close()
	}

	// 동일 DB 파일에 대해 다시 Init → 시드 중복 방지
	if err := Init(dsn); err != nil {
		t.Fatalf("second Init failed: %v", err)
	}
	defer func() {
		if sqlDB, err := DB.DB(); err == nil {
			sqlDB.Close()
		}
	}()

	var cfgCount int64
	if err := DB.Model(&models.RoboClawConfig{}).Count(&cfgCount).Error; err != nil {
		t.Fatalf("count configs failed: %v", err)
	}
	// butler + former = 2
	if cfgCount != 2 {
		t.Errorf("expected exactly 2 configs (no reseed), got %d", cfgCount)
	}
}
