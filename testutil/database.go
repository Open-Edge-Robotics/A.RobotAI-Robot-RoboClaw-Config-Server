// Package testutil 는 테스트에 재사용되는 공용 헬퍼를 제공한다.
// 테스트 코드 간 중복을 줄이고, 일관된 DB/HTTP 준비 방식을 보장한다.
package testutil

import (
	"fmt"
	"net/url"
	"testing"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"

	"ai-config-server/database/models"
)

// NewTestDB 는 테스트별 고유 인메모리 SQLite DB 를 생성하고 마이그레이션한다.
// 테스트가 끝나면 DB 연결을 자동으로 정리한다.
func NewTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	dsn := fmt.Sprintf("file:%s?mode=memory&cache=shared", url.QueryEscape(t.Name()))
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{SkipDefaultTransaction: true})
	if err != nil {
		t.Fatalf("failed to open test db: %v", err)
	}
	if err := db.AutoMigrate(&models.RoboClawConfig{}, &models.TestScenario{}); err != nil {
		t.Fatalf("failed to migrate test db: %v", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatalf("failed to get sql.DB: %v", err)
	}
	t.Cleanup(func() { _ = sqlDB.Close() })
	return db
}
