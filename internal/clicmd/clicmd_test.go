package clicmd_test

import (
	"bytes"
	"encoding/json"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"ai-config-server/handler"
	"ai-config-server/internal/clicmd"
	"ai-config-server/internal/client"
	"ai-config-server/testutil"
)

type cliHarness struct {
	t          *testing.T
	baseURL    string
	adminTok   string
	deviceTok  string
	configPath string
	env        map[string]string
}

func newCLIHarness(t *testing.T) *cliHarness {
	t.Helper()
	cfg := testutil.NewTestConfig()
	cfg.Security.AdminToken = "cli-admin-secret"
	cfg.Security.DeviceToken = "cli-device-secret"
	cfg.Security.RequireAuth = true

	db := testutil.NewTestDB(t)
	srv := httptest.NewServer(handler.NewRouter(cfg, db))
	t.Cleanup(srv.Close)

	dir := t.TempDir()
	return &cliHarness{
		t:          t,
		baseURL:    srv.URL,
		adminTok:   "cli-admin-secret",
		deviceTok:  "cli-device-secret",
		configPath: filepath.Join(dir, "profiles.json"),
		env: map[string]string{
			"TEST_ADMIN_TOK":  "cli-admin-secret",
			"TEST_DEVICE_TOK": "cli-device-secret",
		},
	}
}

func (h *cliHarness) run(stdin string, args ...string) (string, string, error) {
	var outBuf, errBuf bytes.Buffer
	rt := &clicmd.Runtime{
		Out:        &outBuf,
		Err:        &errBuf,
		In:         strings.NewReader(stdin),
		ConfigPath: h.configPath,
		Timeout:    5 * time.Second,
		Getenv: func(k string) string {
			return h.env[k]
		},
	}
	root := clicmd.NewRootCommand("test", rt)
	err := root.Execute(args)
	return outBuf.String(), errBuf.String(), err
}

func TestProfileAndStatusWorkflow(t *testing.T) {
	h := newCLIHarness(t)

	out, _, err := h.run("", "profile", "set", "lab",
		"--url", h.baseURL,
		"--token-env", "TEST_ADMIN_TOK",
		"--device-token-env", "TEST_DEVICE_TOK",
		"--use", "--json",
	)
	if err != nil {
		t.Fatalf("profile set failed: %v", err)
	}
	if !strings.Contains(out, `"active": true`) || strings.Contains(out, h.adminTok) {
		t.Fatalf("unexpected profile set output: %s", out)
	}

	// List profiles (table & json)
	if out, _, err := h.run("", "profile", "list"); err != nil || !strings.Contains(out, "lab") {
		t.Fatalf("profile list failed: %q err=%v", out, err)
	}
	if _, _, err := h.run("", "profile", "use", "lab"); err != nil {
		t.Fatalf("profile use failed: %v", err)
	}

	// Status admin & device
	out, _, err = h.run("", "status", "--json")
	if err != nil {
		t.Fatalf("status --json failed: %v (out=%s)", err, out)
	}
	if !strings.Contains(out, `"auth_ok": true`) || !strings.Contains(out, `"ready": true`) {
		t.Fatalf("unexpected status output: %s", out)
	}
	if out, _, err := h.run("", "status", "--device"); err != nil || !strings.Contains(out, "AUTH_OK") {
		t.Fatalf("status --device failed: %q err=%v", out, err)
	}

	// Remove profile
	if _, _, err := h.run("", "profile", "remove", "lab", "--json"); err != nil {
		t.Fatalf("profile remove failed: %v", err)
	}
	if _, _, err := h.run("", "profile", "use", "lab"); client.ExitCodeFromError(err) != client.ExitNotFound {
		t.Fatalf("expected ExitNotFound for removed profile, got %v", err)
	}
}

func TestConfigFullWorkflowAndSafetyGuards(t *testing.T) {
	h := newCLIHarness(t)
	if _, _, err := h.run("", "profile", "set", "lab", "--url", h.baseURL, "--token-env", "TEST_ADMIN_TOK", "--device-token-env", "TEST_DEVICE_TOK", "--use"); err != nil {
		t.Fatalf("profile set failed: %v", err)
	}

	// 1. Create via stdin + --set + --set-file
	tmpDir := t.TempDir()
	soulPath := filepath.Join(tmpDir, "ROBOT.md")
	if err := os.WriteFile(soulPath, []byte("# Initial Soul\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	createJSON := `{"name":"Butler_Office","robot_name":"butler","environment":"office","llm_provider":"openai","llm_model":"gpt-4.1","openai_api_key":"sk-super-secret"}`
	out, _, err := h.run(createJSON, "config", "create", "--from", "-", "--set", "ros_domain_id=12", "--set-file", "soul_content="+soulPath, "--json")
	if err != nil {
		t.Fatalf("config create failed: %v", err)
	}
	var created map[string]any
	if err := json.Unmarshal([]byte(out), &created); err != nil {
		t.Fatalf("invalid create JSON: %v", err)
	}
	if created["openai_api_key"] != "********" {
		t.Fatalf("expected masked api key in response, got %v", created["openai_api_key"])
	}

	// 2. List & Get by selector
	if out, _, err := h.run("", "config", "list", "--robot", "butler", "--env", "office"); err != nil || !strings.Contains(out, "Butler_Office") {
		t.Fatalf("config list failed: %q err=%v", out, err)
	}
	if out, _, err := h.run("", "config", "get", "--robot", "butler", "--env", "office", "--name", "Butler_Office"); err != nil || !strings.Contains(out, "Butler_Office") {
		t.Fatalf("config get by selector failed: %q err=%v", out, err)
	}

	// 3. Patch --dry-run (no mutation)
	out, _, err = h.run("", "config", "patch", "1", "--set", "llm_model=gpt-4o-mini", "--dry-run", "--json")
	if err != nil || !strings.Contains(out, `"dry_run": true`) || !strings.Contains(out, `"gpt-4o-mini"`) {
		t.Fatalf("config patch --dry-run failed: %q err=%v", out, err)
	}
	// Verify server unchanged after dry-run
	if out, _, err := h.run("", "config", "get", "1"); err != nil || !strings.Contains(out, `"gpt-4.1"`) {
		t.Fatalf("dry-run should not mutate server: %q err=%v", out, err)
	}

	// 4. Patch real
	if out, _, err := h.run("", "config", "patch", "1", "--set", "llm_model=gpt-4o-mini", "--json"); err != nil || !strings.Contains(out, `"gpt-4o-mini"`) {
		t.Fatalf("config patch failed: %q err=%v", out, err)
	}

	// 5. File get (.env masked on stdout, 0600 on --out) & file set
	out, errOut, err := h.run("", "config", "file", "get", "1", ".env")
	if err != nil {
		t.Fatalf("config file get .env failed: %v", err)
	}
	if strings.Contains(out, "sk-super-secret") {
		t.Fatalf(".env stdout leaked secret: %s", out)
	}
	if !strings.Contains(errOut, "마스킹") {
		t.Errorf("expected masking notice on stderr, got: %q", errOut)
	}
	envOutFile := filepath.Join(tmpDir, "robot.env")
	if _, _, err := h.run("", "config", "file", "get", "1", ".env", "--out", envOutFile, "--json"); err != nil {
		t.Fatalf("config file get --out failed: %v", err)
	}
	info, err := os.Stat(envOutFile)
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("expected 0600 perm for saved .env, got %v err=%v", info, err)
	}
	if _, _, err := h.run("# Updated Soul\n", "config", "file", "set", "1", "ROBOT.md", "--from", "-", "--json"); err != nil {
		t.Fatalf("config file set failed: %v", err)
	}

	// 6. Activate requires --yes
	if _, _, err := h.run("", "config", "activate", "1"); client.ExitCodeFromError(err) != client.ExitUsage {
		t.Fatalf("expected ExitUsage without --yes, got %v", err)
	}
	if _, _, err := h.run("", "config", "activate", "1", "--yes", "--json"); err != nil {
		t.Fatalf("config activate --yes failed: %v", err)
	}

	// 7. Device verification
	if out, _, err := h.run("", "device", "active-config", "--robot", "butler", "--env", "office"); err != nil || !strings.Contains(out, "gpt-4o-mini") {
		t.Fatalf("device active-config failed: %q err=%v", out, err)
	}
	if out, _, err := h.run("", "device", "active-config", "--robot", "butler", "--env", "office", "--v2"); err != nil || !strings.Contains(out, "schema_version") {
		t.Fatalf("device active-config --v2 failed: %q err=%v", out, err)
	}
	if out, _, err := h.run("", "device", "file", "ROBOT.md", "--robot", "butler", "--env", "office"); err != nil || !strings.Contains(out, "Updated Soul") {
		t.Fatalf("device file ROBOT.md failed: %q err=%v", out, err)
	}

	// 8. Clone with --new-name, diff, and delete
	if out, _, err := h.run("", "config", "clone", "1", "--new-name", "Butler_Clone", "--json"); err != nil || !strings.Contains(out, "Butler_Clone") {
		t.Fatalf("config clone failed: %q err=%v", out, err)
	}
	if out, _, err := h.run("", "config", "diff", "1", "2"); err != nil || !strings.Contains(out, "name") {
		t.Fatalf("config diff failed: %q err=%v", out, err)
	}
	if _, _, err := h.run("", "config", "delete", "2"); client.ExitCodeFromError(err) != client.ExitUsage {
		t.Fatalf("expected ExitUsage for delete without --yes, got %v", err)
	}
	if _, _, err := h.run("", "config", "delete", "2", "--yes"); err != nil {
		t.Fatalf("config delete --yes failed: %v", err)
	}
}

func TestScenarioTransferMcpAndSchemaWorkflow(t *testing.T) {
	h := newCLIHarness(t)
	if _, _, err := h.run("", "profile", "set", "lab", "--url", h.baseURL, "--token-env", "TEST_ADMIN_TOK", "--device-token-env", "TEST_DEVICE_TOK", "--use"); err != nil {
		t.Fatalf("profile set failed: %v", err)
	}

	// Scenario CRUD + case add/remove
	scJSON := `{"name":"Office_Smoke","description":"init","robot_name":"butler","environment":"office","test_cases":[{"id":"tc1","name":"Ping","type":"ping","timeout_ms":1000,"enabled":true}]}`
	if out, _, err := h.run(scJSON, "scenario", "create", "--from", "-", "--json"); err != nil || !strings.Contains(out, "Office_Smoke") {
		t.Fatalf("scenario create failed: %q err=%v", out, err)
	}
	if out, _, err := h.run("", "scenario", "list"); err != nil || !strings.Contains(out, "Office_Smoke") {
		t.Fatalf("scenario list failed: %q err=%v", out, err)
	}
	if out, _, err := h.run("", "scenario", "patch", "1", "--set", "description=patched", "--json"); err != nil || !strings.Contains(out, "patched") {
		t.Fatalf("scenario patch failed: %q err=%v", out, err)
	}
	if out, _, err := h.run("", "scenario", "case", "add", "1", "--id", "tc2", "--name", "Battery", "--type", "battery", "--json"); err != nil || !strings.Contains(out, "tc2") {
		t.Fatalf("scenario case add failed: %q err=%v", out, err)
	}
	if _, _, err := h.run("", "scenario", "case", "remove", "1", "tc2", "--yes", "--json"); err != nil {
		t.Fatalf("scenario case remove failed: %v", err)
	}
	if _, _, err := h.run("", "scenario", "activate", "1", "--yes"); err != nil {
		t.Fatalf("scenario activate failed: %v", err)
	}
	if out, _, err := h.run("", "device", "active-scenario", "--robot", "butler", "--env", "office"); err != nil || !strings.Contains(out, "Office_Smoke") {
		t.Fatalf("device active-scenario failed: %q err=%v", out, err)
	}
	if _, _, err := h.run("", "scenario", "clone", "1", "--new-name", "Office_Smoke_Copy"); err != nil {
		t.Fatalf("scenario clone failed: %v", err)
	}
	if _, _, err := h.run("", "scenario", "delete", "2", "--yes"); err != nil {
		t.Fatalf("scenario delete failed: %v", err)
	}

	// Transfer export -> validate -> import
	backupPath := filepath.Join(t.TempDir(), "backup.json")
	if _, _, err := h.run("", "transfer", "export", "--out", backupPath, "--include-secrets", "--json"); err != nil {
		t.Fatalf("transfer export failed: %v", err)
	}
	info, err := os.Stat(backupPath)
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("expected 0600 backup file when --include-secrets, got %v err=%v", info, err)
	}
	if out, _, err := h.run("", "transfer", "validate", "--from", backupPath); err != nil || !strings.Contains(out, `"valid": true`) {
		t.Fatalf("transfer validate failed: %q err=%v", out, err)
	}
	if _, _, err := h.run("", "transfer", "import", "--from", backupPath, "--conflict", "overwrite"); client.ExitCodeFromError(err) != client.ExitUsage {
		t.Fatalf("expected ExitUsage for overwrite without --yes, got %v", err)
	}
	if out, _, err := h.run("", "transfer", "import", "--from", backupPath, "--dry-run"); err != nil || !strings.Contains(out, `"valid": true`) {
		t.Fatalf("transfer import --dry-run failed: %q err=%v", out, err)
	}
	if _, _, err := h.run("", "transfer", "import", "--from", backupPath, "--conflict", "skip"); err != nil {
		t.Fatalf("transfer import failed: %v", err)
	}

	// MCP catalog & offline schema fields
	if out, _, err := h.run("", "mcp", "catalog", "--json"); err != nil || !strings.Contains(out, `"servers"`) {
		t.Fatalf("mcp catalog failed: %q err=%v", out, err)
	}
	if out, _, err := h.run("", "schema", "fields", "--query", "llm_model", "--json"); err != nil || !strings.Contains(out, `"llm_model"`) {
		t.Fatalf("schema fields --json failed: %q err=%v", out, err)
	}
	if out, _, err := h.run("", "schema", "fields", "--secrets-only"); err != nil || !strings.Contains(out, "SECRET") {
		t.Fatalf("schema fields --secrets-only failed: %q err=%v", out, err)
	}
}

func TestEdgeCasesAndAdditionalSubcommands(t *testing.T) {
	h := newCLIHarness(t)
	if _, _, err := h.run("", "profile", "set", "lab", "--url", h.baseURL, "--token-env", "TEST_ADMIN_TOK", "--use"); err != nil {
		t.Fatalf("profile set failed: %v", err)
	}

	// Config file set for SKILLS.md, TROUBLESHOOTING.md, ROBOT_LIMITS.json, and invalid filename
	createJSON := `{"name":"Edge_Cfg","robot_name":"former","environment":"factory"}`
	if _, _, err := h.run(createJSON, "config", "create", "--from", "-"); err != nil {
		t.Fatalf("config create failed: %v", err)
	}
	for _, tc := range []struct {
		file, body string
	}{
		{"SKILLS.md", "# Skills\n"},
		{"TROUBLESHOOTING.md", "# Troubleshooting\n"},
		{"ROBOT_LIMITS.json", `{"max_speed":1.0}`},
	} {
		if _, _, err := h.run(tc.body, "config", "file", "set", "1", tc.file, "--from", "-"); err != nil {
			t.Fatalf("config file set %s failed: %v", tc.file, err)
		}
	}
	if _, _, err := h.run("x", "config", "file", "set", "1", "UNKNOWN.txt", "--from", "-"); client.ExitCodeFromError(err) != client.ExitUsage {
		t.Fatalf("expected ExitUsage for unsupported file, got %v", err)
	}

	// Config diff --against stdin
	if out, _, err := h.run(`{"name":"Other_Name"}`, "config", "diff", "1", "--against", "-"); err != nil || !strings.Contains(out, "Other_Name") {
		t.Fatalf("config diff --against failed: %q err=%v", out, err)
	}

	// Scenario get by selector, update (PUT), duplicate case add conflict
	scJSON := `{"name":"Edge_Sc","description":"d1","robot_name":"former","environment":"factory","test_cases":[{"id":"tc1","name":"Ping","type":"ping","timeout_ms":1000,"enabled":true}]}`
	if _, _, err := h.run(scJSON, "scenario", "create", "--from", "-"); err != nil {
		t.Fatalf("scenario create failed: %v", err)
	}
	if out, _, err := h.run("", "scenario", "get", "--robot", "former", "--env", "factory", "--name", "Edge_Sc"); err != nil || !strings.Contains(out, "Edge_Sc") {
		t.Fatalf("scenario get by selector failed: %q err=%v", out, err)
	}
	putJSON := `{"name":"Edge_Sc_Put","description":"d2","robot_name":"former","environment":"factory","test_cases":[{"id":"tc1","name":"Ping","type":"ping","timeout_ms":2000,"enabled":true}]}`
	if out, _, err := h.run(putJSON, "scenario", "update", "1", "--from", "-", "--json"); err != nil || !strings.Contains(out, "Edge_Sc_Put") {
		t.Fatalf("scenario update failed: %q err=%v", out, err)
	}
	if _, _, err := h.run("", "scenario", "case", "add", "1", "--id", "tc1", "--name", "Dup", "--type", "ping"); client.ExitCodeFromError(err) != client.ExitConflict {
		t.Fatalf("expected ExitConflict for duplicate case id, got %v", err)
	}
	if _, _, err := h.run("", "scenario", "case", "remove", "1", "nonexistent", "--yes"); client.ExitCodeFromError(err) != client.ExitNotFound {
		t.Fatalf("expected ExitNotFound for missing case id, got %v", err)
	}
}
