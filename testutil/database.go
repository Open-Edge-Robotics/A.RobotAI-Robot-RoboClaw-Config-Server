// Package testutil 는 테스트에 재사용되는 공용 헬퍼를 제공한다.
// 테스트 코드 간 중복을 줄이고, 일관된 DB/HTTP 준비 방식을 보장한다.
package testutil

import (
	"fmt"
	"net/url"
	"sync/atomic"
	"testing"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"

	"ai-config-server/database/models"
)

// testDBCounter 는 한 테스트 안에서 여러 DB 를 열 때 DSN 이 겹치지 않게 한다.
var testDBCounter atomic.Uint64

// NewTestDB 는 테스트별 고유 인메모리 SQLite DB 를 생성하고 마이그레이션한다.
// 전역 DB 를 교체하지 않으므로 테스트는 각자 소유한 핸들을 직접 사용한다.
// 커넥션은 프로덕션과 동일하게 1개로 제한하고, 실패 경로에서도 새지 않도록
// 정리 함수를 가능한 빨리 등록한다.
func NewTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	dsn := fmt.Sprintf("file:%s?mode=memory&cache=shared",
		url.QueryEscape(fmt.Sprintf("%s-%d", t.Name(), testDBCounter.Add(1))))
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{SkipDefaultTransaction: true})
	if err != nil {
		t.Fatalf("failed to open test db: %v", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatalf("failed to get sql.DB: %v", err)
	}
	t.Cleanup(func() { _ = sqlDB.Close() })
	sqlDB.SetMaxOpenConns(1)

	if err := db.AutoMigrate(&models.RoboClawConfig{}, &models.TestScenario{}); err != nil {
		t.Fatalf("failed to migrate test db: %v", err)
	}
	return db
}
