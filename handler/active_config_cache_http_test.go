package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"ai-config-server/database/models"
	"ai-config-server/testutil"

	"github.com/gin-gonic/gin"
)

// TestActiveConfigCacheServesHotPathAndInvalidates 는 활성 설정 조회가 캐시
// 적중 경로를 타는지, 그리고 수정 API 가 캐시를 무효화하는지 검증한다.
func TestActiveConfigCacheServesHotPathAndInvalidates(t *testing.T) {
	h, db := setupRouterTestDB(t)
	cfg := models.RoboClawConfig{Name: "v1", RobotName: "butler", Environment: "office", IsActive: true}
	db.Create(&cfg)

	r := gin.New()
	r.GET("/active", h.GetActiveConfig)
	r.PUT("/c/:id", h.UpdateConfig)

	activeName := func() string {
		t.Helper()
		w := testutil.PerformJSON(r, "GET", "/active?robot_name=butler&environment=office", "", nil)
		if w.Code != http.StatusOK {
			t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
		}
		var resp models.RoboClawConfig
		if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
			t.Fatal(err)
		}
		return resp.Name
	}

	if got := activeName(); got != "v1" {
		t.Fatalf("expected v1, got %q", got)
	}

	// DB 만 바꾸고 캐시를 무효화하지 않으면 이전 응답이 그대로 나온다(핫 패스).
	if err := db.Model(&models.RoboClawConfig{}).Where("id = ?", cfg.ID).Update("name", "v2").Error; err != nil {
		t.Fatal(err)
	}
	if got := activeName(); got != "v1" {
		t.Fatalf("expected cached v1 before invalidation, got %q", got)
	}

	// 수정 API 는 캐시를 무효화하므로 다음 조회는 DB 값을 반환한다.
	w := testutil.PerformJSON(r, "PUT", fmt.Sprintf("/c/%d", cfg.ID), "", map[string]any{
		"name": "v3", "robot_name": "butler", "environment": "office",
	})
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 from update, got %d: %s", w.Code, w.Body.String())
	}
	if got := activeName(); got != "v3" {
		t.Fatalf("expected refreshed v3 after invalidation, got %q", got)
	}
}

// TestActiveConfigFileFirstThenActiveConfigKeepsProfile 는 파일 조회가 먼저 와서
// 캐시를 채운 뒤 활성 설정 JSON 을 요청해도 실제 프로필이 유지되는지 검증한다.
// 파일 경로만 캐시되고 설정 본문이 비어 있으면 디바이스가 빈 프로필을 받는다.
func TestActiveConfigFileFirstThenActiveConfigKeepsProfile(t *testing.T) {
	h, db := setupRouterTestDB(t)
	cfg := models.RoboClawConfig{
		Name: "profile", RobotName: "butler", Environment: "office", IsActive: true,
		SoulContent: "# soul", LlmProvider: "azure", LlmModel: "gpt-4o",
	}
	db.Create(&cfg)

	r := gin.New()
	r.GET("/file/:filename", h.GetActiveConfigFile)
	r.GET("/active", h.GetActiveConfig)

	w := testutil.PerformJSON(r, "GET", "/file/ROBOT.md?robot_name=butler&environment=office", "", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for file, got %d: %s", w.Code, w.Body.String())
	}
	if w.Body.String() != "# soul" {
		t.Fatalf("expected file content, got %q", w.Body.String())
	}

	w = testutil.PerformJSON(r, "GET", "/active?robot_name=butler&environment=office", "", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 for active config, got %d: %s", w.Code, w.Body.String())
	}
	var resp models.RoboClawConfig
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp.Name != "profile" || resp.LlmProvider != "azure" {
		t.Fatalf("expected cached profile to keep the active config, got %+v", resp)
	}
}

// TestHandlerQueriesHonorCanceledRequestContext 는 요청 컨텍스트가 취소되면
// DB 조회가 에러로 처리되는지 검증한다.
func TestHandlerQueriesHonorCanceledRequestContext(t *testing.T) {
	h, _ := setupRouterTestDB(t)

	r := gin.New()
	r.GET("/configs", h.ListConfigs)
	r.GET("/active", h.GetActiveConfig)

	performCanceled := func(target string) *httptest.ResponseRecorder {
		t.Helper()
		ctx, cancel := context.WithCancel(t.Context())
		cancel()
		req := httptest.NewRequest("GET", target, nil).WithContext(ctx)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		return w
	}

	if w := performCanceled("/configs"); w.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500 for canceled context on list, got %d: %s", w.Code, w.Body.String())
	}
	if w := performCanceled("/active?robot_name=butler&environment=office"); w.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500 for canceled context on active config, got %d: %s", w.Code, w.Body.String())
	}
}
