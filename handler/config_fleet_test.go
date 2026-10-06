package handler

import (
	"encoding/json"
	"strings"
	"testing"

	"ai-config-server/database"
	"ai-config-server/database/models"
	"ai-config-server/testutil"
	"github.com/gin-gonic/gin"
)

// TestValidateRuntimeValuesFleetControl 는 v2.2.0 fleet.* field의
// enum/range/dependency 검증을 확인한다.
func TestValidateRuntimeValuesFleetControl(t *testing.T) {
	base := func() models.RoboClawConfig {
		return models.RoboClawConfig{
			RobotPort:               50053,
			MaestroDisconnectPolicy: "complete",
			FleetHeartbeatSec:       1.0,
		}
	}

	if err := validateRuntimeValues(ptrConfig(base())); err != nil {
		t.Fatalf("expected valid fleet config, got %v", err)
	}

	badPolicy := base()
	badPolicy.MaestroDisconnectPolicy = "explode"
	if err := validateRuntimeValues(ptrConfig(badPolicy)); err == nil {
		t.Error("expected invalid maestro_disconnect_policy to be rejected")
	}

	badPort := base()
	badPort.RobotPort = 70000
	if err := validateRuntimeValues(ptrConfig(badPort)); err == nil {
		t.Error("expected out-of-range robot_port to be rejected")
	}

	negativeHeartbeat := base()
	negativeHeartbeat.FleetHeartbeatSec = -1
	if err := validateRuntimeValues(ptrConfig(negativeHeartbeat)); err == nil {
		t.Error("expected negative fleet_heartbeat_sec to be rejected")
	}

	missingRobotId := base()
	missingRobotId.MaestroIp = "10.0.0.5"
	if err := validateRuntimeValues(ptrConfig(missingRobotId)); err == nil {
		t.Error("expected maestro_ip without robot_id to be rejected")
	}

	withRobotId := base()
	withRobotId.MaestroIp = "10.0.0.5"
	withRobotId.RobotId = "butler-01"
	if err := validateRuntimeValues(ptrConfig(withRobotId)); err != nil {
		t.Errorf("expected maestro_ip with robot_id to be valid, got %v", err)
	}
}

func ptrConfig(c models.RoboClawConfig) *models.RoboClawConfig { return &c }

// TestGeneratedEnvIncludesFleetControl 은 .env에 contract v2.2.0의
// fleet.* env 이름이 정확히 매핑되는지 확인한다.
func TestGeneratedEnvIncludesFleetControl(t *testing.T) {
	cfg := &models.RoboClawConfig{
		RobotName:               "butler",
		Environment:             "office",
		MaestroIp:               "10.0.0.5",
		RobotPort:               50053,
		RobotId:                 "butler-01",
		RobotSiteId:             "site-a",
		RobotMapId:              "1f",
		RobotMapVersion:         "v3",
		RobotMapFrameId:         "map",
		MaestroDisconnectPolicy: "finish_atomic",
		FleetHeartbeatSec:       2.5,
		FleetCommandJournalPath: "/var/lib/fleet.sqlite3",
		FleetSkillsGuideFile:    "/etc/robo/skills.md",
		FleetControlTls:         true,
		FleetControlCaCert:      "/etc/robo/ca.pem",
		FleetControlClientCert:  "/etc/robo/client.pem",
		FleetControlClientKey:   "/etc/robo/client.key",
	}

	body := generateEnvContent(cfg)
	for field, want := range map[string]string{
		"MAESTRO_IP":                 "MAESTRO_IP=10.0.0.5",
		"ROBOT_PORT":                 "ROBOT_PORT=50053",
		"ROBOT_ID":                   "ROBOT_ID=butler-01",
		"ROBOT_SITE_ID":              "ROBOT_SITE_ID=site-a",
		"ROBOT_MAP_ID":               "ROBOT_MAP_ID=1f",
		"ROBOT_MAP_VERSION":          "ROBOT_MAP_VERSION=v3",
		"ROBOT_MAP_FRAME_ID":         "ROBOT_MAP_FRAME_ID=map",
		"MAESTRO_DISCONNECT_POLICY":  "MAESTRO_DISCONNECT_POLICY=finish_atomic",
		"FLEET_HEARTBEAT_SEC":        "FLEET_HEARTBEAT_SEC=2.5",
		"FLEET_COMMAND_JOURNAL_PATH": "FLEET_COMMAND_JOURNAL_PATH=/var/lib/fleet.sqlite3",
		"RC_SKILLS_GUIDE_FILE":       "RC_SKILLS_GUIDE_FILE=/etc/robo/skills.md",
		"FLEET_CONTROL_TLS":          "FLEET_CONTROL_TLS=true",
		"FLEET_CONTROL_CA_CERT":      "FLEET_CONTROL_CA_CERT=/etc/robo/ca.pem",
		"FLEET_CONTROL_CLIENT_CERT":  "FLEET_CONTROL_CLIENT_CERT=/etc/robo/client.pem",
		"FLEET_CONTROL_CLIENT_KEY":   "FLEET_CONTROL_CLIENT_KEY=/etc/robo/client.key",
	} {
		if !strings.Contains(body, want) {
			t.Errorf("expected .env to contain %q for %s", want, field)
		}
	}
}

// TestGeneratedEnvSkillsGuideFileDefaults 는 skills_guide_file이 비어 있을 때
// 기존 배포 경로(config/SKILLS.md)가 유지되는지 확인한다.
func TestGeneratedEnvSkillsGuideFileDefaults(t *testing.T) {
	body := generateEnvContent(&models.RoboClawConfig{RobotName: "butler", Environment: "office"})
	if !strings.Contains(body, "RC_SKILLS_GUIDE_FILE=config/SKILLS.md") {
		t.Fatalf("expected default skills guide path, got %q", body)
	}
	if strings.Count(body, "RC_SKILLS_GUIDE_FILE=") != 1 {
		t.Fatalf("expected exactly one RC_SKILLS_GUIDE_FILE line, got %q", body)
	}
}

// TestConfigTransferRoundTripPreservesFleetControl 은 export/import가 fleet.*
// 값을 보존하는지 확인한다.
func TestConfigTransferRoundTripPreservesFleetControl(t *testing.T) {
	cfg := models.RoboClawConfig{
		Name:                    "fleet",
		RobotName:               "butler",
		Environment:             "office",
		MaestroIp:               "10.0.0.5",
		RobotPort:               50053,
		RobotId:                 "butler-01",
		RobotSiteId:             "site-a",
		RobotMapId:              "1f",
		RobotMapVersion:         "v3",
		RobotMapFrameId:         "map",
		MaestroDisconnectPolicy: "stop",
		FleetHeartbeatSec:       2.5,
		FleetCommandJournalPath: "/var/lib/fleet.sqlite3",
		FleetSkillsGuideFile:    "/etc/robo/skills.md",
		FleetControlTls:         true,
		FleetControlCaCert:      "/etc/robo/ca.pem",
		FleetControlClientCert:  "/etc/robo/client.pem",
		FleetControlClientKey:   "/etc/robo/client.key",
	}

	tr := configToTransfer(&cfg, false)
	got := tr.toModel(nil)

	if got.MaestroIp != cfg.MaestroIp || got.RobotPort != cfg.RobotPort || got.RobotId != cfg.RobotId {
		t.Fatalf("fleet identity not preserved: %#v", got)
	}
	if got.MaestroDisconnectPolicy != cfg.MaestroDisconnectPolicy || got.FleetHeartbeatSec != cfg.FleetHeartbeatSec {
		t.Fatalf("fleet policy not preserved: %#v", got)
	}
	if got.FleetControlTls != cfg.FleetControlTls || got.FleetControlClientKey != cfg.FleetControlClientKey {
		t.Fatalf("fleet mTLS not preserved: %#v", got)
	}
}

// TestGetActiveRuntimeConfigV2IncludesFleetFields 는 v2 manifest 응답의
// config에 contract api_json field가 포함되는지 확인한다.
func TestGetActiveRuntimeConfigV2IncludesFleetFields(t *testing.T) {
	setupRouterTestDB(t)
	database.DB.Create(&models.RoboClawConfig{
		Name: "active", RobotName: "butler", Environment: "office", IsActive: true,
		MaestroIp: "10.0.0.5", RobotId: "butler-01", RobotPort: 50053,
		LangsmithWorkspaceId: "workspace-123",
		System1Router:        "laya", System1Endpoint: "http://laya:8000", System1ApiKey: "system1-secret",
	})

	r := gin.New()
	r.GET("/api/v2/device/runtime-config", GetActiveRuntimeConfigV2)
	w := testutil.PerformJSON(r, "GET", "/api/v2/device/runtime-config?robot_name=butler&environment=office", "", nil)
	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	var response map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	config := response["config"].(map[string]any)
	for _, key := range []string{
		"maestro_ip", "robot_port", "robot_id", "robot_site_id", "robot_map_id",
		"robot_map_version", "robot_map_frame_id", "maestro_disconnect_policy",
		"fleet_heartbeat_sec", "fleet_command_journal_path", "skills_guide_file",
		"fleet_control_tls", "fleet_control_ca_cert", "fleet_control_client_cert",
		"fleet_control_client_key", "langsmith_workspace_id",
		"system1_router", "system1_shadow", "system1_shadow_log", "system1_scope",
		"system1_endpoint", "system1_provider", "system1_timeout_ms",
		"system1_conf_thresholds_json", "system1_skills", "system1_max_options", "system1_api_key",
	} {
		if _, ok := config[key]; !ok {
			t.Errorf("expected runtime manifest to expose %q", key)
		}
	}
	if config["langsmith_workspace_id"] != "workspace-123" {
		t.Errorf("expected workspace ID in runtime manifest, got %v", config["langsmith_workspace_id"])
	}
	if config["system1_router"] != "laya" {
		t.Errorf("expected System 1 router in runtime manifest, got %v", config["system1_router"])
	}
	if config["system1_api_key"] != MaskValue {
		t.Errorf("expected System 1 API key masked in runtime manifest, got %v", config["system1_api_key"])
	}
}
