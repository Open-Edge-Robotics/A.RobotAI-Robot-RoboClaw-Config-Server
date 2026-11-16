package handler

import (
	"testing"

	"ai-config-server/testutil"
	"github.com/gin-gonic/gin"
)

func TestReadyChecksDatabase(t *testing.T) {
	h, _ := setupRouterTestDB(t)
	r := gin.New()
	r.GET("/ready", h.Ready)
	w := testutil.PerformJSON(r, "GET", "/ready", "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}
}

func TestReadyReturnsUnavailableWithoutDatabase(t *testing.T) {
	r := gin.New()
	r.GET("/ready", NewHandler(nil).Ready)
	w := testutil.PerformJSON(r, "GET", "/ready", "", nil)
	if w.Code != 503 {
		t.Fatalf("expected 503, got %d", w.Code)
	}
}

// TestReadyReturnsUnavailableWhenDatabaseClosed 는 DB 커넥션이 닫힌 뒤
// 준비 상태 확인이 503 을 반환하는지 검증한다.
func TestReadyReturnsUnavailableWhenDatabaseClosed(t *testing.T) {
	h, db := setupRouterTestDB(t)
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatalf("failed to get sql.DB: %v", err)
	}
	if err := sqlDB.Close(); err != nil {
		t.Fatalf("failed to close sql.DB: %v", err)
	}

	r := gin.New()
	r.GET("/ready", h.Ready)
	w := testutil.PerformJSON(r, "GET", "/ready", "", nil)
	if w.Code != 503 {
		t.Fatalf("expected 503 for closed database, got %d: %s", w.Code, w.Body.String())
	}
}
