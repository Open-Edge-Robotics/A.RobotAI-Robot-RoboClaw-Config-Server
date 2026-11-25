package clioutput

import (
	"bytes"
	"strings"
	"testing"
)

func TestWriteJSONAndTable(t *testing.T) {
	var buf bytes.Buffer
	if err := WriteJSON(&buf, map[string]any{"ok": true, "id": 1}); err != nil {
		t.Fatalf("WriteJSON failed: %v", err)
	}
	if !strings.Contains(buf.String(), `"ok": true`) {
		t.Errorf("unexpected JSON output: %s", buf.String())
	}

	buf.Reset()
	if err := WriteTable(&buf, []string{"ID", "NAME"}, [][]string{{"1", "butler"}}); err != nil {
		t.Fatalf("WriteTable failed: %v", err)
	}
	if !strings.Contains(buf.String(), "ID") || !strings.Contains(buf.String(), "butler") {
		t.Errorf("unexpected table output: %s", buf.String())
	}
}

func TestMaskEnvContent(t *testing.T) {
	raw := strings.Join([]string{
		"# comment",
		"ROS_DOMAIN_ID=42",
		"OPENAI_API_KEY=sk-secret-123",
		"CUSTOM_SECRET_VAR=hidden",
		"RC_MCP_SERVERS_JSON=[{\"env\":{\"TOKEN\":\"abc\"}}]",
		"EMPTY_TOKEN=",
	}, "\n")

	masked := MaskEnvContent(raw, map[string]bool{"CUSTOM_SECRET_VAR": true})
	if !strings.Contains(masked, "ROS_DOMAIN_ID=42") {
		t.Errorf("non-secret key should remain intact: %s", masked)
	}
	if strings.Contains(masked, "sk-secret-123") || strings.Contains(masked, "hidden") || strings.Contains(masked, "abc") {
		t.Errorf("secret values leaked in masked output: %s", masked)
	}
	if !strings.Contains(masked, "OPENAI_API_KEY="+MaskValue) {
		t.Errorf("expected OPENAI_API_KEY masked: %s", masked)
	}
	if !strings.Contains(masked, "EMPTY_TOKEN=") {
		t.Errorf("empty secret should remain empty: %s", masked)
	}
}

func TestDiffMaps(t *testing.T) {
	before := map[string]any{"a": 1, "b": "old", "c": true}
	after := map[string]any{"a": 1, "b": "new", "d": "added"}
	diffs := DiffMaps(before, after)
	if len(diffs) != 3 {
		t.Fatalf("expected 3 diffs, got %+v", diffs)
	}
	if diffs[0].Field != "b" || diffs[1].Field != "c" || diffs[2].Field != "d" {
		t.Errorf("unexpected sorted diff order: %+v", diffs)
	}
}

func TestParseSetExpr(t *testing.T) {
	types := map[string]string{
		"ros_domain_id":    "integer",
		"llm_tool_calling": "boolean",
		"rag_threshold":    "number",
		"llm_model":        "string",
	}

	k, v, err := ParseSetExpr("ros_domain_id=42", types)
	if err != nil || k != "ros_domain_id" || v != int64(42) {
		t.Fatalf("unexpected integer parse: %q %v %v", k, v, err)
	}
	k, v, err = ParseSetExpr("llm_tool_calling=false", types)
	if err != nil || k != "llm_tool_calling" || v != false {
		t.Fatalf("unexpected bool parse: %q %v %v", k, v, err)
	}
	k, v, err = ParseSetExpr("rag_threshold=0.75", types)
	if err != nil || k != "rag_threshold" || v != 0.75 {
		t.Fatalf("unexpected float parse: %q %v %v", k, v, err)
	}
	k, v, err = ParseSetExpr("llm_model=42", types)
	if err != nil || k != "llm_model" || v != "42" {
		t.Fatalf("string schema hint should preserve numeric text: %q %#v %v", k, v, err)
	}
	if _, _, err := ParseSetExpr("ros_domain_id=abc", types); err == nil {
		t.Fatal("expected error for non-integer value")
	}
	if _, _, err := ParseSetExpr("missing_equals", types); err == nil {
		t.Fatal("expected error for missing '='")
	}
}

func TestLoadContractSchema(t *testing.T) {
	schema, err := LoadContractSchema()
	if err != nil {
		t.Fatalf("LoadContractSchema failed: %v", err)
	}
	if len(schema.Fields) == 0 {
		t.Fatal("expected embedded contract fields")
	}
	secrets := schema.SecretEnvKeys()
	if len(secrets) == 0 {
		t.Fatal("expected secret env keys in embedded contract")
	}
	filtered := schema.FilterFields("llm_model", "", false)
	if len(filtered) == 0 {
		t.Fatal("expected llm_model match in contract fields")
	}
	secretFiltered := schema.FilterFields("", "", true)
	if len(secretFiltered) == 0 {
		t.Fatal("expected secret fields when secretsOnly=true")
	}
	ft := schema.FieldTypes()
	if ft["llm_model"] != "string" || ft["ros_domain_id"] != "integer" {
		t.Fatalf("unexpected field types: llm_model=%q ros_domain_id=%q", ft["llm_model"], ft["ros_domain_id"])
	}
}

func TestParseSetExprInferenceAndErrors(t *testing.T) {
	if _, v, err := ParseSetExpr("flag=true", nil); err != nil || v != true {
		t.Fatalf("inferred bool failed: %v %v", v, err)
	}
	if _, v, err := ParseSetExpr("flag=false", nil); err != nil || v != false {
		t.Fatalf("inferred false failed: %v %v", v, err)
	}
	if _, v, err := ParseSetExpr("empty=null", nil); err != nil || v != nil {
		t.Fatalf("inferred null failed: %v %v", v, err)
	}
	if _, v, err := ParseSetExpr("num=123", nil); err != nil || v != int64(123) {
		t.Fatalf("inferred int failed: %v %v", v, err)
	}
	if _, v, err := ParseSetExpr("flt=1.5", nil); err != nil || v != 1.5 {
		t.Fatalf("inferred float failed: %v %v", v, err)
	}
	if _, v, err := ParseSetExpr("txt=hello", nil); err != nil || v != "hello" {
		t.Fatalf("inferred string failed: %v %v", v, err)
	}
	if _, _, err := ParseSetExpr("b=notbool", map[string]string{"b": "boolean"}); err == nil {
		t.Fatal("expected boolean parse error")
	}
	if _, _, err := ParseSetExpr("f=notfloat", map[string]string{"f": "number"}); err == nil {
		t.Fatal("expected number parse error")
	}
}
