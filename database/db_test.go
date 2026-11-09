package database

import (
	"path/filepath"
	"testing"

	"ai-config-server/database/models"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
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

// TestInitBackfillsMaestroEnabledOnColumnAddition 은 스위치 컬럼이 처음 추가될 때
// IP가 설정된 기존 프로필의 동작을 보존하는지 검증한다.
func TestInitBackfillsMaestroEnabledOnColumnAddition(t *testing.T) {
	dsn := filepath.Join(t.TempDir(), "legacy.db")
	legacy, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatalf("legacy open failed: %v", err)
	}
	if err := legacy.AutoMigrate(&models.RoboClawConfig{}); err != nil {
		t.Fatalf("legacy migrate failed: %v", err)
	}
	// 스위치 도입 이전 상태 재현: 컬럼 제거 + MAESTRO_IP만 설정된 프로필
	if err := legacy.Exec("ALTER TABLE robo_claw_configs DROP COLUMN maestro_enabled").Error; err != nil {
		t.Fatalf("drop column failed: %v", err)
	}
	if err := legacy.Exec(
		"INSERT INTO robo_claw_configs (name, robot_name, environment, maestro_ip, is_active) VALUES (?, ?, ?, ?, ?)",
		"former-real", "former", "real", "10.0.0.5", true,
	).Error; err != nil {
		t.Fatalf("insert legacy config failed: %v", err)
	}
	if sqlDB, err := legacy.DB(); err == nil {
		sqlDB.Close()
	}

	if err := Init(dsn); err != nil {
		t.Fatalf("Init failed: %v", err)
	}
	defer func() {
		if sqlDB, err := DB.DB(); err == nil {
			sqlDB.Close()
		}
	}()

	var cfg models.RoboClawConfig
	if err := DB.Where("robot_name = ? AND environment = ?", "former", "real").First(&cfg).Error; err != nil {
		t.Fatalf("query config failed: %v", err)
	}
	if !cfg.MaestroEnabled {
		t.Error("expected maestro_enabled to be backfilled for a profile with maestro_ip")
	}

	// 스위치가 없는 프로필은 꺼진 상태로 남는다.
	if err := DB.Exec(
		"INSERT INTO robo_claw_configs (name, robot_name, environment, maestro_ip, is_active) VALUES (?, ?, ?, ?, ?)",
		"butler-real", "butler", "real", "", true,
	).Error; err != nil {
		t.Fatalf("insert profile without ip failed: %v", err)
	}
	var noIp models.RoboClawConfig
	if err := DB.Where("robot_name = ? AND environment = ?", "butler", "real").First(&noIp).Error; err != nil {
		t.Fatalf("query config failed: %v", err)
	}
	if noIp.MaestroEnabled {
		t.Error("expected maestro_enabled to stay false for a profile without maestro_ip")
	}
}

// TestInitKeepsOperatorDisabledMaestroEnabled 는 운영자가 끈 스위치가
// 재기동 시 되살아나지 않는지 검증한다.
func TestInitKeepsOperatorDisabledMaestroEnabled(t *testing.T) {
	dsn := filepath.Join(t.TempDir(), "test.db")
	if err := Init(dsn); err != nil {
		t.Fatalf("first Init failed: %v", err)
	}
	var cfg models.RoboClawConfig
	if err := DB.First(&cfg).Error; err != nil {
		t.Fatalf("query seeded config failed: %v", err)
	}
	cfg.MaestroIp = "10.0.0.5"
	cfg.RobotId = "former-01"
	cfg.MaestroEnabled = false
	if err := DB.Save(&cfg).Error; err != nil {
		t.Fatalf("update config failed: %v", err)
	}
	if sqlDB, err := DB.DB(); err == nil {
		sqlDB.Close()
	}

	if err := Init(dsn); err != nil {
		t.Fatalf("second Init failed: %v", err)
	}
	defer func() {
		if sqlDB, err := DB.DB(); err == nil {
			sqlDB.Close()
		}
	}()

	var reloaded models.RoboClawConfig
	if err := DB.First(&reloaded, cfg.ID).Error; err != nil {
		t.Fatalf("reload config failed: %v", err)
	}
	if reloaded.MaestroEnabled {
		t.Error("expected maestro_enabled to stay false after restart")
	}
}
