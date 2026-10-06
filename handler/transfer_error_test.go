package handler

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"ai-config-server/testutil"

	"github.com/gin-gonic/gin"
)

// TestValidateImportMalformedBody 는 잘못된 JSON 요청 시 400 을 검증한다.
func TestValidateImportMalformedBody(t *testing.T) {
	setupRouterTestDB(t)
	r := gin.New()
	r.POST("/validate", ValidateImport)

	req := httptest.NewRequest("POST", "/validate", bytes.NewReader([]byte("{bad json")))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != 400 {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

// TestImportBackupInvalidConflictPolicy 는 잘못된 충돌 정책 시 400 을 검증한다.
func TestImportBackupInvalidConflictPolicy(t *testing.T) {
	setupRouterTestDB(t)
	r := gin.New()
	r.POST("/import", ImportBackup)

	body := map[string]any{
		"document": map[string]any{
			"kind": BackupKind, "schema_version": BackupSchemaVersion,
			"configs": []any{}, "scenarios": []any{},
		},
		"options": map[string]string{"conflict_policy": "bogus", "activation_policy": "inactive"},
	}
	w := testutil.PerformJSON(r, "POST", "/import", "", body)
	if w.Code != 400 {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

// TestImportBackupInvalidActivationPolicy 는 잘못된 활성 정책 시 400 을 검증한다.
func TestImportBackupInvalidActivationPolicy(t *testing.T) {
	setupRouterTestDB(t)
	r := gin.New()
	r.POST("/import", ImportBackup)

	body := map[string]any{
		"document": map[string]any{
			"kind": BackupKind, "schema_version": BackupSchemaVersion,
			"configs": []any{}, "scenarios": []any{},
		},
		"options": map[string]string{"conflict_policy": "skip", "activation_policy": "bogus"},
	}
	w := testutil.PerformJSON(r, "POST", "/import", "", body)
	if w.Code != 400 {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

// TestExportBackupMalformedBody 는 잘못된 내보내기 요청 시 400 을 검증한다.
func TestExportBackupMalformedBody(t *testing.T) {
	setupRouterTestDB(t)
	r := gin.New()
	r.POST("/export", ExportBackup)

	req := httptest.NewRequest("POST", "/export", bytes.NewReader([]byte("{bad")))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}
