package database

import (
	"path/filepath"
	"testing"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"

	"ai-config-server/database/models"
)

// openTestDB 는 테스트가 소유하는 DB 를 열고, 정리 시 닫는다.
func openTestDB(t *testing.T, dsn string) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{SkipDefaultTransaction: true})
	if err != nil {
		t.Fatalf("failed to open test db: %v", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatalf("failed to get sql.DB: %v", err)
	}
	t.Cleanup(func() { _ = sqlDB.Close() })
	return db
}

// TestInitSeedsData 는 초기 시드 데이터 생성을 검증한다.
func TestInitSeedsData(t *testing.T) {
	dsn := filepath.Join(t.TempDir(), "test.db")
	db, err := Init(dsn)
	if err != nil {
		t.Fatalf("Init failed: %v", err)
	}
	t.Cleanup(func() { closeTestDB(t, db) })

	var cfgCount int64
	if err := db.Model(&models.RoboClawConfig{}).Count(&cfgCount).Error; err != nil {
		t.Fatalf("count configs failed: %v", err)
	}
	if cfgCount < 2 {
		t.Errorf("expected at least 2 seeded configs, got %d", cfgCount)
	}

	var scCount int64
	if err := db.Model(&models.TestScenario{}).Count(&scCount).Error; err != nil {
		t.Fatalf("count scenarios failed: %v", err)
	}
	if scCount < 3 {
		t.Errorf("expected at least 3 seeded scenarios, got %d", scCount)
	}
}

// TestInitReturnsNilAndErrorForInvalidDSN 은 DB 를 열 수 없을 때 nil 과 에러를
// 함께 반환하는지 검증한다. 기존 시그니처는 성공/실패 여부만 알려 줘서 호출자가
// DB 핸들을 얻을 방법이 없었다.
func TestInitReturnsNilAndErrorForInvalidDSN(t *testing.T) {
	dsn := filepath.Join(t.TempDir(), "missing-dir", "nested", "test.db")

	db, err := Init(dsn)
	if err == nil {
		closeTestDB(t, db)
		t.Fatal("expected Init to fail for an unwritable DSN")
	}
	if db != nil {
		closeTestDB(t, db)
		t.Fatal("expected Init to return a nil DB on failure")
	}
}

// TestInitDoesNotReseed 는 재초기화 시 중복 시드를 방지함을 검증한다.
func TestInitDoesNotReseed(t *testing.T) {
	dsn := filepath.Join(t.TempDir(), "test.db")
	first, err := Init(dsn)
	if err != nil {
		t.Fatalf("first Init failed: %v", err)
	}
	closeTestDB(t, first)

	// 동일 DB 파일에 대해 다시 Init → 시드 중복 방지
	second, err := Init(dsn)
	if err != nil {
		t.Fatalf("second Init failed: %v", err)
	}
	t.Cleanup(func() { closeTestDB(t, second) })

	var cfgCount int64
	if err := second.Model(&models.RoboClawConfig{}).Count(&cfgCount).Error; err != nil {
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
	legacy := openTestDB(t, dsn)
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
	closeTestDB(t, legacy)

	db, err := Init(dsn)
	if err != nil {
		t.Fatalf("Init failed: %v", err)
	}
	t.Cleanup(func() { closeTestDB(t, db) })

	var cfg models.RoboClawConfig
	if err := db.Where("robot_name = ? AND environment = ?", "former", "real").First(&cfg).Error; err != nil {
		t.Fatalf("query config failed: %v", err)
	}
	if !cfg.MaestroEnabled {
		t.Error("expected maestro_enabled to be backfilled for a profile with maestro_ip")
	}

	// 스위치가 없는 프로필은 꺼진 상태로 남는다.
	if err := db.Exec(
		"INSERT INTO robo_claw_configs (name, robot_name, environment, maestro_ip, is_active) VALUES (?, ?, ?, ?, ?)",
		"butler-real", "butler", "real", "", true,
	).Error; err != nil {
		t.Fatalf("insert profile without ip failed: %v", err)
	}
	var noIp models.RoboClawConfig
	if err := db.Where("robot_name = ? AND environment = ?", "butler", "real").First(&noIp).Error; err != nil {
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
	first, err := Init(dsn)
	if err != nil {
		t.Fatalf("first Init failed: %v", err)
	}
	var cfg models.RoboClawConfig
	if err := first.First(&cfg).Error; err != nil {
		t.Fatalf("query seeded config failed: %v", err)
	}
	cfg.MaestroIp = "10.0.0.5"
	cfg.RobotId = "former-01"
	cfg.MaestroEnabled = false
	if err := first.Save(&cfg).Error; err != nil {
		t.Fatalf("update config failed: %v", err)
	}
	closeTestDB(t, first)

	second, err := Init(dsn)
	if err != nil {
		t.Fatalf("second Init failed: %v", err)
	}
	t.Cleanup(func() { closeTestDB(t, second) })

	var reloaded models.RoboClawConfig
	if err := second.First(&reloaded, cfg.ID).Error; err != nil {
		t.Fatalf("reload config failed: %v", err)
	}
	if reloaded.MaestroEnabled {
		t.Error("expected maestro_enabled to stay false after restart")
	}
}

// closeTestDB 는 테스트가 소유한 DB 커넥션을 닫는다. 여러 번 불려도 안전하다.
func closeTestDB(t *testing.T, db *gorm.DB) {
	t.Helper()
	if db == nil {
		return
	}
	sqlDB, err := db.DB()
	if err != nil {
		return
	}
	_ = sqlDB.Close()
}
