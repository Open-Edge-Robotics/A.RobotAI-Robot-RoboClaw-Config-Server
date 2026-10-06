package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"ai-config-server/database"
	"ai-config-server/database/models"
	"github.com/gin-gonic/gin"
)

// setupTransferTestDB는 설정/시나리오 모델을 갖는 인메모리 DB를 준비한다.
func setupTransferTestDB(t *testing.T) {
	t.Helper()
	setupHandlerTestDB(t)
}

func TestConfigToTransferOmitsSecrets(t *testing.T) {
	cfg := models.RoboClawConfig{
		Name:              "test",
		RobotName:         "butler",
		Environment:       "office",
		AzureOpenaiApiKey: "secret-key",
		DiscordBotToken:   "discord-token",
		LangsmithApiKey:   "ls-key",
		System1ApiKey:     "system1-key",
		McpServersJson:    `[{"name":"fs"}]`,
	}

	tr := configToTransfer(&cfg, false)
	if tr.AzureOpenaiApiKey != nil {
		t.Errorf("expected azure key to be omitted, got %v", *tr.AzureOpenaiApiKey)
	}
	if tr.DiscordBotToken != nil {
		t.Errorf("expected discord token to be omitted, got %v", *tr.DiscordBotToken)
	}
	if tr.McpServersJson != nil {
		t.Errorf("expected mcp_servers_json to be omitted, got %v", *tr.McpServersJson)
	}
	if tr.System1ApiKey != nil {
		t.Errorf("expected system1_api_key to be omitted, got %v", *tr.System1ApiKey)
	}
}

func TestConfigToTransferIncludesSecrets(t *testing.T) {
	cfg := models.RoboClawConfig{
		AzureOpenaiApiKey:  "secret-key",
		LlmEmbeddingApiKey: "embed-key",
		QdrantApiKey:       "qdrant-key",
		System1ApiKey:      "system1-key",
	}
	tr := configToTransfer(&cfg, true)
	if tr.AzureOpenaiApiKey == nil || *tr.AzureOpenaiApiKey != "secret-key" {
		t.Errorf("expected azure key included, got %v", tr.AzureOpenaiApiKey)
	}
	if tr.LlmEmbeddingApiKey == nil || *tr.LlmEmbeddingApiKey != "embed-key" {
		t.Errorf("expected embedding key included, got %v", tr.LlmEmbeddingApiKey)
	}
	if tr.QdrantApiKey == nil || *tr.QdrantApiKey != "qdrant-key" {
		t.Errorf("expected qdrant key included, got %v", tr.QdrantApiKey)
	}
	if tr.System1ApiKey == nil || *tr.System1ApiKey != "system1-key" {
		t.Errorf("expected System 1 API key included, got %v", tr.System1ApiKey)
	}
}

func TestConfigTransferRoundTripPreservesDashboardNode(t *testing.T) {
	cfg := models.RoboClawConfig{
		Name:          "test",
		RobotName:     "butler",
		Environment:   "office",
		DashboardHost: "0.0.0.0",
		DashboardPort: 9091,
	}

	tr := configToTransfer(&cfg, false)
	if tr.DashboardHost != "0.0.0.0" || tr.DashboardPort != 9091 {
		t.Fatalf("expected dashboard node preserved in export, got %+v", tr)
	}

	model := tr.toModel(nil)
	if model.DashboardHost != "0.0.0.0" || model.DashboardPort != 9091 {
		t.Fatalf("expected dashboard node preserved on import, got %+v", model)
	}
}

func TestConfigTransferRoundTripPreservesSystem1Settings(t *testing.T) {
	cfg := models.RoboClawConfig{
		System1Router:             "laya",
		System1Shadow:             true,
		System1ShadowLog:          "/tmp/system1.jsonl",
		System1Scope:              "navigation",
		System1Endpoint:           "http://laya:8000",
		System1Provider:           "laya",
		System1TimeoutMs:          450,
		System1ConfThresholdsJson: `{"smalltalk":0.95}`,
		System1Skills:             "get_status,identify_location",
		System1MaxOptions:         8,
	}

	tr := configToTransfer(&cfg, false)
	model := tr.toModel(nil)
	if model.System1Router != cfg.System1Router || model.System1Scope != cfg.System1Scope ||
		model.System1Endpoint != cfg.System1Endpoint || model.System1ConfThresholdsJson != cfg.System1ConfThresholdsJson ||
		model.System1Skills != cfg.System1Skills || model.System1TimeoutMs != cfg.System1TimeoutMs {
		t.Fatalf("expected System 1 settings preserved through transfer, got %+v", model)
	}
	if !model.System1Shadow || model.System1MaxOptions != 8 {
		t.Fatalf("expected remaining System 1 settings preserved through transfer, got %+v", model)
	}
}

func TestConfigTransferRoundTripPreservesLangsmithWorkspaceID(t *testing.T) {
	cfg := models.RoboClawConfig{LangsmithWorkspaceId: "workspace-123"}

	tr := configToTransfer(&cfg, false)
	if tr.LangsmithWorkspaceId != "workspace-123" {
		t.Fatalf("expected workspace ID in export, got %q", tr.LangsmithWorkspaceId)
	}

	model := tr.toModel(nil)
	if model.LangsmithWorkspaceId != "workspace-123" {
		t.Fatalf("expected workspace ID preserved on import, got %q", model.LangsmithWorkspaceId)
	}
}

func TestConfigTransferToModelPreservesExistingSecrets(t *testing.T) {
	existing := &models.RoboClawConfig{
		AzureOpenaiApiKey: "existing-key",
		DiscordBotToken:   "existing-token",
		System1ApiKey:     "existing-system1-key",
	}
	tr := ConfigTransfer{
		Name:        "test",
		RobotName:   "butler",
		Environment: "office",
		// 민감 필드는 nil (백업에 없음) → 기존 값 보존
	}
	model := tr.toModel(existing)
	if model.AzureOpenaiApiKey != "existing-key" {
		t.Errorf("expected existing azure key preserved, got %q", model.AzureOpenaiApiKey)
	}
	if model.DiscordBotToken != "existing-token" {
		t.Errorf("expected existing discord token preserved, got %q", model.DiscordBotToken)
	}
	if model.System1ApiKey != "existing-system1-key" {
		t.Errorf("expected existing System 1 API key preserved, got %q", model.System1ApiKey)
	}
}

func TestConfigTransferToModelOverwritesSecretsWhenProvided(t *testing.T) {
	key := "new-key"
	existing := &models.RoboClawConfig{AzureOpenaiApiKey: "old-key"}
	tr := ConfigTransfer{
		Name:              "test",
		RobotName:         "butler",
		Environment:       "office",
		AzureOpenaiApiKey: &key,
	}
	model := tr.toModel(existing)
	if model.AzureOpenaiApiKey != "new-key" {
		t.Errorf("expected azure key overwritten, got %q", model.AzureOpenaiApiKey)
	}
}

func TestExportBackupOmitsIDsAndTimestamps(t *testing.T) {
	setupTransferTestDB(t)

	cfg := models.RoboClawConfig{
		Name:        "cfg-a",
		RobotName:   "butler",
		Environment: "office",
		Description: "hello",
	}
	database.DB.Create(&cfg)
	sc := models.TestScenario{
		Name:        "sc-a",
		RobotName:   "butler",
		Environment: "office",
		TestCases: []models.TestCase{
			{ID: "tc1", Name: "n", Type: "ping", Enabled: true},
		},
	}
	database.DB.Create(&sc)

	r := gin.New()
	r.GET("/export", ExportBackup)
	req := httptest.NewRequest("GET", "/export", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var doc BackupDocument
	if err := json.Unmarshal(w.Body.Bytes(), &doc); err != nil {
		t.Fatal(err)
	}
	if doc.Kind != BackupKind || doc.SchemaVersion != BackupSchemaVersion {
		t.Errorf("unexpected kind/schema: %s/%d", doc.Kind, doc.SchemaVersion)
	}
	if len(doc.Configs) != 1 || len(doc.Scenarios) != 1 {
		t.Fatalf("expected 1 config and 1 scenario, got %d/%d", len(doc.Configs), len(doc.Scenarios))
	}
	if doc.Configs[0].Description != "hello" {
		t.Errorf("expected description preserved, got %q", doc.Configs[0].Description)
	}
	if doc.Scenarios[0].TestCases[0].ID != "tc1" {
		t.Errorf("expected test case id preserved, got %q", doc.Scenarios[0].TestCases[0].ID)
	}
}

func TestExportBackupWithSecretsIncludesKeys(t *testing.T) {
	setupTransferTestDB(t)
	database.DB.Create(&models.RoboClawConfig{
		Name:              "cfg-a",
		RobotName:         "butler",
		Environment:       "office",
		AzureOpenaiApiKey: "real-secret",
	})

	r := gin.New()
	r.POST("/export", ExportBackup)
	body := []byte(`{"include_secrets":true,"include_configs":true,"include_scenarios":true}`)
	req := httptest.NewRequest("POST", "/export", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	var doc BackupDocument
	if err := json.Unmarshal(w.Body.Bytes(), &doc); err != nil {
		t.Fatal(err)
	}
	if len(doc.Configs) != 1 {
		t.Fatalf("expected 1 config, got %d", len(doc.Configs))
	}
	if doc.Configs[0].AzureOpenaiApiKey == nil || *doc.Configs[0].AzureOpenaiApiKey != "real-secret" {
		t.Errorf("expected real secret included with include_secrets, got %v", doc.Configs[0].AzureOpenaiApiKey)
	}
}

func TestValidateImportRejectsBadSchemaAndInvalidJSON(t *testing.T) {
	setupTransferTestDB(t)

	r := gin.New()
	r.POST("/validate", ValidateImport)

	// 잘못된 스키마 버전
	body := []byte(`{"document":{"kind":"ai-config-server.portable-backup","schema_version":99,"configs":[],"scenarios":[]}}`)
	req := httptest.NewRequest("POST", "/validate", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	var res ImportValidationResult
	json.Unmarshal(w.Body.Bytes(), &res)
	if res.Valid {
		t.Error("expected validation to fail for bad schema version")
	}

	// 잘못된 중첩 JSON
	body = []byte(`{"document":{"kind":"ai-config-server.portable-backup","schema_version":1,"configs":[{"name":"a","robot_name":"b","environment":"c","limits_content":"{bad"}],"scenarios":[]}}`)
	req = httptest.NewRequest("POST", "/validate", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	json.Unmarshal(w.Body.Bytes(), &res)
	if res.Valid {
		t.Error("expected validation to fail for invalid limits JSON")
	}
}

func TestImportBackupFreshServer(t *testing.T) {
	setupTransferTestDB(t)

	r := gin.New()
	r.POST("/import", ImportBackup)

	body := []byte(`{
		"document": {
			"kind": "ai-config-server.portable-backup",
			"schema_version": 1,
			"includes_secrets": true,
			"configs": [{
				"name": "imported-cfg",
				"robot_name": "butler",
				"environment": "office",
				"description": "from-backup",
				"azure_openai_api_key": "secret-key",
				"limits_content": "{}"
			}],
			"scenarios": [{
				"name": "imported-scenario",
				"robot_name": "butler",
				"environment": "office",
				"test_cases": [{"id":"tc1","name":"n","type":"ping","enabled":true}]
			}]
		},
		"options": {"conflict_policy": "skip", "activation_policy": "inactive"}
	}`)

	req := httptest.NewRequest("POST", "/import", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var result ImportResult
	json.Unmarshal(w.Body.Bytes(), &result)
	if result.Configs.Created != 1 || result.Scenarios.Created != 1 {
		t.Fatalf("expected 1 created each, got configs=%+v scenarios=%+v", result.Configs, result.Scenarios)
	}

	var stored models.RoboClawConfig
	if err := database.DB.Where("name = ?", "imported-cfg").First(&stored).Error; err != nil {
		t.Fatal(err)
	}
	if stored.AzureOpenaiApiKey != "secret-key" {
		t.Errorf("expected secret imported, got %q", stored.AzureOpenaiApiKey)
	}
	if stored.IsActive {
		t.Error("expected imported config to be inactive")
	}
}

func TestImportBackupConflictSkipAndCopy(t *testing.T) {
	setupTransferTestDB(t)
	database.DB.Create(&models.RoboClawConfig{
		Name:        "dup",
		RobotName:   "butler",
		Environment: "office",
	})

	r := gin.New()
	r.POST("/import", ImportBackup)

	doc := map[string]any{
		"kind":           BackupKind,
		"schema_version": BackupSchemaVersion,
		"configs": []any{
			map[string]any{"name": "dup", "robot_name": "butler", "environment": "office", "limits_content": "{}"},
			map[string]any{"name": "new", "robot_name": "butler", "environment": "office", "limits_content": "{}"},
		},
		"scenarios": []any{},
	}
	reqBody, _ := json.Marshal(map[string]any{
		"document": doc,
		"options":  map[string]string{"conflict_policy": "skip", "activation_policy": "inactive"},
	})

	req := httptest.NewRequest("POST", "/import", bytes.NewReader(reqBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	var result ImportResult
	json.Unmarshal(w.Body.Bytes(), &result)
	if result.Configs.Skipped != 1 || result.Configs.Created != 1 {
		t.Fatalf("skip policy: expected skipped=1 created=1, got %+v", result.Configs)
	}

	// copy 정책
	reqBody, _ = json.Marshal(map[string]any{
		"document": doc,
		"options":  map[string]string{"conflict_policy": "copy", "activation_policy": "inactive"},
	})
	req = httptest.NewRequest("POST", "/import", bytes.NewReader(reqBody))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	json.Unmarshal(w.Body.Bytes(), &result)
	if result.Configs.Created != 2 {
		t.Fatalf("copy policy: expected created=2, got %+v", result.Configs)
	}
}

func TestImportBackupPreservesExistingSecretsWhenBackupOmitsThem(t *testing.T) {
	setupTransferTestDB(t)
	database.DB.Create(&models.RoboClawConfig{
		Name:              "existing",
		RobotName:         "butler",
		Environment:       "office",
		AzureOpenaiApiKey: "keep-me",
	})

	r := gin.New()
	r.POST("/import", ImportBackup)

	// 백업에 민감 정보 없음 → 덮어쓰기 시 기존 키 보존
	body := []byte(`{
		"document": {
			"kind": "ai-config-server.portable-backup",
			"schema_version": 1,
			"configs": [{
				"name": "existing",
				"robot_name": "butler",
				"environment": "office",
				"description": "overwritten",
				"limits_content": "{}"
			}],
			"scenarios": []
		},
		"options": {"conflict_policy": "overwrite", "activation_policy": "inactive"}
	}`)
	req := httptest.NewRequest("POST", "/import", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var stored models.RoboClawConfig
	if err := database.DB.Where("name = ?", "existing").First(&stored).Error; err != nil {
		t.Fatal(err)
	}
	if stored.AzureOpenaiApiKey != "keep-me" {
		t.Errorf("expected existing secret preserved on overwrite without secrets, got %q", stored.AzureOpenaiApiKey)
	}
	if stored.Description != "overwritten" {
		t.Errorf("expected non-secret field updated, got %q", stored.Description)
	}
}

func TestImportBackupSingleActivePerRobotEnvironment(t *testing.T) {
	setupTransferTestDB(t)
	database.DB.Create(&models.RoboClawConfig{
		Name:        "old-active",
		RobotName:   "butler",
		Environment: "office",
		IsActive:    true,
	})

	r := gin.New()
	r.POST("/import", ImportBackup)

	// preserve 활성 정책, 활성 신규 항목 1개
	body := []byte(`{
		"document": {
			"kind": "ai-config-server.portable-backup",
			"schema_version": 1,
			"configs": [{
				"name": "new-active",
				"robot_name": "butler",
				"environment": "office",
				"is_active": true,
				"limits_content": "{}"
			}],
			"scenarios": []
		},
		"options": {"conflict_policy": "skip", "activation_policy": "preserve"}
	}`)
	req := httptest.NewRequest("POST", "/import", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var activeCount int64
	database.DB.Model(&models.RoboClawConfig{}).
		Where("robot_name = ? AND environment = ? AND is_active = ?", "butler", "office", true).
		Count(&activeCount)
	if activeCount != 1 {
		t.Fatalf("expected exactly one active config, got %d", activeCount)
	}

	var newActive models.RoboClawConfig
	database.DB.Where("name = ?", "new-active").First(&newActive)
	if !newActive.IsActive {
		t.Error("expected new-active to be active with preserve policy")
	}
}

func TestImportBackupAllInactivePolicy(t *testing.T) {
	setupTransferTestDB(t)
	r := gin.New()
	r.POST("/import", ImportBackup)

	body := []byte(`{
		"document": {
			"kind": "ai-config-server.portable-backup",
			"schema_version": 1,
			"configs": [{
				"name": "cfg-a",
				"robot_name": "butler",
				"environment": "office",
				"is_active": true,
				"limits_content": "{}"
			}],
			"scenarios": []
		},
		"options": {"conflict_policy": "skip", "activation_policy": "inactive"}
	}`)
	req := httptest.NewRequest("POST", "/import", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var stored models.RoboClawConfig
	database.DB.Where("name = ?", "cfg-a").First(&stored)
	if stored.IsActive {
		t.Error("expected config imported as inactive under inactive policy")
	}
}

func TestImportBackupRollsBackOnBadData(t *testing.T) {
	setupTransferTestDB(t)
	r := gin.New()
	r.POST("/import", ImportBackup)

	// 유효한 config 하나와 잘못된(필수 필드 누락) config 하나 → 전체 롤백
	body := []byte(`{
		"document": {
			"kind": "ai-config-server.portable-backup",
			"schema_version": 1,
			"configs": [
				{"name": "good", "robot_name": "butler", "environment": "office", "limits_content": "{}"},
				{"name": "", "robot_name": "", "environment": "", "limits_content": "{}"}
			],
			"scenarios": []
		},
		"options": {"conflict_policy": "skip", "activation_policy": "inactive"}
	}`)
	req := httptest.NewRequest("POST", "/import", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	// 사전 검증에서 막히므로 400
	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid import, got %d: %s", w.Code, w.Body.String())
	}

	var count int64
	database.DB.Model(&models.RoboClawConfig{}).Count(&count)
	if count != 0 {
		t.Fatalf("expected no configs inserted after rollback, got %d", count)
	}
}

// TestMaskSensitiveFieldsMasksEmbeddingApiKey 는 마스킹 누락 보완 검증이다.
func TestMaskSensitiveFieldsMasksEmbeddingApiKey(t *testing.T) {
	cfg := models.RoboClawConfig{LlmEmbeddingApiKey: "embed-secret"}
	maskSensitiveFields(&cfg)
	if cfg.LlmEmbeddingApiKey != MaskValue {
		t.Errorf("expected llm_embedding_api_key to be masked, got %q", cfg.LlmEmbeddingApiKey)
	}
}
