package handler

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	"ai-config-server/database"
	"ai-config-server/database/models"
	"ai-config-server/testutil"

	"github.com/gin-gonic/gin"
)

// mcpServerView는 MCP 서버 JSON 검증용 뷰다.
type mcpServerView struct {
	Name      string            `json:"name"`
	Transport string            `json:"transport"`
	Command   string            `json:"command"`
	Cwd       string            `json:"cwd"`
	Env       map[string]string `json:"env"`
	Headers   map[string]string `json:"headers"`
}

func parseMcpServers(t *testing.T, raw string) []mcpServerView {
	t.Helper()
	var servers []mcpServerView
	if err := json.Unmarshal([]byte(raw), &servers); err != nil {
		t.Fatalf("expected valid MCP servers JSON, got %q: %v", raw, err)
	}
	return servers
}

// ===== 마스킹 =====

// TestMaskMcpServersJsonMasksOnlyCredentials 는 등록한 MCP 서버가 대시보드에
// 보이도록 구조는 유지하고 자격 증명(env/headers 값)만 마스킹하는지 검증한다.
func TestMaskMcpServersJsonMasksOnlyCredentials(t *testing.T) {
	raw := `[
		{"name":"fs","transport":"stdio","command":"npx","args":["-y","server-fs"],"cwd":"/data",
		 "env":{"GITHUB_TOKEN":"ghp-secret","LOG_LEVEL":"debug"}},
		{"name":"remote","transport":"sse","url":"https://mcp.example.com/sse",
		 "headers":{"Authorization":"Bearer secret","X-Trace":"on"}}
	]`

	masked := maskMcpServersJson(raw)
	servers := parseMcpServers(t, masked)
	if len(servers) != 2 {
		t.Fatalf("expected 2 servers to remain visible, got %d: %s", len(servers), masked)
	}

	stdio := servers[0]
	if stdio.Name != "fs" || stdio.Transport != "stdio" || stdio.Command != "npx" || stdio.Cwd != "/data" {
		t.Errorf("expected stdio server structure to stay visible, got %+v", stdio)
	}
	if stdio.Env["GITHUB_TOKEN"] != MaskValue {
		t.Errorf("expected GITHUB_TOKEN masked, got %q", stdio.Env["GITHUB_TOKEN"])
	}
	if stdio.Env["LOG_LEVEL"] != MaskValue {
		t.Errorf("expected all env values masked, got %q", stdio.Env["LOG_LEVEL"])
	}
	if _, ok := stdio.Env["GITHUB_TOKEN"]; !ok {
		t.Errorf("expected env key to stay visible, got %+v", stdio.Env)
	}

	remote := servers[1]
	if remote.Name != "remote" || remote.Transport != "sse" {
		t.Errorf("expected sse server structure to stay visible, got %+v", remote)
	}
	if remote.Headers["Authorization"] != MaskValue {
		t.Errorf("expected Authorization header masked, got %q", remote.Headers["Authorization"])
	}
	if remote.Headers["X-Trace"] != MaskValue {
		t.Errorf("expected all header values masked, got %q", remote.Headers["X-Trace"])
	}
}

// TestMaskMcpServersJsonEdgeCases 는 빈 목록과 파싱 불가 값의 처리를 검증한다.
func TestMaskMcpServersJsonEdgeCases(t *testing.T) {
	for _, empty := range []string{"", "[]"} {
		if got := maskMcpServersJson(empty); got != empty {
			t.Errorf("expected %q to stay untouched, got %q", empty, got)
		}
	}

	// JSON 배열이 아니면 값 유출을 막기 위해 전체를 마스킹한다.
	for _, invalid := range []string{"********", `{"name":"fs"}`, "not-json"} {
		if got := maskMcpServersJson(invalid); got != MaskValue {
			t.Errorf("expected %q to fall back to whole mask, got %q", invalid, got)
		}
	}
}

// ===== 병합(마스킹 값 복원) =====

// TestMergeMaskedMcpServersJsonRestoresStoredSecrets 는 대시보드가 마스킹된 값을
// 그대로 저장했을 때 실제 자격 증명이 보존되는지 검증한다.
func TestMergeMaskedMcpServersJsonRestoresStoredSecrets(t *testing.T) {
	existing := `[{"name":"fs","transport":"stdio","command":"npx","env":{"GITHUB_TOKEN":"ghp-secret","LOG_LEVEL":"debug"}}]`
	incoming := maskMcpServersJson(existing)

	merged := mergeMaskedMcpServersJson(existing, incoming)
	servers := parseMcpServers(t, merged)

	if servers[0].Env["GITHUB_TOKEN"] != "ghp-secret" {
		t.Errorf("expected stored token preserved, got %q", servers[0].Env["GITHUB_TOKEN"])
	}
	if servers[0].Env["LOG_LEVEL"] != "debug" {
		t.Errorf("expected stored env preserved, got %q", servers[0].Env["LOG_LEVEL"])
	}
	if servers[0].Command != "npx" {
		t.Errorf("expected structure preserved, got %+v", servers[0])
	}
}

// TestMergeMaskedMcpServersJsonPreservesSecretsWhenServerRenamed 는 이름 변경 시에도
// 실행 대상이 유일하게 일치하면 기존 자격 증명을 보존하는지 검증한다.
func TestMergeMaskedMcpServersJsonPreservesSecretsWhenServerRenamed(t *testing.T) {
	existing := `[{"name":"github","transport":"stdio","command":"npx","args":["-y","server-github"],"env":{"GITHUB_TOKEN":"ghp-secret"}}]`
	incoming := `[{"name":"github-renamed","transport":"stdio","command":"npx","args":["-y","server-github"],"env":{"GITHUB_TOKEN":"********"}}]`

	merged := mergeMaskedMcpServersJson(existing, incoming)
	servers := parseMcpServers(t, merged)

	if got := servers[0].Env["GITHUB_TOKEN"]; got != "ghp-secret" {
		t.Errorf("expected stored token preserved after rename, got %q", got)
	}
}

// TestMergeMaskedMcpServersJsonKeepsNewValues 는 새로 입력한 값은 마스킹 값으로
// 덮어쓰지 않고 그대로 저장되는지 검증한다.
func TestMergeMaskedMcpServersJsonKeepsNewValues(t *testing.T) {
	existing := `[{"name":"fs","transport":"stdio","command":"npx","env":{"OLD_TOKEN":"old","KEEP":"keep-me"}}]`
	incoming := `[{"name":"fs","transport":"stdio","command":"npx","env":{"NEW_TOKEN":"new-token","KEEP":"********"}}]`

	merged := mergeMaskedMcpServersJson(existing, incoming)
	servers := parseMcpServers(t, merged)

	if servers[0].Env["NEW_TOKEN"] != "new-token" {
		t.Errorf("expected new value kept, got %q", servers[0].Env["NEW_TOKEN"])
	}
	if servers[0].Env["KEEP"] != "keep-me" {
		t.Errorf("expected stored value restored, got %q", servers[0].Env["KEEP"])
	}
}

// TestMergeMaskedMcpServersJsonDropsMaskForUnmatchedServer 는 다른 서버의 마스킹 값이
// 실제 자격 증명으로 저장되지 않도록 제거되는지 검증한다.
func TestMergeMaskedMcpServersJsonDropsMaskForUnmatchedServer(t *testing.T) {
	existing := `[{"name":"old","transport":"stdio","command":"old-command","env":{"TOKEN":"old-secret"}}]`
	incoming := `[{"name":"new","transport":"stdio","command":"new-command","env":{"TOKEN":"********"}}]`

	merged := mergeMaskedMcpServersJson(existing, incoming)
	servers := parseMcpServers(t, merged)

	if _, ok := servers[0].Env["TOKEN"]; ok {
		t.Errorf("expected unmatched masked credential removed, got %q", servers[0].Env["TOKEN"])
	}
	if strings.Contains(merged, MaskValue) {
		t.Errorf("expected unmatched mask not to be persisted, got %s", merged)
	}
}

// TestMergeMaskedMcpServersJsonDropsUnmatchedMask 는 기존 서버에 없는 새 키의
// 마스킹 값이 자격 증명으로 저장되지 않도록 제거되는지 검증한다.
func TestMergeMaskedMcpServersJsonDropsUnmatchedMask(t *testing.T) {
	existing := `[{"name":"fs","transport":"stdio","command":"npx","env":{"EXISTING":"value"}}]`
	incoming := `[{"name":"fs","transport":"stdio","command":"npx","env":{"EXISTING":"********","BRAND_NEW":"********"}}]`

	merged := mergeMaskedMcpServersJson(existing, incoming)
	servers := parseMcpServers(t, merged)

	if servers[0].Env["EXISTING"] != "value" {
		t.Errorf("expected stored value restored, got %q", servers[0].Env["EXISTING"])
	}
	if got, ok := servers[0].Env["BRAND_NEW"]; ok {
		t.Errorf("expected unmatched mask removed, got %q", got)
	}
}

// TestMergeMaskedMcpServersJsonHandlesServerChanges 는 서버 삭제/추가와
// 이름이 겹치지 않는 경우를 검증한다.
func TestMergeMaskedMcpServersJsonHandlesServerChanges(t *testing.T) {
	existing := `[{"name":"fs","env":{"TOKEN":"secret"}},{"name":"removed","env":{"TOKEN":"gone"}}]`
	incoming := `[{"name":"fs","env":{"TOKEN":"********"}},{"name":"added","env":{"TOKEN":"new"}}]`

	merged := mergeMaskedMcpServersJson(existing, incoming)
	servers := parseMcpServers(t, merged)

	if len(servers) != 2 {
		t.Fatalf("expected 2 servers, got %d: %s", len(servers), merged)
	}
	if servers[0].Env["TOKEN"] != "secret" {
		t.Errorf("expected matched server token restored, got %q", servers[0].Env["TOKEN"])
	}
	if servers[1].Name != "added" || servers[1].Env["TOKEN"] != "new" {
		t.Errorf("expected added server untouched, got %+v", servers[1])
	}
	if len(merged) == 0 {
		t.Fatal("unreachable")
	}
}

// ===== 수정 API 통합 =====

// TestUpdateConfigPreservesMcpCredentialsWhenFieldMasked 는 대시보드가 받은
// 마스킹 목록을 그대로 저장해도 실제 자격 증명이 보존되는지 end-to-end 로 검증한다.
func TestUpdateConfigPreservesMcpCredentialsWhenFieldMasked(t *testing.T) {
	setupRouterTestDB(t)
	cfg := models.RoboClawConfig{
		Name:        "c",
		RobotName:   "butler",
		Environment: "office",
		McpServersJson: `[{"name":"gh","transport":"stdio","command":"npx","args":["-y","server-github"],` +
			`"env":{"GITHUB_TOKEN":"ghp-secret","LOG_LEVEL":"debug"}}]`,
	}
	database.DB.Create(&cfg)

	r := gin.New()
	r.PUT("/c/:id", UpdateConfig)

	// 대시보드 응답과 동일하게 자격 증명만 마스킹된 목록을 만들어 그대로 저장한다.
	masked := maskMcpServersJson(cfg.McpServersJson)
	if masked == cfg.McpServersJson {
		t.Fatalf("expected masking to change credentials, got %q", masked)
	}

	body := map[string]any{
		"name": "c", "robot_name": "butler", "environment": "office",
		"mcp_servers_json": masked,
	}
	w := testutil.PerformJSON(r, "PUT", fmt.Sprintf("/c/%d", cfg.ID), "", body)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var stored models.RoboClawConfig
	database.DB.First(&stored, cfg.ID)
	servers := parseMcpServers(t, stored.McpServersJson)

	if servers[0].Env["GITHUB_TOKEN"] != "ghp-secret" {
		t.Errorf("expected GITHUB_TOKEN preserved, got %q", servers[0].Env["GITHUB_TOKEN"])
	}
	if servers[0].Env["LOG_LEVEL"] != "debug" {
		t.Errorf("expected LOG_LEVEL preserved, got %q", servers[0].Env["LOG_LEVEL"])
	}
	if servers[0].Command != "npx" {
		t.Errorf("expected command preserved, got %q", servers[0].Command)
	}
}

// TestUpdateConfigOverwritesMcpCredentialWhenProvided 는 마스킹 대신 새 값을
// 입력하면 그 값으로 교체되는지 검증한다.
func TestUpdateConfigOverwritesMcpCredentialWhenProvided(t *testing.T) {
	setupRouterTestDB(t)
	cfg := models.RoboClawConfig{
		Name:           "c",
		RobotName:      "butler",
		Environment:    "office",
		McpServersJson: `[{"name":"gh","env":{"GITHUB_TOKEN":"old-token","OTHER":"keep"}}]`,
	}
	database.DB.Create(&cfg)

	r := gin.New()
	r.PUT("/c/:id", UpdateConfig)

	body := map[string]any{
		"name": "c", "robot_name": "butler", "environment": "office",
		"mcp_servers_json": `[{"name":"gh","env":{"GITHUB_TOKEN":"new-token","OTHER":"********"}}]`,
	}
	w := testutil.PerformJSON(r, "PUT", fmt.Sprintf("/c/%d", cfg.ID), "", body)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var stored models.RoboClawConfig
	database.DB.First(&stored, cfg.ID)
	servers := parseMcpServers(t, stored.McpServersJson)

	if servers[0].Env["GITHUB_TOKEN"] != "new-token" {
		t.Errorf("expected new token stored, got %q", servers[0].Env["GITHUB_TOKEN"])
	}
	if servers[0].Env["OTHER"] != "keep" {
		t.Errorf("expected masked OTHER preserved, got %q", servers[0].Env["OTHER"])
	}
}

// TestUpdateConfigPreservesWholeMaskedMcpServersJson 는 JSON 전체가 마스킹된
// 구형 클라이언트 payload 도 계속 보존되는지 검증한다(하위 호환).
// (동일 계약을 TestUpdateConfigPreservesMaskedMcpServersJson 이 이미 검증하므로
//
//	여기서는 전용 헬퍼를 쓰는 경로만 확인한다.)
func TestUpdateConfigPreservesWholeMaskedMcpServersJsonViaRouter(t *testing.T) {
	setupRouterTestDB(t)
	original := `[{"name":"fs","env":{"TOKEN":"secret"}}]`
	cfg := models.RoboClawConfig{
		Name: "c", RobotName: "butler", Environment: "office",
		McpServersJson: original,
	}
	database.DB.Create(&cfg)

	r := gin.New()
	r.PUT("/c/:id", UpdateConfig)

	body := map[string]any{
		"name": "c", "robot_name": "butler", "environment": "office",
		"mcp_servers_json": MaskValue,
	}
	w := testutil.PerformJSON(r, "PUT", fmt.Sprintf("/c/%d", cfg.ID), "", body)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var stored models.RoboClawConfig
	database.DB.First(&stored, cfg.ID)
	servers := parseMcpServers(t, stored.McpServersJson)
	if servers[0].Env["TOKEN"] != "secret" {
		t.Errorf("expected whole-masked payload to preserve stored value, got %q", servers[0].Env["TOKEN"])
	}
}
