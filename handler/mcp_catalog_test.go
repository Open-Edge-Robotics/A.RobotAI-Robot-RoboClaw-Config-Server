package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"ai-config-server/testutil"

	"github.com/gin-gonic/gin"
)

// TestFilterCatalog 는 검색어 필터링을 검증한다.
func TestFilterCatalog(t *testing.T) {
	entries := []McpCatalogEntry{
		{Name: "filesystem", DisplayName: "Filesystem", Description: "file ops", Category: "storage"},
		{Name: "git", DisplayName: "Git", Description: "git ops", Category: "vcs"},
	}

	// 대소문자 무시 부분 일치
	filtered := filterCatalog(entries, "GIT")
	if len(filtered) != 1 || filtered[0].Name != "git" {
		t.Errorf("expected 1 git entry, got %d", len(filtered))
	}

	// 빈 검색어 → 전체 반환
	if len(filterCatalog(entries, "")) != 2 {
		t.Errorf("expected all entries for empty query")
	}

	// 매칭 없음 → 빈 결과
	if len(filterCatalog(entries, "none")) != 0 {
		t.Errorf("expected empty result for no match")
	}
}

// TestListMcpCatalogBuiltin 는 레지스트리 미설정 시 내장 카탈로그를 반환함을 검증한다.
func TestListMcpCatalogBuiltin(t *testing.T) {
	setupRouterTestDB(t)
	r := gin.New()
	r.GET("/mcp/catalog", ListMcpCatalog(nil))

	w := testutil.PerformJSON(r, "GET", "/mcp/catalog", "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	var resp struct {
		Source  string            `json:"source"`
		Servers []McpCatalogEntry `json:"servers"`
	}
	json.Unmarshal(w.Body.Bytes(), &resp)
	if resp.Source != "builtin" {
		t.Errorf("expected builtin source, got %q", resp.Source)
	}
	if len(resp.Servers) == 0 {
		t.Error("expected non-empty builtin catalog")
	}
}

// TestListMcpCatalogQueryFilter 는 q 파라미터 필터링을 검증한다.
func TestListMcpCatalogQueryFilter(t *testing.T) {
	setupRouterTestDB(t)
	r := gin.New()
	r.GET("/mcp/catalog", ListMcpCatalog(nil))

	w := testutil.PerformJSON(r, "GET", "/mcp/catalog?q=filesystem", "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	var resp struct {
		Servers []McpCatalogEntry `json:"servers"`
	}
	json.Unmarshal(w.Body.Bytes(), &resp)
	if len(resp.Servers) == 0 {
		t.Error("expected at least one filesystem match")
	}
}

// TestShortName 은 정규화된 이름에서 마지막 세그먼트를 취하는 로직을 검증한다.
func TestShortName(t *testing.T) {
	if got := shortName("io.github.owner/name"); got != "name" {
		t.Errorf("expected 'name', got %q", got)
	}
	if got := shortName("name"); got != "name" {
		t.Errorf("expected 'name', got %q", got)
	}
	if got := shortName(""); got != "" {
		t.Errorf("expected empty, got %q", got)
	}
}

// TestPackageToCommand 은 npm/pypi/지원하지 않는 런타임 명령 매핑을 검증한다.
func TestPackageToCommand(t *testing.T) {
	cmd, args := packageToCommand(registryPackage{RegistryType: "npm", Identifier: "@x/y"})
	if cmd != "npx" || len(args) != 2 {
		t.Errorf("expected npx with 2 args, got %q %v", cmd, args)
	}

	cmd, args = packageToCommand(registryPackage{RegistryType: "pypi", Identifier: "pkg"})
	if cmd != "uvx" || len(args) != 1 {
		t.Errorf("expected uvx with 1 arg, got %q %v", cmd, args)
	}

	cmd, _ = packageToCommand(registryPackage{RegistryType: "unknown", Identifier: "x"})
	if cmd != "" {
		t.Errorf("expected empty cmd for unsupported runtime, got %q", cmd)
	}
}

// TestRegistryServerToEntry 은 sse/stdio 변환을 검증한다.
func TestRegistryServerToEntry(t *testing.T) {
	sse := registryServer{
		Name:    "io.github.owner/name",
		Remotes: []registryRemote{{Type: "sse", URL: "https://x/mcp"}},
	}
	e, ok := registryServerToEntry(sse)
	if !ok || e.Transport != "sse" || e.URL != "https://x/mcp" {
		t.Errorf("expected sse entry, got %+v ok=%v", e, ok)
	}

	streamable := registryServer{
		Name:    "io.github.owner/remote",
		Remotes: []registryRemote{{Type: "streamable-http", URL: "https://x/mcp"}},
	}
	eHTTP, ok := registryServerToEntry(streamable)
	if !ok || eHTTP.Transport != "streamable_http" || eHTTP.URL != "https://x/mcp" {
		t.Errorf("expected streamable_http entry, got %+v ok=%v", eHTTP, ok)
	}

	stdio := registryServer{
		Name: "n",
		Packages: []registryPackage{
			{RegistryType: "npm", Identifier: "@x/y"},
		},
	}
	e2, ok := registryServerToEntry(stdio)
	if !ok || e2.Transport != "stdio" || e2.Command != "npx" {
		t.Errorf("expected stdio npx entry, got %+v ok=%v", e2, ok)
	}
}

// TestEnvHints 은 환경변수 힌트 매핑을 검증한다.
func TestEnvHints(t *testing.T) {
	m := envHints([]registryEnvVar{{Name: "KEY"}, {Name: ""}})
	if len(m) != 1 || m["KEY"] != "" {
		t.Errorf("expected single empty hint, got %v", m)
	}
	if envHints(nil) != nil {
		t.Error("expected nil for empty vars")
	}
}

// TestBuiltinMcpCatalog 은 내장 카탈로그의 소스가 모두 builtin 인지 검증한다.
func TestBuiltinMcpCatalog(t *testing.T) {
	entries := builtinMcpCatalog()
	if len(entries) == 0 {
		t.Fatal("expected non-empty builtin catalog")
	}
	for _, e := range entries {
		if e.Source != "builtin" {
			t.Errorf("expected builtin source, got %q", e.Source)
		}
	}
}

// TestFetchFromRegistry 은 레지스트리 HTTP 조회를 검증한다.
func TestFetchFromRegistry(t *testing.T) {
	var gotSearch string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotSearch = r.URL.Query().Get("search")
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"servers":[{"name":"git","packages":[{"registry_type":"npm","identifier":"x"}]}]}`))
	}))
	defer server.Close()

	entries, err := fetchFromRegistry(context.Background(), server.URL, "git")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if gotSearch != "git" {
		t.Errorf("expected search=git, got %q", gotSearch)
	}
	if len(entries) == 0 {
		t.Error("expected at least one entry")
	}
	if entries[0].Source != "registry" {
		t.Errorf("expected registry source, got %q", entries[0].Source)
	}
}
