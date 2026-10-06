package handler

import (
	"testing"

	"ai-config-server/database"
	"ai-config-server/testutil"
	"github.com/gin-gonic/gin"
)

func TestReadyChecksDatabase(t *testing.T) {
	setupRouterTestDB(t)
	r := gin.New()
	r.GET("/ready", Ready)
	w := testutil.PerformJSON(r, "GET", "/ready", "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}
}

func TestReadyReturnsUnavailableWithoutDatabase(t *testing.T) {
	original := database.DB
	database.DB = nil
	t.Cleanup(func() { database.DB = original })
	r := gin.New()
	r.GET("/ready", Ready)
	w := testutil.PerformJSON(r, "GET", "/ready", "", nil)
	if w.Code != 503 {
		t.Fatalf("expected 503, got %d", w.Code)
	}
}
