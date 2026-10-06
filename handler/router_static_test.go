package handler

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"

	"ai-config-server/testutil"
)

// setupWebFixture 는 임시 작업 디렉터리에 Flutter Web 산출물 픽스처를 만들고
// 테스트 동안 작업 위치를 그곳으로 옮긴다.
// NewRouter 의 정적 서빙 경로(./frontend/build/web)가 상대 경로이기 때문이다.
func setupWebFixture(t *testing.T) string {
	t.Helper()

	dir := t.TempDir()
	webDir := filepath.Join(dir, "frontend", "build", "web")
	if err := os.MkdirAll(webDir, 0o755); err != nil {
		t.Fatalf("failed to create web fixture dir: %v", err)
	}

	indexHTML := "<!DOCTYPE html><html><body>fixture-index</body></html>"
	if err := os.WriteFile(filepath.Join(webDir, "index.html"), []byte(indexHTML), 0o644); err != nil {
		t.Fatalf("failed to write index.html: %v", err)
	}

	// 릴리스 빌드의 flutter.js 는 소스맵을 참조하지만 .map 파일은 생성되지 않는다.
	// (--source-maps 없이 빌드하면 주석만 남고 map 은 산출물에 없다.)
	flutterJS := "console.log(1);\n//# sourceMappingURL=flutter.js.map\n"
	if err := os.WriteFile(filepath.Join(webDir, "flutter.js"), []byte(flutterJS), 0o644); err != nil {
		t.Fatalf("failed to write flutter.js: %v", err)
	}

	t.Chdir(dir)
	ipBuckets = sync.Map{}

	return webDir
}

func assertJSONErrorBody(t *testing.T, raw []byte) {
	t.Helper()
	var resp map[string]any
	if err := json.Unmarshal(raw, &resp); err != nil {
		t.Fatalf("expected JSON error body, got %q: %v", string(raw), err)
	}
	if resp["error"] == nil {
		t.Fatalf("expected error field, got %v", resp)
	}
}

// TestRouterMissingSourceMapReturns404 는 배포 산출물에 .map 이 없을 때
// SPA fallback(index.html)이 아니라 404 를 반환하는지 검증한다.
//
// index.html 을 200 text/html 로 돌려주면 브라우저 devtools 소스맵 로더가
// HTML 을 JSON.parse 하면서
// "JSON.parse: unexpected character at line 1 column 1" 오류를 낸다.
func TestRouterMissingSourceMapReturns404(t *testing.T) {
	setupWebFixture(t)
	r := NewRouter(testutil.NewTestConfig())

	w := testutil.PerformJSON(r, "GET", "/web/flutter.js.map", "", nil)

	if w.Code != http.StatusNotFound {
		t.Fatalf("expected 404 for missing source map, got %d (content-type=%q)",
			w.Code, w.Header().Get("Content-Type"))
	}
	if strings.Contains(strings.ToLower(w.Body.String()), "<!doctype html") {
		t.Fatalf("expected JSON 404, got index.html body: %s", w.Body.String())
	}
	assertJSONErrorBody(t, w.Body.Bytes())
}

// TestRouterMissingStaticAssetReturns404 는 누락된 정적 자산 전반(.json/.wasm 등)에
// 대해서도 HTML 이 아니라 404 를 반환하는지 검증한다.
// 200 + HTML 로 위장하면 재배포 후 해시가 바뀐 자산이나 스테일 service worker
// 요청이 조용히 성공한 것처럼 보여 캐시 문제를 추적하기 어려워진다.
func TestRouterMissingStaticAssetReturns404(t *testing.T) {
	setupWebFixture(t)
	r := NewRouter(testutil.NewTestConfig())

	for _, path := range []string{
		"/web/assets/AssetManifest.json",
		"/web/canvaskit/canvaskit.wasm",
		"/web/assets/missing.png",
	} {
		w := testutil.PerformJSON(r, "GET", path, "", nil)
		if w.Code != http.StatusNotFound {
			t.Errorf("%s: expected 404, got %d (content-type=%q)",
				path, w.Code, w.Header().Get("Content-Type"))
			continue
		}
		if strings.Contains(strings.ToLower(w.Body.String()), "<!doctype html") {
			t.Errorf("%s: expected JSON 404, got index.html body", path)
		}
	}
}

// TestRouterSpaDeepLinkServesIndexHTML 은 확장자가 없는 SPA 딥링크는
// 기존처럼 index.html 로 fallback 되는지 검증한다.
func TestRouterSpaDeepLinkServesIndexHTML(t *testing.T) {
	setupWebFixture(t)
	r := NewRouter(testutil.NewTestConfig())

	for _, path := range []string{"/web/", "/web/dashboard", "/web/configs/1/edit"} {
		w := testutil.PerformJSON(r, "GET", path, "", nil)
		if w.Code != http.StatusOK {
			t.Errorf("%s: expected 200, got %d", path, w.Code)
			continue
		}
		if !strings.Contains(w.Body.String(), "fixture-index") {
			t.Errorf("%s: expected index.html body, got %q", path, w.Body.String())
		}
	}
}

// TestRouterServesExistingStaticAsset 은 실제로 존재하는 산출물은 그대로 서빙되는지
// 검증한다(확장자 필터가 정상 자산까지 막지 않아야 한다).
func TestRouterServesExistingStaticAsset(t *testing.T) {
	setupWebFixture(t)
	r := NewRouter(testutil.NewTestConfig())

	w := testutil.PerformJSON(r, "GET", "/web/flutter.js", "", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), "sourceMappingURL") {
		t.Errorf("expected flutter.js body, got %q", w.Body.String())
	}
}

// TestRouterWebPrefixBoundary 는 /web 경계 밖 경로(/webhook 등)가
// index.html fallback 에 삼켜지지 않는지 검증한다.
func TestRouterWebPrefixBoundary(t *testing.T) {
	setupWebFixture(t)
	r := NewRouter(testutil.NewTestConfig())

	for _, path := range []string{"/webhook", "/webhook/notify", "/no/such/route"} {
		w := testutil.PerformJSON(r, "GET", path, "", nil)
		if w.Code != http.StatusNotFound {
			t.Errorf("%s: expected 404, got %d", path, w.Code)
			continue
		}
		if strings.Contains(strings.ToLower(w.Body.String()), "<!doctype html") {
			t.Errorf("%s: expected JSON 404, got index.html body", path)
		}
		assertJSONErrorBody(t, w.Body.Bytes())
	}
}
