package service

import (
	"encoding/json"
	"fmt"
	"strings"

	"ai-config-server/database/models"
)

// ValidateJSONFields는 입력된 문자열이 유효한 JSON 포맷인지 Go 표준 라이브러리로 사전 검사합니다.
func ValidateJSONFields(limits, ollamaOptions, allowedCidrs, allowedSkills, blockedSkills, mcpServers string, peerValues ...string) error {
	if err := ValidateJSONShape("limits_content", limits, false); err != nil {
		return err
	}
	if err := ValidateJSONShape("ollama_options_json", ollamaOptions, false); err != nil {
		return err
	}
	if err := ValidateJSONShape("http_allowed_cidrs_json", allowedCidrs, true); err != nil {
		return err
	}
	if err := ValidateJSONShape("http_allowed_skills_json", allowedSkills, true); err != nil {
		return err
	}
	if err := ValidateJSONShape("http_blocked_skills_json", blockedSkills, true); err != nil {
		return err
	}
	if err := ValidateJSONShape("mcp_servers_json", mcpServers, true); err != nil {
		return err
	}
	peers := ""
	if len(peerValues) > 0 {
		peers = peerValues[0]
	}
	if err := ValidateJSONShape("grpc_target_peers_json", peers, true); err != nil {
		return err
	}
	thresholds := ""
	if len(peerValues) > 1 {
		thresholds = peerValues[1]
	}
	if err := ValidateJSONShape("system1_conf_thresholds_json", thresholds, false); err != nil {
		return err
	}
	cleanupDemoMotionIDs := ""
	if len(peerValues) > 2 {
		cleanupDemoMotionIDs = peerValues[2]
	}
	if err := ValidateJSONShape("cloid_cleanup_demo_motion_ids_json", cleanupDemoMotionIDs, true); err != nil {
		return err
	}
	if cleanupDemoMotionIDs != "" {
		var motionIDs []int
		if err := json.Unmarshal([]byte(cleanupDemoMotionIDs), &motionIDs); err != nil {
			return fmt.Errorf("cloid_cleanup_demo_motion_ids_json must contain integer IDs: %w", err)
		}
		for _, motionID := range motionIDs {
			if motionID < 0 {
				return fmt.Errorf("cloid_cleanup_demo_motion_ids_json must not contain negative IDs")
			}
		}
	}
	return nil
}

// ValidateJSONShape는 JSON 문법뿐 아니라 최상위 자료형도 검증한다.
// ROS launch 쪽은 배열/객체를 문자열로 전달하므로 scalar/null을 허용하면
// 실행 시점까지 오류가 지연된다.
func ValidateJSONShape(fieldName, raw string, wantArray bool) error {
	if raw == "" {
		return nil
	}

	var value any
	if err := json.Unmarshal([]byte(raw), &value); err != nil {
		return fmt.Errorf("%s 필드의 JSON 형식이 올바르지 않습니다.", fieldName)
	}
	if value == nil {
		return fmt.Errorf("%s 필드는 null일 수 없습니다.", fieldName)
	}

	if wantArray {
		if _, ok := value.([]any); !ok {
			return fmt.Errorf("%s 필드는 JSON 배열이어야 합니다.", fieldName)
		}
	} else {
		if _, ok := value.(map[string]any); !ok {
			return fmt.Errorf("%s 필드는 JSON 객체여야 합니다.", fieldName)
		}
	}
	return nil
}

// shadowLogToggles는 SYSTEM1_SHADOW_LOG 자리에 잘못 들어가는 켜기/끄기 값이다.
// 이 값은 파일 경로가 아니므로 로봇이 작업 디렉터리에 동명의 파일을 만든다.
var shadowLogToggles = map[string]bool{
	"true": true, "false": true, "on": true, "off": true, "yes": true, "no": true,
}

// IsShadowLogPath는 SYSTEM1_SHADOW_LOG 값이 켜기/끄기 토글이 아닌 절대 경로인지 판정한다.
func IsShadowLogPath(value string) bool {
	trimmed := strings.TrimSpace(value)
	return strings.HasPrefix(trimmed, "/") && !shadowLogToggles[strings.ToLower(trimmed)]
}

func ValidateRuntimeValues(cfg *models.RoboClawConfig) error {
	providers := map[string]bool{"": true, "azure": true, "openai": true, "anthropic": true, "ollama": true}
	if !providers[strings.ToLower(cfg.LlmProvider)] {
		return fmt.Errorf("지원하지 않는 llm_provider입니다: %s", cfg.LlmProvider)
	}
	if cfg.RosDomainId < 0 || cfg.RosDomainId > 232 {
		return fmt.Errorf("ros_domain_id는 0~232 범위여야 합니다")
	}
	if cfg.HttpPort < 0 || cfg.HttpPort > 65535 {
		return fmt.Errorf("http_port는 1~65535 범위여야 합니다")
	}
	if cfg.DashboardPort < 0 || cfg.DashboardPort > 65535 {
		return fmt.Errorf("dashboard_port는 1~65535 범위여야 합니다")
	}
	if cfg.GrpcTargetPort < 0 || cfg.GrpcTargetPort > 65535 {
		return fmt.Errorf("grpc_target_port는 1~65535 범위여야 합니다")
	}
	if cfg.HttpRateLimitPerMinute < 0 || cfg.RagTopK < 0 || cfg.TaskQueueMaxSize < 0 {
		return fmt.Errorf("rate limit, rag_top_k, task_queue_max_size는 음수일 수 없습니다")
	}
	if cfg.RagScoreThreshold < 0 || cfg.RagScoreThreshold > 1 {
		return fmt.Errorf("rag_score_threshold는 0~1 범위여야 합니다")
	}
	if cfg.QdrantTimeoutSec < 0 || cfg.SkillLearningReflectIntervalSec < 0 {
		return fmt.Errorf("timeout과 reflect interval은 음수일 수 없습니다")
	}
	if cfg.SkillLearningSuccessSampleRate < 0 || cfg.SkillLearningSuccessSampleRate > 1 {
		return fmt.Errorf("skill_learning_success_sample_rate는 0~1 범위여야 합니다")
	}
	system1Routers := map[string]bool{"": true, "rule": true, "laya": true}
	if !system1Routers[strings.ToLower(cfg.System1Router)] {
		return fmt.Errorf("지원하지 않는 system1_router입니다: %s", cfg.System1Router)
	}
	system1Scopes := map[string]bool{"": true, "readonly": true, "navigation": true}
	if !system1Scopes[strings.ToLower(cfg.System1Scope)] {
		return fmt.Errorf("지원하지 않는 system1_scope입니다: %s", cfg.System1Scope)
	}
	system1StepRoutings := map[string]bool{"": true, "off": true, "shadow": true, "on": true}
	if !system1StepRoutings[strings.ToLower(strings.TrimSpace(cfg.System1StepRouting))] {
		return fmt.Errorf("지원하지 않는 system1_step_routing입니다: %s", cfg.System1StepRouting)
	}
	if shadowLog := strings.TrimSpace(cfg.System1ShadowLog); shadowLog != "" && !IsShadowLogPath(shadowLog) {
		if shadowLogToggles[strings.ToLower(shadowLog)] {
			return fmt.Errorf("system1_shadow_log는 켜기/끄기 값이 아니라 파일 경로여야 합니다: %s", cfg.System1ShadowLog)
		}
		return fmt.Errorf("system1_shadow_log는 절대 경로여야 합니다: %s", cfg.System1ShadowLog)
	}
	if cfg.System1TimeoutMs > 0 && cfg.System1TimeoutMs < 1 {
		return fmt.Errorf("system1_timeout_ms는 1 이상이어야 합니다")
	}
	if cfg.System1MaxOptions > 0 && cfg.System1MaxOptions < 2 {
		return fmt.Errorf("system1_max_options는 2 이상이어야 합니다")
	}
	if cfg.System1ConfThresholdsJson != "" {
		var thresholds map[string]float64
		if err := json.Unmarshal([]byte(cfg.System1ConfThresholdsJson), &thresholds); err != nil {
			return fmt.Errorf("system1_conf_thresholds_json 필드 값은 숫자로 된 JSON 객체여야 합니다")
		}
		for name, value := range thresholds {
			if value < 0 || value > 1 {
				return fmt.Errorf("system1_conf_thresholds_json의 %q 값은 0~1 범위여야 합니다", name)
			}
		}
	}
	if cfg.TaskDecompositionMaxSteps < 0 || cfg.TaskStepMaxRetries < 0 || cfg.TaskDecompositionWaitMarginCapSec < 0 {
		return fmt.Errorf("task decomposition 설정은 음수일 수 없습니다")
	}
	if cfg.UseVision && strings.TrimSpace(cfg.VisionModelPath) == "" {
		return fmt.Errorf("use_vision이 true이면 vision_model_path가 필요합니다")
	}
	// ── Maestro FleetControl outbound connector (contract v2.2.0) ──
	disconnectPolicies := map[string]bool{"": true, "complete": true, "stop": true, "finish_atomic": true}
	if !disconnectPolicies[cfg.MaestroDisconnectPolicy] {
		return fmt.Errorf("지원하지 않는 maestro_disconnect_policy입니다: %s", cfg.MaestroDisconnectPolicy)
	}
	if cfg.RobotPort < 0 || cfg.RobotPort > 65535 {
		return fmt.Errorf("robot_port는 1~65535 범위여야 합니다")
	}
	if cfg.FleetHeartbeatSec < 0 {
		return fmt.Errorf("fleet_heartbeat_sec는 음수일 수 없습니다")
	}
	if strings.TrimSpace(cfg.MaestroIp) != "" && strings.TrimSpace(cfg.RobotId) == "" {
		return fmt.Errorf("maestro_ip가 설정되면 robot_id가 필요합니다")
	}
	if cfg.MaestroEnabled {
		if strings.TrimSpace(cfg.MaestroIp) == "" {
			return fmt.Errorf("maestro_enabled=true이면 maestro_ip가 필요합니다")
		}
		if strings.TrimSpace(cfg.RobotId) == "" {
			return fmt.Errorf("maestro_enabled=true이면 robot_id가 필요합니다")
		}
		if !cfg.UseGrpc {
			return fmt.Errorf("maestro_enabled=true이면 gRPC 노드 사용(use_grpc)도 켜야 합니다")
		}
		// Maestro가 명령의 단일 경로이므로 로봇 간 협업 채널은 함께 켤 수 없다.
		if cfg.EnableGrpc {
			return fmt.Errorf("maestro_enabled=true이면 gRPC 메신저 서버(enable_grpc)를 꺼야 합니다")
		}
		if cfg.EnableGrpcClient {
			return fmt.Errorf("maestro_enabled=true이면 gRPC 클라이언트(enable_grpc_client)를 꺼야 합니다")
		}
		if !IsEmptyPeersJSON(cfg.GrpcTargetPeersJson) {
			return fmt.Errorf("maestro_enabled=true이면 grpc_target_peers_json을 비워야 합니다")
		}
	}
	return nil
}

// IsEmptyPeersJSON은 peer 목록 JSON이 사실상 빈 값인지 판정한다.
func IsEmptyPeersJSON(raw string) bool {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "", "[]", "null":
		return true
	default:
		return false
	}
}
