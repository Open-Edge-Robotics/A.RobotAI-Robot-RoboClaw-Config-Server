package handler

import (
	"encoding/json"
	"strings"
	"testing"

	"ai-config-server/database/models"
)

// TestBuildConfigFileContent 는 파일 유형별 콘텐츠 생성을 검증한다.
func TestBuildConfigFileContent(t *testing.T) {
	cfg := &models.RoboClawConfig{
		Name:                   "c",
		RobotName:              "butler",
		Environment:            "office",
		SoulContent:            "# soul",
		SkillsContent:          "# skills",
		TroubleshootingContent: "# trouble",
		LimitsContent:          `{"max_linear_speed":1.0}`,
	}

	// .env
	content, ok := buildConfigFileContent(cfg, ".env")
	if !ok || !strings.Contains(string(content), "ROS_DOMAIN_ID") {
		t.Errorf("expected .env to contain ROS_DOMAIN_ID, got %q", content)
	}

	// ROBOT.md
	content, ok = buildConfigFileContent(cfg, "ROBOT.md")
	if !ok || string(content) != "# soul" {
		t.Errorf("expected soul content, got %q", content)
	}

	// SKILLS.md
	content, ok = buildConfigFileContent(cfg, "SKILLS.md")
	if !ok || string(content) != "# skills" {
		t.Errorf("expected skills content, got %q", content)
	}

	// TROUBLESHOOTING.md
	content, ok = buildConfigFileContent(cfg, "TROUBLESHOOTING.md")
	if !ok || string(content) != "# trouble" {
		t.Errorf("expected troubleshooting content, got %q", content)
	}

	// ROBOT_LIMITS.json
	content, ok = buildConfigFileContent(cfg, "ROBOT_LIMITS.json")
	if !ok || !json.Valid(content) {
		t.Errorf("expected valid limits JSON, got %q", content)
	}

	// 지원하지 않는 파일명
	if _, ok := buildConfigFileContent(cfg, "UNKNOWN.txt"); ok {
		t.Error("expected not-found for unknown filename")
	}
}

func TestGeneratedEnvEscapesNewlines(t *testing.T) {
	cfg := &models.RoboClawConfig{
		RobotName:   "butler",
		Environment: "office",
		AgentId:     "agent\nINJECTED=value",
	}

	content := string(generateEnvContent(cfg))
	if strings.Contains(content, "agent\nINJECTED=value") {
		t.Fatal("generated dotenv contains an unescaped newline")
	}
	if !strings.Contains(content, `RC_AGENT_ID=agent\nINJECTED=value`) {
		t.Fatalf("expected escaped newline in generated dotenv, got %q", content)
	}
}

// TestGeneratedEnvIncludesDashboardNode 는 .env에 Dashboard 노드 환경변수가
// 포함되는지 검증한다. (RC_DASHBOARD_HOST / RC_DASHBOARD_PORT)
func TestGeneratedEnvIncludesDashboardNode(t *testing.T) {
	cfg := &models.RoboClawConfig{
		RobotName:     "butler",
		Environment:   "office",
		DashboardHost: "0.0.0.0",
		DashboardPort: 9090,
	}

	content := string(generateEnvContent(cfg))
	if !strings.Contains(content, "RC_DASHBOARD_HOST=0.0.0.0") {
		t.Fatalf("expected RC_DASHBOARD_HOST in generated dotenv, got %q", content)
	}
	if !strings.Contains(content, "RC_DASHBOARD_PORT=9090") {
		t.Fatalf("expected RC_DASHBOARD_PORT in generated dotenv, got %q", content)
	}
}

func TestGeneratedEnvIncludesLangsmithWorkspaceID(t *testing.T) {
	cfg := &models.RoboClawConfig{
		LangsmithWorkspaceId: "workspace-123",
	}

	content := string(generateEnvContent(cfg))
	if !strings.Contains(content, "LANGSMITH_WORKSPACE_ID=workspace-123") {
		t.Fatalf("expected LangSmith workspace ID in generated dotenv, got %q", content)
	}
}

func TestGeneratedEnvCompactsSystem1ThresholdsJSON(t *testing.T) {
	cfg := &models.RoboClawConfig{
		System1ConfThresholdsJson: "{\n  \"skill\": 0.8\n}",
	}

	content := string(generateEnvContent(cfg))
	if !strings.Contains(content, `SYSTEM1_CONF_THRESHOLDS_JSON={"skill":0.8}`) {
		t.Fatalf("expected compact JSON threshold value, got %q", content)
	}
}

func TestGeneratedEnvIncludesSystem1RouterSettings(t *testing.T) {
	cfg := &models.RoboClawConfig{
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
		System1ApiKey:             "system1-secret",
	}

	content := string(generateEnvContent(cfg))
	for _, expected := range []string{
		"SYSTEM1_ROUTER=laya",
		"SYSTEM1_SHADOW=true",
		"SYSTEM1_SHADOW_LOG=/tmp/system1.jsonl",
		"SYSTEM1_SCOPE=navigation",
		"SYSTEM1_ENDPOINT=http://laya:8000",
		"SYSTEM1_PROVIDER=laya",
		"SYSTEM1_TIMEOUT_MS=450",
		`SYSTEM1_CONF_THRESHOLDS_JSON={"smalltalk":0.95}`,
		"SYSTEM1_SKILLS=get_status,identify_location",
		"SYSTEM1_MAX_OPTIONS=8",
		"SYSTEM1_API_KEY=system1-secret",
	} {
		if !strings.Contains(content, expected) {
			t.Errorf("expected generated dotenv to contain %q, got %q", expected, content)
		}
	}
}
