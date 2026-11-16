package service

import (
	"strings"
	"testing"

	"ai-config-server/database/models"
)

// TestValidateJSONFields 는 각 필드의 JSON 문법 검증을 확인한다.
func TestValidateJSONFields(t *testing.T) {
	cases := []struct {
		name    string
		limits  string
		ollama  string
		cidrs   string
		skills  string
		blocked string
		mcp     string
		peers   []string
		wantErr string
	}{
		{name: "전체 유효", limits: `{"speed": 1.2}`, ollama: `{"num_ctx": 2048}`, cidrs: `[]`, skills: `[]`, blocked: `[]`, mcp: `[]`},
		{name: "빈 값 허용"},
		{name: "limits 문법 오류", limits: `{"speed": 1.2`, wantErr: "limits_content"},
		{name: "ollama 문법 오류", ollama: `{"num_ctx": 2048`, wantErr: "ollama_options_json"},
		{name: "cidrs 문법 오류", cidrs: `[`, wantErr: "http_allowed_cidrs_json"},
		{name: "skills 최상위 자료형 오류", skills: `{"skill":"a"}`, wantErr: "http_allowed_skills_json"},
		{name: "blocked skills 최상위 자료형 오류", blocked: `"skill"`, wantErr: "http_blocked_skills_json"},
		{name: "limits 최상위 자료형 오류", limits: `[1,2]`, wantErr: "limits_content"},
		{name: "null 거부", ollama: `null`, wantErr: "ollama_options_json"},
		{name: "peers 배열 유효", peers: []string{`[{"host":"10.0.0.1"}]`}},
		{name: "peers 객체 거부", peers: []string{`{"host":"10.0.0.1"}`}, wantErr: "grpc_target_peers_json"},
		{name: "thresholds 객체 유효", peers: []string{``, `{"skill":0.8}`}},
		{name: "thresholds 배열 거부", peers: []string{``, `[]`}, wantErr: "system1_conf_thresholds_json"},
		{name: "motion IDs 배열 유효", peers: []string{``, ``, `[22,60]`}},
		{name: "motion IDs scalar 거부", peers: []string{``, ``, `22`}, wantErr: "cloid_cleanup_demo_motion_ids_json"},
		{name: "motion IDs 문법 오류", peers: []string{``, ``, `[22,`}, wantErr: "cloid_cleanup_demo_motion_ids_json"},
		{name: "motion IDs 문자열 거부", peers: []string{``, ``, `["22"]`}, wantErr: "must contain integer IDs"},
		{name: "motion IDs 음수 거부", peers: []string{``, ``, `[-1]`}, wantErr: "negative IDs"},
		{name: "mcp servers 배열 유효", mcp: `[{"name":"fs","transport":"stdio","command":"npx"}]`},
		{name: "mcp servers 문법 오류", mcp: `[{"name":"fs"`, wantErr: "mcp_servers_json"},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := ValidateJSONFields(tc.limits, tc.ollama, tc.cidrs, tc.skills, tc.blocked, tc.mcp, tc.peers...)
			if tc.wantErr == "" {
				if err != nil {
					t.Fatalf("기대한 오류 없음, got %v", err)
				}
				return
			}
			if err == nil {
				t.Fatalf("오류를 기대했지만 nil")
			}
			if !strings.Contains(err.Error(), tc.wantErr) {
				t.Fatalf("오류 메시지에 %q 가 없음: %v", tc.wantErr, err)
			}
		})
	}
}

// TestValidateJSONShape 는 최상위 자료형 판정을 확인한다.
func TestValidateJSONShape(t *testing.T) {
	if err := ValidateJSONShape("field", "", true); err != nil {
		t.Errorf("빈 문자열은 허용되어야 함: %v", err)
	}
	if err := ValidateJSONShape("field", "[]", true); err != nil {
		t.Errorf("배열 허용: %v", err)
	}
	if err := ValidateJSONShape("field", "{}", false); err != nil {
		t.Errorf("객체 허용: %v", err)
	}
	if err := ValidateJSONShape("field", "null", true); err == nil {
		t.Error("null 은 거부되어야 함")
	}
	if err := ValidateJSONShape("field", "1", true); err == nil {
		t.Error("scalar 는 거부되어야 함")
	}
	if err := ValidateJSONShape("field", "[]", false); err == nil {
		t.Error("객체 자리에 배열은 거부되어야 함")
	}
	if err := ValidateJSONShape("field", "{}", true); err == nil {
		t.Error("배열 자리에 객체는 거부되어야 함")
	}
}

// TestIsShadowLogPath 는 토글 값과 절대 경로 판정을 확인한다.
func TestIsShadowLogPath(t *testing.T) {
	cases := []struct {
		value string
		want  bool
	}{
		{"/var/log/robot/shadow.log", true},
		{" /var/log/robot/shadow.log ", true},
		{"", false},
		{"true", false},
		{"FALSE", false},
		{"on", false},
		{"off", false},
		{"yes", false},
		{"no", false},
		{"shadow.log", false},
		{"relative/shadow.log", false},
	}
	for _, tc := range cases {
		if got := IsShadowLogPath(tc.value); got != tc.want {
			t.Errorf("IsShadowLogPath(%q) = %t, want %t", tc.value, got, tc.want)
		}
	}
}

// TestIsEmptyPeersJSON 는 peer 목록의 빈 값 판정을 확인한다.
func TestIsEmptyPeersJSON(t *testing.T) {
	for _, raw := range []string{"", "[]", "null", " NULL ", "  "} {
		if !IsEmptyPeersJSON(raw) {
			t.Errorf("IsEmptyPeersJSON(%q) 는 true 여야 함", raw)
		}
	}
	for _, raw := range []string{`[{"host":"10.0.0.1"}]`, `[0]`, `{}`} {
		if IsEmptyPeersJSON(raw) {
			t.Errorf("IsEmptyPeersJSON(%q) 는 false 여야 함", raw)
		}
	}
}

// TestValidateRuntimeValuesAcceptsDefaults 는 영값 설정이 통과하는지 확인한다.
func TestValidateRuntimeValuesAcceptsDefaults(t *testing.T) {
	if err := ValidateRuntimeValues(&models.RoboClawConfig{}); err != nil {
		t.Fatalf("기본값은 유효해야 함: %v", err)
	}
	valid := &models.RoboClawConfig{
		LlmProvider:                    "Ollama",
		RosDomainId:                    232,
		HttpPort:                       65535,
		DashboardPort:                  1,
		GrpcTargetPort:                 50052,
		RagScoreThreshold:              1,
		SkillLearningSuccessSampleRate: 0,
		System1Router:                  "laya",
		System1Scope:                   "navigation",
		System1StepRouting:             " SHADOW ",
		System1ShadowLog:               "/var/log/robot/shadow.log",
		System1TimeoutMs:               1,
		System1MaxOptions:              2,
		System1ConfThresholdsJson:      `{"skill":0,"navigation":1}`,
		MaestroDisconnectPolicy:        "finish_atomic",
		RobotPort:                      50053,
		FleetHeartbeatSec:              0,
	}
	if err := ValidateRuntimeValues(valid); err != nil {
		t.Fatalf("경계값 설정은 유효해야 함: %v", err)
	}
}

// TestValidateRuntimeValuesRejectsScalarAndRangeViolations 는 범위/enum 위반을 확인한다.
func TestValidateRuntimeValuesRejectsScalarAndRangeViolations(t *testing.T) {
	cases := []struct {
		name   string
		mutate func(cfg *models.RoboClawConfig)
		want   string
	}{
		{"llm_provider enum", func(c *models.RoboClawConfig) { c.LlmProvider = "gemini" }, "llm_provider"},
		{"ros_domain_id 음수", func(c *models.RoboClawConfig) { c.RosDomainId = -1 }, "ros_domain_id"},
		{"ros_domain_id 초과", func(c *models.RoboClawConfig) { c.RosDomainId = 233 }, "ros_domain_id"},
		{"http_port 음수", func(c *models.RoboClawConfig) { c.HttpPort = -1 }, "http_port"},
		{"http_port 초과", func(c *models.RoboClawConfig) { c.HttpPort = 65536 }, "http_port"},
		{"dashboard_port 초과", func(c *models.RoboClawConfig) { c.DashboardPort = 65536 }, "dashboard_port"},
		{"grpc_target_port 음수", func(c *models.RoboClawConfig) { c.GrpcTargetPort = -1 }, "grpc_target_port"},
		{"rate limit 음수", func(c *models.RoboClawConfig) { c.HttpRateLimitPerMinute = -1 }, "rate limit"},
		{"rag_top_k 음수", func(c *models.RoboClawConfig) { c.RagTopK = -1 }, "rate limit"},
		{"task_queue_max_size 음수", func(c *models.RoboClawConfig) { c.TaskQueueMaxSize = -1 }, "rate limit"},
		{"rag_score_threshold 음수", func(c *models.RoboClawConfig) { c.RagScoreThreshold = -0.1 }, "rag_score_threshold"},
		{"rag_score_threshold 초과", func(c *models.RoboClawConfig) { c.RagScoreThreshold = 1.1 }, "rag_score_threshold"},
		{"qdrant_timeout 음수", func(c *models.RoboClawConfig) { c.QdrantTimeoutSec = -1 }, "timeout"},
		{"reflect interval 음수", func(c *models.RoboClawConfig) { c.SkillLearningReflectIntervalSec = -1 }, "timeout"},
		{"sample rate 음수", func(c *models.RoboClawConfig) { c.SkillLearningSuccessSampleRate = -0.5 }, "sample_rate"},
		{"sample rate 초과", func(c *models.RoboClawConfig) { c.SkillLearningSuccessSampleRate = 1.5 }, "sample_rate"},
		{"system1_router enum", func(c *models.RoboClawConfig) { c.System1Router = "llm" }, "system1_router"},
		{"system1_scope enum", func(c *models.RoboClawConfig) { c.System1Scope = "write" }, "system1_scope"},
		{"system1_step_routing enum", func(c *models.RoboClawConfig) { c.System1StepRouting = "partial" }, "system1_step_routing"},
		{"shadow log 토글", func(c *models.RoboClawConfig) { c.System1ShadowLog = "true" }, "켜기/끄기 값"},
		{"shadow log 상대 경로", func(c *models.RoboClawConfig) { c.System1ShadowLog = "logs/shadow.log" }, "절대 경로"},
		{"system1_timeout_ms 범위", func(c *models.RoboClawConfig) { c.System1TimeoutMs = 0.5 }, "system1_timeout_ms"},
		{"system1_max_options 범위", func(c *models.RoboClawConfig) { c.System1MaxOptions = 1 }, "system1_max_options"},
		{"thresholds 숫자 아님", func(c *models.RoboClawConfig) { c.System1ConfThresholdsJson = `{"skill":"high"}` }, "숫자로 된 JSON 객체"},
		{"thresholds 범위 초과", func(c *models.RoboClawConfig) { c.System1ConfThresholdsJson = `{"skill":1.2}` }, "0~1 범위"},
		{"task decomposition 음수", func(c *models.RoboClawConfig) { c.TaskDecompositionMaxSteps = -1 }, "task decomposition"},
		{"task step retries 음수", func(c *models.RoboClawConfig) { c.TaskStepMaxRetries = -1 }, "task decomposition"},
		{"wait margin 음수", func(c *models.RoboClawConfig) { c.TaskDecompositionWaitMarginCapSec = -1 }, "task decomposition"},
		{"vision path 누락", func(c *models.RoboClawConfig) { c.UseVision = true }, "vision_model_path"},
		{"maestro_disconnect_policy enum", func(c *models.RoboClawConfig) { c.MaestroDisconnectPolicy = "explode" }, "maestro_disconnect_policy"},
		{"robot_port 초과", func(c *models.RoboClawConfig) { c.RobotPort = 70000 }, "robot_port"},
		{"fleet_heartbeat_sec 음수", func(c *models.RoboClawConfig) { c.FleetHeartbeatSec = -1 }, "fleet_heartbeat_sec"},
		{"maestro_ip 단독", func(c *models.RoboClawConfig) { c.MaestroIp = "10.0.0.5" }, "robot_id"},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			cfg := &models.RoboClawConfig{}
			tc.mutate(cfg)
			err := ValidateRuntimeValues(cfg)
			if err == nil {
				t.Fatalf("오류를 기대했지만 nil")
			}
			if !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("오류 메시지에 %q 가 없음: %v", tc.want, err)
			}
		})
	}
}

// TestValidateRuntimeValuesMaestroEnabled 는 Maestro 활성 조건을 확인한다.
func TestValidateRuntimeValuesMaestroEnabled(t *testing.T) {
	enabled := func() models.RoboClawConfig {
		return models.RoboClawConfig{
			MaestroEnabled:          true,
			MaestroIp:               "10.0.0.5",
			RobotId:                 "butler-01",
			RobotPort:               50053,
			MaestroDisconnectPolicy: "complete",
			FleetHeartbeatSec:       1,
			UseGrpc:                 true,
		}
	}
	valid := enabled()
	if err := ValidateRuntimeValues(&valid); err != nil {
		t.Fatalf("활성 Maestro 설정은 유효해야 함: %v", err)
	}

	cases := []struct {
		name   string
		mutate func(cfg *models.RoboClawConfig)
	}{
		{"maestro_ip 누락", func(c *models.RoboClawConfig) { c.MaestroIp = "" }},
		{"robot_id 누락", func(c *models.RoboClawConfig) { c.RobotId = "" }},
		{"use_grpc 꺼짐", func(c *models.RoboClawConfig) { c.UseGrpc = false }},
		{"enable_grpc 켜짐", func(c *models.RoboClawConfig) { c.EnableGrpc = true }},
		{"enable_grpc_client 켜짐", func(c *models.RoboClawConfig) { c.EnableGrpcClient = true }},
		{"peers 비어있지 않음", func(c *models.RoboClawConfig) { c.GrpcTargetPeersJson = `[{"host":"10.0.0.9"}]` }},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			cfg := enabled()
			tc.mutate(&cfg)
			if err := ValidateRuntimeValues(&cfg); err == nil {
				t.Fatal("오류를 기대했지만 nil")
			}
		})
	}

	// Maestro 스위치를 끄면 IP/robot_id/gRPC 노드 없이도 저장할 수 있어야 한다.
	disabled := enabled()
	disabled.MaestroEnabled = false
	disabled.UseGrpc = false
	disabled.MaestroIp = ""
	if err := ValidateRuntimeValues(&disabled); err != nil {
		t.Fatalf("비활성 Maestro 설정은 유효해야 함: %v", err)
	}

	// 빈 peers 표기는 모두 허용한다.
	for _, peers := range []string{"", "[]", "null"} {
		emptyPeers := enabled()
		emptyPeers.GrpcTargetPeersJson = peers
		if err := ValidateRuntimeValues(&emptyPeers); err != nil {
			t.Errorf("빈 peers(%q) 는 허용되어야 함: %v", peers, err)
		}
	}
}
