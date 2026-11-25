package client_test

import (
	"context"
	"encoding/json"
	"errors"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"ai-config-server/handler"
	"ai-config-server/internal/client"
	"ai-config-server/testutil"
)

func setupTestServer(t *testing.T) (*client.Client, *client.Client) {
	t.Helper()
	cfg := testutil.NewTestConfig()
	cfg.Security.AdminToken = "test-admin-token"
	cfg.Security.DeviceToken = "test-device-token"
	cfg.Security.RequireAuth = true

	db := testutil.NewTestDB(t)
	router := handler.NewRouter(cfg, db)
	srv := httptest.NewServer(router)
	t.Cleanup(srv.Close)

	adminCli := client.New(srv.URL, "test-admin-token", 5*time.Second)
	deviceCli := client.New(srv.URL, "test-device-token", 5*time.Second)
	return adminCli, deviceCli
}

func TestClientHealthAndAuthErrors(t *testing.T) {
	adminCli, _ := setupTestServer(t)
	ctx := context.Background()

	ping, err := adminCli.Ping(ctx)
	if err != nil || ping["message"] != "pong" {
		t.Fatalf("Ping failed: %+v %v", ping, err)
	}
	ready, err := adminCli.Ready(ctx)
	if err != nil || ready["ready"] != true {
		t.Fatalf("Ready failed: %+v %v", ready, err)
	}

	unauth := client.New(adminCli.BaseURL, "wrong-token", 5*time.Second)
	_, err = unauth.ListConfigs(ctx, "", "")
	if err == nil {
		t.Fatal("expected 401 error")
	}
	if code := client.ExitCodeFromError(err); code != client.ExitAuth {
		t.Errorf("expected ExitAuth (%d), got %d (%v)", client.ExitAuth, code, err)
	}

	_, err = adminCli.GetConfig(ctx, 99999)
	if code := client.ExitCodeFromError(err); code != client.ExitNotFound {
		t.Errorf("expected ExitNotFound (%d), got %d (%v)", client.ExitNotFound, code, err)
	}
}

func TestClientConfigAndDeviceLifecycle(t *testing.T) {
	adminCli, deviceCli := setupTestServer(t)
	ctx := context.Background()

	created, err := adminCli.CreateConfig(ctx, map[string]any{
		"name":           "Butler_CLI_Test",
		"robot_name":     "butler",
		"environment":    "office",
		"llm_provider":   "openai",
		"llm_model":      "gpt-4.1",
		"openai_api_key": "sk-live-secret",
		"soul_content":   "# Butler Soul\n",
	})
	if err != nil {
		t.Fatalf("CreateConfig failed: %v", err)
	}
	id := created.ID()
	if id <= 0 || created.Name() != "Butler_CLI_Test" {
		t.Fatalf("unexpected created config: %+v", created)
	}

	list, err := adminCli.ListConfigs(ctx, "butler", "office")
	if err != nil || len(list) == 0 {
		t.Fatalf("ListConfigs failed: len=%d err=%v", len(list), err)
	}

	patched, err := adminCli.PatchConfig(ctx, id, map[string]any{
		"llm_model": "gpt-4o-mini",
	})
	if err != nil {
		t.Fatalf("PatchConfig failed: %v", err)
	}
	if patched.StringField("llm_model") != "gpt-4o-mini" {
		t.Errorf("expected patched llm_model, got %q", patched.StringField("llm_model"))
	}

	// Activate and verify device APIs
	if _, err := adminCli.ActivateConfig(ctx, id); err != nil {
		t.Fatalf("ActivateConfig failed: %v", err)
	}

	active, err := deviceCli.GetActiveConfig(ctx, "butler", "office")
	if err != nil || active.ID() != id || !active.IsActive() {
		t.Fatalf("GetActiveConfig failed: %+v err=%v", active, err)
	}
	devList, err := deviceCli.ListDeviceConfigs(ctx, "butler", "office")
	if err != nil || len(devList) == 0 {
		t.Fatalf("ListDeviceConfigs failed: %v", err)
	}
	v2, err := deviceCli.GetActiveRuntimeConfigV2(ctx, "butler", "office")
	if err != nil || len(v2) == 0 {
		t.Fatalf("GetActiveRuntimeConfigV2 failed: %v", err)
	}

	// File downloads (admin & device)
	envBytes, err := adminCli.GetConfigFile(ctx, id, ".env")
	if err != nil || !strings.Contains(string(envBytes), "gpt-4o-mini") {
		t.Fatalf("GetConfigFile(.env) failed: %q err=%v", string(envBytes), err)
	}
	soulBytes, err := deviceCli.GetActiveConfigFile(ctx, "butler", "office", "ROBOT.md")
	if err != nil || !strings.Contains(string(soulBytes), "Butler Soul") {
		t.Fatalf("GetActiveConfigFile(ROBOT.md) failed: %q err=%v", string(soulBytes), err)
	}

	// Clone & delete
	cloned, err := adminCli.CloneConfig(ctx, id)
	if err != nil || cloned.ID() == id {
		t.Fatalf("CloneConfig failed: %+v err=%v", cloned, err)
	}
	if _, err := adminCli.DeleteConfig(ctx, cloned.ID()); err != nil {
		t.Fatalf("DeleteConfig failed: %v", err)
	}
}

func TestClientScenarioTransferAndMcp(t *testing.T) {
	adminCli, deviceCli := setupTestServer(t)
	ctx := context.Background()

	sc, err := adminCli.CreateScenario(ctx, map[string]any{
		"name":        "CLI_Scenario",
		"description": "initial",
		"robot_name":  "butler",
		"environment": "office",
		"test_cases": []client.TestCase{
			{ID: "tc1", Name: "Ping", Type: "ping", TimeoutMs: 1000, Enabled: true},
		},
	})
	if err != nil || sc.ID == 0 {
		t.Fatalf("CreateScenario failed: %+v err=%v", sc, err)
	}

	patched, err := adminCli.PatchScenario(ctx, int(sc.ID), map[string]any{
		"description": "patched",
	})
	if err != nil || patched.Description != "patched" || len(patched.TestCases) != 1 {
		t.Fatalf("PatchScenario failed: %+v err=%v", patched, err)
	}

	updated, err := adminCli.UpdateScenario(ctx, int(sc.ID), map[string]any{
		"name":        "CLI_Scenario_Updated",
		"description": "updated",
		"robot_name":  "butler",
		"environment": "office",
		"test_cases":  patched.TestCases,
	})
	if err != nil || updated.Name != "CLI_Scenario_Updated" {
		t.Fatalf("UpdateScenario failed: %+v err=%v", updated, err)
	}

	if _, err := adminCli.ActivateScenario(ctx, int(sc.ID)); err != nil {
		t.Fatalf("ActivateScenario failed: %v", err)
	}
	activeSc, err := deviceCli.GetActiveScenario(ctx, "butler", "office")
	if err != nil || activeSc.ID != sc.ID {
		t.Fatalf("GetActiveScenario failed: %+v err=%v", activeSc, err)
	}
	listSc, err := adminCli.ListScenarios(ctx, "butler", "office")
	if err != nil || len(listSc) == 0 {
		t.Fatalf("ListScenarios failed: %v", err)
	}
	gotSc, err := adminCli.GetScenario(ctx, int(sc.ID))
	if err != nil || gotSc.ID != sc.ID {
		t.Fatalf("GetScenario failed: %v", err)
	}
	clonedSc, err := adminCli.CloneScenario(ctx, int(sc.ID))
	if err != nil || clonedSc.ID == sc.ID {
		t.Fatalf("CloneScenario failed: %v", err)
	}
	if _, err := adminCli.DeleteScenario(ctx, int(clonedSc.ID)); err != nil {
		t.Fatalf("DeleteScenario failed: %v", err)
	}

	// Transfer export -> validate -> import
	exported, err := adminCli.ExportBackup(ctx, client.ExportRequest{
		IncludeConfigs:   true,
		IncludeScenarios: true,
	})
	if err != nil || !json.Valid(exported) {
		t.Fatalf("ExportBackup failed: err=%v", err)
	}
	req := client.ImportRequest{
		Document: exported,
		Options: client.ImportOptions{
			ConflictPolicy:   "skip",
			ActivationPolicy: "keep_existing",
		},
	}
	valRes, err := adminCli.ValidateImport(ctx, req)
	if err != nil || valRes["valid"] != true {
		t.Fatalf("ValidateImport failed: %+v err=%v", valRes, err)
	}
	impRes, err := adminCli.ImportBackup(ctx, req)
	if err != nil || impRes["scenarios"] == nil {
		t.Fatalf("ImportBackup failed: %+v err=%v", impRes, err)
	}

	// MCP catalog
	cat, err := adminCli.ListMcpCatalog(ctx, "")
	if err != nil || len(cat.Servers) == 0 {
		t.Fatalf("ListMcpCatalog failed: %+v err=%v", cat, err)
	}

	// ExitCodeFromError helper coverage
	if client.ExitCodeFromError(nil) != client.ExitOK {
		t.Error("nil error should map to ExitOK")
	}
	ce := &client.CodeError{Code: client.ExitUsage, Err: errors.New("bad input")}
	if client.ExitCodeFromError(ce) != client.ExitUsage {
		t.Error("CodeError should preserve exit code")
	}
}
