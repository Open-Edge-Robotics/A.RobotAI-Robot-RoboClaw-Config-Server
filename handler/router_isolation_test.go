package handler

import (
	"encoding/json"
	"net/http"
	"testing"

	"ai-config-server/database/models"
	"ai-config-server/testutil"

	"github.com/gin-gonic/gin"
)

// TestRoutersDoNotShareActiveConfigCache 는 라우터(=서버)마다 캐시가 분리되는지
// 검증한다. 두 라우터가 같은 로봇/환경 키를 쓰더라도 서로 다른 DB 의 활성 설정이
// 섞이면 안 된다.
func TestRoutersDoNotShareActiveConfigCache(t *testing.T) {
	cfg := testutil.NewTestConfig()
	firstDB := testutil.NewTestDB(t)
	secondDB := testutil.NewTestDB(t)
	firstDB.Create(&models.RoboClawConfig{Name: "first", RobotName: "butler", Environment: "office", IsActive: true})
	secondDB.Create(&models.RoboClawConfig{Name: "second", RobotName: "butler", Environment: "office", IsActive: true})

	firstRouter := NewRouter(cfg, firstDB)
	secondRouter := NewRouter(cfg, secondDB)

	activeName := func(router *gin.Engine) string {
		t.Helper()
		w := testutil.PerformJSON(router, "GET", "/api/v1/configs/active?robot_name=butler&environment=office", "", nil)
		if w.Code != http.StatusOK {
			t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
		}
		var resp models.RoboClawConfig
		if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
			t.Fatal(err)
		}
		return resp.Name
	}

	// 두 라우터를 번갈아 호출해 캐시가 서로를 덮어쓰지 않는지 확인한다.
	for i := 0; i < 3; i++ {
		if got := activeName(firstRouter); got != "first" {
			t.Fatalf("round %d: expected first router to serve 'first', got %q", i, got)
		}
		if got := activeName(secondRouter); got != "second" {
			t.Fatalf("round %d: expected second router to serve 'second', got %q", i, got)
		}
	}
}

// TestRoutersDoNotShareRateLimitBuckets 는 라우터마다 요청 제한 버킷이 분리되는지
// 검증한다. 한 라우터에서 버스트를 모두 소진해도 다른 라우터는 영향을 받지 않는다.
func TestRoutersDoNotShareRateLimitBuckets(t *testing.T) {
	newLimitedRouter := func() *gin.Engine {
		r := gin.New()
		r.Use(LimitRate(0, 1)) // 충전 없음, burst 1 → 두 번째 요청부터 거절
		r.GET("/ping", Ping)
		return r
	}
	exhausted := newLimitedRouter()
	untouched := newLimitedRouter()

	if w := testutil.PerformJSON(exhausted, "GET", "/ping", "", nil); w.Code != http.StatusOK {
		t.Fatalf("expected first request to be allowed, got %d", w.Code)
	}
	if w := testutil.PerformJSON(exhausted, "GET", "/ping", "", nil); w.Code != http.StatusTooManyRequests {
		t.Fatalf("expected 429 after burst exhaustion, got %d", w.Code)
	}

	if w := testutil.PerformJSON(untouched, "GET", "/ping", "", nil); w.Code != http.StatusOK {
		t.Fatalf("expected second router to keep its own budget, got %d", w.Code)
	}
}
