package handler

import (
	"strings"
	"testing"

	"ai-config-server/database/models"
)

// TestGeneratedEnvIncludesSystem1StepRouting 는 STEP_ROUTING 값이 .env로 전달되는지 검증한다.
func TestGeneratedEnvIncludesSystem1StepRouting(t *testing.T) {
	for _, mode := range []string{"off", "shadow", "on"} {
		cfg := &models.RoboClawConfig{System1StepRouting: mode}
		content := string(generateEnvContent(cfg))
		if !strings.Contains(content, "SYSTEM1_STEP_ROUTING="+mode) {
			t.Errorf("expected SYSTEM1_STEP_ROUTING=%s in generated dotenv, got %q", mode, content)
		}
	}
}

// TestGeneratedEnvNormalizesSystem1StepRouting 은 대소문자를 정규화하는지 검증한다.
func TestGeneratedEnvNormalizesSystem1StepRouting(t *testing.T) {
	cfg := &models.RoboClawConfig{System1StepRouting: " SHADOW "}
	content := string(generateEnvContent(cfg))
	if !strings.Contains(content, "SYSTEM1_STEP_ROUTING=shadow") {
		t.Fatalf("expected normalized step routing in generated dotenv, got %q", content)
	}
}

// TestGeneratedEnvOmitsEmptySystem1StepRouting 은 값이 비면 .env에 쓰지 않는지 검증한다.
// 로봇 기본값(shadow)을 그대로 쓰게 하기 위해서다.
func TestGeneratedEnvOmitsEmptySystem1StepRouting(t *testing.T) {
	cfg := &models.RoboClawConfig{System1StepRouting: ""}
	content := string(generateEnvContent(cfg))
	if strings.Contains(content, "SYSTEM1_STEP_ROUTING=") {
		t.Fatalf("expected empty step routing to be omitted, got %q", content)
	}
}

// TestGeneratedEnvOmitsInvalidSystem1StepRouting 은 잘못된 값이 로봇으로 새지 않는지 검증한다.
func TestGeneratedEnvOmitsInvalidSystem1StepRouting(t *testing.T) {
	cfg := &models.RoboClawConfig{System1StepRouting: "maybe"}
	content := string(generateEnvContent(cfg))
	if strings.Contains(content, "SYSTEM1_STEP_ROUTING=") {
		t.Fatalf("expected invalid step routing to be omitted, got %q", content)
	}
}

// TestGeneratedEnvOmitsToggleSystem1ShadowLog 는 잘못 저장된 켜기/끄기 값이
// 로봇으로 전달되지 않는지 확인한다(작업 디렉터리에 “true“ 파일이 생기는 문제 방지).
func TestGeneratedEnvOmitsToggleSystem1ShadowLog(t *testing.T) {
	for _, value := range []string{"true", "ON", "no", "system1_shadow.jsonl"} {
		cfg := &models.RoboClawConfig{System1ShadowLog: value}
		content := string(generateEnvContent(cfg))
		if strings.Contains(content, "SYSTEM1_SHADOW_LOG=") {
			t.Errorf("expected %q to be omitted from generated dotenv, got %q", value, content)
		}
	}

	cfg := &models.RoboClawConfig{System1ShadowLog: "/ws/agent_workspace/system1_shadow.jsonl"}
	content := string(generateEnvContent(cfg))
	if !strings.Contains(content, "SYSTEM1_SHADOW_LOG=/ws/agent_workspace/system1_shadow.jsonl") {
		t.Fatalf("expected absolute shadow log path in generated dotenv, got %q", content)
	}
}

// TestValidateRuntimeValuesSystem1StepRouting 는 enum 검증을 확인한다.
func TestValidateRuntimeValuesSystem1StepRouting(t *testing.T) {
	for _, mode := range []string{"", "off", "shadow", "on", "ON", "Shadow"} {
		cfg := models.RoboClawConfig{System1StepRouting: mode}
		if err := validateRuntimeValues(ptrConfig(cfg)); err != nil {
			t.Errorf("expected %q to be a valid system1_step_routing, got %v", mode, err)
		}
	}
	if err := validateRuntimeValues(ptrConfig(models.RoboClawConfig{System1StepRouting: "maybe"})); err == nil {
		t.Error("expected invalid system1_step_routing to be rejected")
	}
}

// TestValidateRuntimeValuesSystem1ShadowLog 는 파일 경로 검증을 확인한다.
func TestValidateRuntimeValuesSystem1ShadowLog(t *testing.T) {
	valid := []string{"", "/ws/agent_workspace/system1_shadow.jsonl", "/tmp/system1.jsonl"}
	for _, path := range valid {
		cfg := models.RoboClawConfig{System1ShadowLog: path}
		if err := validateRuntimeValues(ptrConfig(cfg)); err != nil {
			t.Errorf("expected %q to be a valid system1_shadow_log, got %v", path, err)
		}
	}

	invalid := []string{"true", "FALSE", "on", "off", "yes", "no", "system1.jsonl", "~/system1.jsonl"}
	for _, value := range invalid {
		cfg := models.RoboClawConfig{System1ShadowLog: value}
		if err := validateRuntimeValues(ptrConfig(cfg)); err == nil {
			t.Errorf("expected %q to be rejected as system1_shadow_log", value)
		}
	}
}

// TestConfigTransferRoundTripPreservesSystem1StepRouting 는 백업/복원에서 값이 유지되는지 검증한다.
func TestConfigTransferRoundTripPreservesSystem1StepRouting(t *testing.T) {
	cfg := models.RoboClawConfig{System1StepRouting: "on"}

	tr := configToTransfer(&cfg, false)
	model := tr.toModel(nil)
	if model.System1StepRouting != "on" {
		t.Fatalf("expected step routing preserved through transfer, got %q", model.System1StepRouting)
	}
}
