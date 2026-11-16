package profile

import (
	"encoding/json"
	"errors"
	"testing"
	"time"

	"gorm.io/gorm"

	"ai-config-server/database/models"
)

// patchOf 는 JSON 본문을 수정 payload map 으로 변환한다.
func patchOf(t *testing.T, body string) map[string]json.RawMessage {
	t.Helper()
	var patch map[string]json.RawMessage
	if err := json.Unmarshal([]byte(body), &patch); err != nil {
		t.Fatalf("invalid patch JSON %q: %v", body, err)
	}
	return patch
}

// TestMergePreservesProtectedFields 는 ID/타임스탬프/활성 상태를 payload 로
// 변경할 수 없는지 검증한다.
func TestMergePreservesProtectedFields(t *testing.T) {
	created := time.Date(2024, 1, 2, 3, 4, 5, 0, time.UTC)
	current := models.RoboClawConfig{
		Model:    gorm.Model{ID: 7, CreatedAt: created, UpdatedAt: created.Add(time.Hour)},
		Name:     "old",
		IsActive: true,
	}

	merged, err := Merge(current, patchOf(t, `{
		"id": 99,
		"is_active": false,
		"created_at": "2000-01-01T00:00:00Z",
		"updated_at": "2000-01-01T00:00:00Z",
		"name": "new"
	}`), 7)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if merged.ID != 7 {
		t.Errorf("expected ID 7, got %d", merged.ID)
	}
	if !merged.IsActive {
		t.Error("expected is_active to be preserved from the stored record")
	}
	if !merged.CreatedAt.Equal(created) || !merged.UpdatedAt.Equal(created.Add(time.Hour)) {
		t.Errorf("expected timestamps preserved, got created=%v updated=%v", merged.CreatedAt, merged.UpdatedAt)
	}
	if merged.DeletedAt.Valid {
		t.Errorf("expected deleted_at to stay empty, got %v", merged.DeletedAt)
	}
	if merged.Name != "new" {
		t.Errorf("expected patched name, got %q", merged.Name)
	}
}

// TestMergePinsRequestedID 는 경로 ID 가 모델 ID 를 결정하는지 검증한다.
func TestMergePinsRequestedID(t *testing.T) {
	current := models.RoboClawConfig{Model: gorm.Model{ID: 3}}
	merged, err := Merge(current, patchOf(t, `{"name":"x"}`), 3)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if merged.ID != 3 {
		t.Errorf("expected ID 3, got %d", merged.ID)
	}
}

// TestMergeKeepsUnmentionedFields 는 payload 에 없는 필드가 기존 값을 유지하는지 검증한다.
func TestMergeKeepsUnmentionedFields(t *testing.T) {
	current := models.RoboClawConfig{
		Name:        "old",
		RobotName:   "former",
		Environment: "office",
		LlmModel:    "gpt-4o",
		HttpPort:    8080,
	}

	merged, err := Merge(current, patchOf(t, `{"name":"renamed"}`), 1)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if merged.LlmModel != "gpt-4o" || merged.HttpPort != 8080 || merged.RobotName != "former" {
		t.Errorf("expected unmentioned fields preserved, got %+v", merged)
	}
	if merged.Name != "renamed" {
		t.Errorf("expected patched name, got %q", merged.Name)
	}
}

// TestMergeRestoresMaskedSecrets 는 마스킹된 자격 증명이 기존 값으로 복원되는지 검증한다.
func TestMergeRestoresMaskedSecrets(t *testing.T) {
	current := models.RoboClawConfig{}
	for _, field := range secretFields {
		field.set(&current, secretSample(field))
	}

	patchBody := `{"name":"c","openai_api_key":"` + MaskValue + `","mcp_servers_json":"` + MaskValue + `"}`
	merged, err := Merge(current, patchOf(t, patchBody), 1)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if merged.OpenaiApiKey != current.OpenaiApiKey {
		t.Errorf("expected openai key preserved, got %q", merged.OpenaiApiKey)
	}
	if merged.McpServersJson != current.McpServersJson {
		t.Errorf("expected MCP servers preserved, got %q", merged.McpServersJson)
	}
	if merged.AnthropicApiKey != current.AnthropicApiKey {
		t.Errorf("expected unmentioned anthropic key preserved, got %q", merged.AnthropicApiKey)
	}
}

// TestMergeReplacesSecretWhenClientSendsValue 는 실제 값이 오면 저장 값을 교체하는지 검증한다.
func TestMergeReplacesSecretWhenClientSendsValue(t *testing.T) {
	current := models.RoboClawConfig{OpenaiApiKey: "old-secret"}
	merged, err := Merge(current, patchOf(t, `{"openai_api_key":"new-secret"}`), 1)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if merged.OpenaiApiKey != "new-secret" {
		t.Errorf("expected new secret, got %q", merged.OpenaiApiKey)
	}
}

// TestMergeAppliesButlerPathDefaults 는 병합 결과에 배포 기본 경로가 적용되는지 검증한다.
func TestMergeAppliesButlerPathDefaults(t *testing.T) {
	current := models.RoboClawConfig{RobotName: "butler"}
	merged, err := Merge(current, patchOf(t, `{"name":"c"}`), 1)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if merged.ButlerScriptsDir == "" || merged.ButlerSourceDir == "" {
		t.Errorf("expected butler path defaults, got %+v", merged)
	}
}

// TestMergeRejectsPatchFieldTypeError 는 필드 형식 오류를 400 단계로 구분하는지 검증한다.
func TestMergeRejectsPatchFieldTypeError(t *testing.T) {
	current := models.RoboClawConfig{HttpPort: 8080}
	_, err := Merge(current, patchOf(t, `{"http_port":"not-a-number"}`), 1)
	if err == nil {
		t.Fatal("expected error for wrong field type")
	}
	if !errors.Is(err, ErrPatchFieldType) {
		t.Errorf("expected ErrPatchFieldType, got %v", err)
	}
	if errors.Is(err, ErrMergeBase) || errors.Is(err, ErrMergePatch) {
		t.Errorf("expected only the field type stage, got %v", err)
	}
	// handler 로그/응답 문구가 바뀌지 않도록 원인 오류 문구를 그대로 노출한다.
	if got := err.Error(); got == "" || got == ErrPatchFieldType.Error() {
		t.Errorf("expected wrapped cause message, got %q", got)
	}
}

// TestMergeIgnoresUnknownFields 는 모델에 없는 필드를 무시하는지 검증한다.
func TestMergeIgnoresUnknownFields(t *testing.T) {
	current := models.RoboClawConfig{Name: "old"}
	merged, err := Merge(current, patchOf(t, `{"unknown_field":1,"name":"new"}`), 1)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if merged.Name != "new" {
		t.Errorf("expected patched name, got %q", merged.Name)
	}
}
