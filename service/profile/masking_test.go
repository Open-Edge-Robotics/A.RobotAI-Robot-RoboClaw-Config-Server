package profile

import (
	"encoding/json"
	"reflect"
	"regexp"
	"strings"
	"testing"

	"ai-config-server/database/models"
)

// secretSample 은 표 항목별로 서로 다른 실제 자격 증명 예시를 만든다.
func secretSample(field secretField) string {
	if field.kind == secretMCPServersJSON {
		return `[{"name":"fs","transport":"stdio","command":"npx","env":{"GITHUB_TOKEN":"ghp-secret"}}]`
	}
	return "real-" + field.name
}

// sameJSON 은 두 JSON 문자열이 공백/키 순서 차이만 있는지 비교한다.
func sameJSON(t *testing.T, got, want string) bool {
	t.Helper()
	var gotValue, wantValue any
	if err := json.Unmarshal([]byte(got), &gotValue); err != nil {
		t.Fatalf("expected valid JSON, got %q: %v", got, err)
	}
	if err := json.Unmarshal([]byte(want), &wantValue); err != nil {
		t.Fatalf("expected valid JSON, got %q: %v", want, err)
	}
	return reflect.DeepEqual(gotValue, wantValue)
}

// sameFieldValue 는 표 항목 하나의 두 설정 값이 같은지 비교한다.
func sameFieldValue(t *testing.T, field secretField, a, b *models.RoboClawConfig) bool {
	t.Helper()
	if field.kind == secretMCPServersJSON {
		return sameJSON(t, field.get(a), field.get(b))
	}
	return field.get(a) == field.get(b)
}

// TestMaskMasksEverySecretField 는 표의 모든 항목이 마스킹되는지 검증한다.
func TestMaskMasksEverySecretField(t *testing.T) {
	for _, field := range secretFields {
		cfg := models.RoboClawConfig{}
		field.set(&cfg, secretSample(field))
		Mask(&cfg)

		if field.kind == secretMCPServersJSON {
			// MCP 서버는 구조를 유지하고 env/headers 값만 가린다.
			if got := field.get(&cfg); !strings.Contains(got, MaskValue) || strings.Contains(got, "ghp-secret") {
				t.Errorf("%s: expected credentials masked with structure kept, got %q", field.name, got)
			}
			continue
		}
		if got := field.get(&cfg); got != MaskValue {
			t.Errorf("%s: expected %q, got %q", field.name, MaskValue, got)
		}
	}
}

// TestMaskLeavesEmptySecretsUntouched 는 비어 있는 값은 그대로 두는지 검증한다.
func TestMaskLeavesEmptySecretsUntouched(t *testing.T) {
	cfg := models.RoboClawConfig{McpServersJson: "[]"}
	Mask(&cfg)
	if cfg.McpServersJson != "[]" {
		t.Errorf("expected empty MCP list to stay '[]', got %q", cfg.McpServersJson)
	}
	for _, field := range secretFields {
		if field.kind == secretMCPServersJSON {
			continue
		}
		if got := field.get(&cfg); got != "" {
			t.Errorf("%s: expected empty value to stay empty, got %q", field.name, got)
		}
	}
}

// TestRestoreSecretsRestoresEveryMaskedField 는 표의 모든 항목이 복원되는지 검증한다.
func TestRestoreSecretsRestoresEveryMaskedField(t *testing.T) {
	stored := models.RoboClawConfig{}
	for _, field := range secretFields {
		field.set(&stored, secretSample(field))
	}

	incoming := stored
	Mask(&incoming)
	restoreSecrets(&incoming, &stored)

	for _, field := range secretFields {
		if !sameFieldValue(t, field, &incoming, &stored) {
			t.Errorf("%s: expected restored %q, got %q", field.name, field.get(&stored), field.get(&incoming))
		}
	}
}

// TestMaskAndRestoreUseSameFieldSet 은 마스킹 필드 집합과 복원 필드 집합이
// 같은 표에서 나오는지 검증한다. 두 목록이 갈라지면 마스킹된 자격 증명이
// 실제 값 대신 "********" 로 저장된다.
func TestMaskAndRestoreUseSameFieldSet(t *testing.T) {
	stored := models.RoboClawConfig{}
	for _, field := range secretFields {
		field.set(&stored, secretSample(field))
	}

	masked := stored
	Mask(&masked)

	var maskSet []string
	for _, field := range secretFields {
		if !sameFieldValue(t, field, &masked, &stored) {
			maskSet = append(maskSet, field.name)
		}
	}

	restored := masked
	restoreSecrets(&restored, &stored)

	var restoreSet []string
	for _, field := range secretFields {
		if sameFieldValue(t, field, &restored, &stored) {
			restoreSet = append(restoreSet, field.name)
		}
	}

	if len(maskSet) != len(secretFields) {
		t.Errorf("expected %d masked fields, got %v", len(secretFields), maskSet)
	}
	if !reflect.DeepEqual(maskSet, restoreSet) {
		t.Errorf("masked fields and restored fields differ: masked=%v restored=%v", maskSet, restoreSet)
	}
}

// credentialFieldSuffix 는 모델에서 자격 증명으로 다루는 필드 이름 규칙이다.
var credentialFieldSuffix = regexp.MustCompile(`(_api_key|_token)$`)

// TestSecretFieldTableMatchesModel 은 모델에 자격 증명 필드를 추가하고 표를
// 갱신하지 않는 회귀를 막는다.
func TestSecretFieldTableMatchesModel(t *testing.T) {
	table := make(map[string]bool, len(secretFields))
	for _, field := range secretFields {
		if table[field.name] {
			t.Errorf("duplicate secret field in table: %s", field.name)
		}
		table[field.name] = true
	}

	typ := reflect.TypeOf(models.RoboClawConfig{})
	known := make(map[string]bool, typ.NumField())
	for i := 0; i < typ.NumField(); i++ {
		structField := typ.Field(i)
		name := strings.Split(structField.Tag.Get("json"), ",")[0]
		known[name] = true
		if structField.Type.Kind() != reflect.String {
			continue
		}
		if !credentialFieldSuffix.MatchString(name) {
			continue
		}
		if !table[name] {
			t.Errorf("model credential field %s is missing from the secret field table", name)
		}
	}

	for _, field := range secretFields {
		if !known[field.name] {
			t.Errorf("secret field table entry %s does not exist in models.RoboClawConfig", field.name)
		}
	}
}

// TestMaskMCPServersJSONKeepsStructure 는 MCP 서버 구조는 노출하고
// 자격 증명(env/headers)만 마스킹하는지 검증한다.
func TestMaskMCPServersJSONKeepsStructure(t *testing.T) {
	raw := `[
		{"name":"fs","transport":"stdio","command":"npx","args":["-y","server-fs"],"cwd":"/data",
		 "env":{"GITHUB_TOKEN":"ghp-secret","LOG_LEVEL":"debug"}},
		{"name":"remote","transport":"sse","url":"https://mcp.example.com/sse",
		 "headers":{"Authorization":"Bearer secret","X-Trace":"on"}}
	]`

	var servers []map[string]any
	if err := json.Unmarshal([]byte(MaskMCPServersJSON(raw)), &servers); err != nil {
		t.Fatalf("expected valid masked JSON: %v", err)
	}
	if len(servers) != 2 {
		t.Fatalf("expected 2 visible servers, got %d", len(servers))
	}
	if servers[0]["name"] != "fs" || servers[0]["command"] != "npx" || servers[1]["url"] != "https://mcp.example.com/sse" {
		t.Errorf("expected server structure to stay visible, got %v", servers)
	}

	stdioEnv := servers[0]["env"].(map[string]any)
	for key, value := range stdioEnv {
		if value != MaskValue {
			t.Errorf("expected env value %s masked, got %v", key, value)
		}
	}
	remoteHeaders := servers[1]["headers"].(map[string]any)
	for key, value := range remoteHeaders {
		if value != MaskValue {
			t.Errorf("expected header %s masked, got %v", key, value)
		}
	}
}

// TestMaskMCPServersJSONWholeFallback 는 파싱할 수 없는 JSON 을 전체 마스킹하는지 검증한다.
func TestMaskMCPServersJSONWholeFallback(t *testing.T) {
	for _, raw := range []string{`{bad json`, `{"name":"fs"}`, `"text"`} {
		if got := MaskMCPServersJSON(raw); got != MaskValue {
			t.Errorf("expected %q to be fully masked, got %q", raw, got)
		}
	}
	for _, raw := range []string{"", "[]"} {
		if got := MaskMCPServersJSON(raw); got != raw {
			t.Errorf("expected %q to stay unchanged, got %q", raw, got)
		}
	}
}

// TestMergeMaskedMCPServersJSONRestoresByName 는 이름이 같은 서버의 자격 증명을 복원하는지 검증한다.
func TestMergeMaskedMCPServersJSONRestoresByName(t *testing.T) {
	existing := `[{"name":"fs","command":"npx","env":{"GITHUB_TOKEN":"ghp-secret","LOG_LEVEL":"debug"}}]`
	incoming := MaskMCPServersJSON(existing)

	merged := MergeMaskedMCPServersJSON(existing, incoming)
	if strings.Contains(merged, MaskValue) {
		t.Errorf("expected masked credentials to be restored, got %q", merged)
	}
	if !sameJSON(t, merged, existing) {
		t.Errorf("expected %q, got %q", existing, merged)
	}
}

// TestMergeMaskedMCPServersJSONDropsUnmatchedMasks 는 대응하는 저장 값이 없는
// 마스킹 값이 실제 자격 증명으로 저장되지 않게 제거하는지 검증한다.
func TestMergeMaskedMCPServersJSONDropsUnmatchedMasks(t *testing.T) {
	incoming := `[{"name":"new","command":"npx","env":{"NEW_TOKEN":"********"}}]`
	merged := MergeMaskedMCPServersJSON(`[]`, incoming)
	if strings.Contains(merged, MaskValue) {
		t.Errorf("expected unmatched masked value to be removed, got %q", merged)
	}
}

// TestMergeMaskedMCPServersJSONPassesThroughUnmasked 는 마스킹 값이 없는 요청을
// 그대로 통과시키는지 검증한다.
func TestMergeMaskedMCPServersJSONPassesThroughUnmasked(t *testing.T) {
	incoming := `[{"name":"fs","env":{"GITHUB_TOKEN":"new"}}]`
	if got := MergeMaskedMCPServersJSON(`[]`, incoming); got != incoming {
		t.Errorf("expected %q unchanged, got %q", incoming, got)
	}
}
