package transfer

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"

	"ai-config-server/database/models"
)

// TestConfigFromModelCoversProfileFields 는 이식용 DTO가 프로필 필드를 모두 담는지 확인한다.
func TestConfigFromModelCoversProfileFields(t *testing.T) {
	transferFields := make(map[string]bool)
	transferType := reflect.TypeFor[ConfigTransfer]()
	for i := 0; i < transferType.NumField(); i++ {
		name := strings.Split(transferType.Field(i).Tag.Get("json"), ",")[0]
		transferFields[name] = true
	}

	modelType := reflect.TypeFor[models.RoboClawConfig]()
	for i := 0; i < modelType.NumField(); i++ {
		field := modelType.Field(i)
		// Embedded GORM metadata is deliberately excluded from portable backups.
		if field.Anonymous {
			continue
		}
		name := strings.Split(field.Tag.Get("json"), ",")[0]
		if name != "" && name != "-" && !transferFields[name] {
			t.Errorf("profile field %s is missing from the backup DTO", name)
		}
	}
}

func fullProfileFixture() models.RoboClawConfig {
	var cfg models.RoboClawConfig
	value := reflect.ValueOf(&cfg).Elem()
	for i := 0; i < value.NumField(); i++ {
		field := value.Field(i)
		if value.Type().Field(i).Anonymous {
			continue
		}
		switch field.Kind() {
		case reflect.String:
			field.SetString("fixture_" + value.Type().Field(i).Name)
		case reflect.Bool:
			field.SetBool(true)
		case reflect.Int:
			field.SetInt(123)
		case reflect.Float64:
			field.SetFloat(1.25)
		case reflect.Pointer:
			if field.Type().Elem().Kind() != reflect.Bool {
				panic("unsupported fixture field: " + value.Type().Field(i).Name)
			}
			field.Set(reflect.ValueOf(new(true)))
		default:
			panic("unsupported fixture field: " + value.Type().Field(i).Name)
		}
	}
	return cfg
}

// TestConfigTransferJSONRoundTripPreservesAllProfileFields 는 모든 필드가
// JSON 왕복 후에도 값이 유지되는지 확인한다.
func TestConfigTransferJSONRoundTripPreservesAllProfileFields(t *testing.T) {
	cfg := fullProfileFixture()
	data, err := json.Marshal(ConfigFromModel(&cfg, true))
	if err != nil {
		t.Fatal(err)
	}
	var transfer ConfigTransfer
	if err := json.Unmarshal(data, &transfer); err != nil {
		t.Fatal(err)
	}
	original := reflect.ValueOf(&cfg).Elem()
	restored := reflect.ValueOf(transfer.ToModel(nil))
	for i := 0; i < original.NumField(); i++ {
		if original.Type().Field(i).Anonymous {
			continue
		}
		if !reflect.DeepEqual(original.Field(i).Interface(), restored.Field(i).Interface()) {
			t.Errorf("profile field %s changed through the JSON round trip", original.Type().Field(i).Name)
		}
	}
}

// TestConfigFromModelOmitsSecretsByDefault 는 민감 필드가 기본으로 빠지는지 확인한다.
func TestConfigFromModelOmitsSecretsByDefault(t *testing.T) {
	cfg := models.RoboClawConfig{
		Name:              "prod",
		OpenaiApiKey:      "openai-secret",
		AnthropicApiKey:   "anthropic-secret",
		GrpcPeerToken:     "peer-secret",
		McpServersJson:    `[{"name":"fs","command":"npx"}]`,
		System1ApiKey:     "system1-secret",
		LangsmithApiKey:   "langsmith-secret",
		TelegramBotToken:  "telegram-secret",
		AzureOpenaiApiKey: "azure-secret",
	}

	tr := ConfigFromModel(&cfg, false)
	if tr.OpenaiApiKey != nil || tr.AnthropicApiKey != nil || tr.AzureOpenaiApiKey != nil {
		t.Error("LLM API 키는 기본 내보내기에서 빠져야 함")
	}
	if tr.GrpcPeerToken != nil || tr.System1ApiKey != nil || tr.LangsmithApiKey != nil || tr.TelegramBotToken != nil {
		t.Error("민감 토큰은 기본 내보내기에서 빠져야 함")
	}
	if tr.McpServersJson != nil {
		t.Error("MCP 서버 설정은 기본 내보내기에서 빠져야 함")
	}

	data, err := json.Marshal(tr)
	if err != nil {
		t.Fatal(err)
	}
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(data, &fields); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"openai_api_key", "grpc_peer_token", "mcp_servers_json", "system1_api_key"} {
		if _, exists := fields[key]; exists {
			t.Errorf("민감 필드 %s 가 기본 JSON에 포함됨", key)
		}
	}
}

// TestConfigFromModelIncludesSecrets 는 민감 필드 포함 옵션을 확인한다.
func TestConfigFromModelIncludesSecrets(t *testing.T) {
	cfg := models.RoboClawConfig{
		OpenaiApiKey:   "openai-secret",
		GrpcPeerToken:  "peer-secret",
		McpServersJson: `[{"name":"fs","command":"npx"}]`,
	}
	tr := ConfigFromModel(&cfg, true)
	if tr.OpenaiApiKey == nil || *tr.OpenaiApiKey != "openai-secret" {
		t.Fatal("포함 옵션에서는 OpenAI 키가 유지되어야 함")
	}
	if tr.GrpcPeerToken == nil || *tr.GrpcPeerToken != "peer-secret" {
		t.Fatal("포함 옵션에서는 peer 토큰이 유지되어야 함")
	}
	if tr.McpServersJson == nil || *tr.McpServersJson != cfg.McpServersJson {
		t.Fatal("포함 옵션에서는 MCP 서버 설정이 유지되어야 함")
	}

	data, err := json.Marshal(tr)
	if err != nil {
		t.Fatal(err)
	}
	var restored ConfigTransfer
	if err := json.Unmarshal(data, &restored); err != nil {
		t.Fatal(err)
	}
	model := restored.ToModel(nil)
	if model.OpenaiApiKey != "openai-secret" || model.GrpcPeerToken != "peer-secret" {
		t.Error("포함된 민감 값이 왕복 후에도 유지되어야 함")
	}
	if model.McpServersJson != cfg.McpServersJson {
		t.Error("MCP 서버 설정이 왕복 후에도 유지되어야 함")
	}
}

// TestConfigToModelMissingSecretKeepsExisting 는 백업에 없는 민감 필드가
// 기존 서버 값을 덮어쓰지 않는지 확인한다.
func TestConfigToModelMissingSecretKeepsExisting(t *testing.T) {
	var tr ConfigTransfer
	if err := json.Unmarshal([]byte(`{"name":"restored","robot_name":"butler","environment":"office"}`), &tr); err != nil {
		t.Fatal(err)
	}
	existing := &models.RoboClawConfig{
		OpenaiApiKey:   "existing-openai",
		McpServersJson: `[{"name":"existing"}]`,
		GrpcPeerToken:  "existing-peer",
	}
	model := tr.ToModel(existing)
	if model.OpenaiApiKey != existing.OpenaiApiKey {
		t.Error("백업에 없는 API 키는 기존 값을 보존해야 함")
	}
	if model.McpServersJson != existing.McpServersJson {
		t.Error("백업에 없는 MCP 설정은 기존 값을 보존해야 함")
	}
	if model.GrpcPeerToken != existing.GrpcPeerToken {
		t.Error("백업에 없는 peer 토큰은 기존 값을 보존해야 함")
	}

	// 기존 레코드가 없으면 빈 문자열로 채운다.
	fresh := tr.ToModel(nil)
	if fresh.OpenaiApiKey != "" || fresh.McpServersJson != "" || fresh.GrpcPeerToken != "" {
		t.Error("신규 서버에서는 민감 필드가 빈 값이어야 함")
	}
}

// TestConfigToModelExplicitEmptySecretOverrides 는 명시적 빈 값이 기존 값을
// 지우는지 확인한다.
func TestConfigToModelExplicitEmptySecretOverrides(t *testing.T) {
	var tr ConfigTransfer
	if err := json.Unmarshal([]byte(`{"openai_api_key":"","mcp_servers_json":"","grpc_peer_token":""}`), &tr); err != nil {
		t.Fatal(err)
	}
	existing := &models.RoboClawConfig{
		OpenaiApiKey:   "existing-openai",
		McpServersJson: `[{"name":"existing"}]`,
		GrpcPeerToken:  "existing-peer",
	}
	model := tr.ToModel(existing)
	if model.OpenaiApiKey != "" || model.McpServersJson != "" || model.GrpcPeerToken != "" {
		t.Error("명시적 빈 값은 기존 민감 값을 지워야 함")
	}
}

// TestConfigToModelGRPCLegacyDefaults 는 gRPC 필드가 없는 구버전 백업의
// 호환 기본값을 확인한다.
func TestConfigToModelGRPCLegacyDefaults(t *testing.T) {
	var tr ConfigTransfer
	if err := json.Unmarshal([]byte(`{"name":"legacy","robot_name":"butler","environment":"office"}`), &tr); err != nil {
		t.Fatal(err)
	}
	restored := tr.ToModel(nil)
	if restored.GrpcPort != 50052 || restored.GrpcPeerToken != "" {
		t.Error("legacy 백업은 신규 서버에서 호환 기본값을 써야 함")
	}

	existing := &models.RoboClawConfig{GrpcPort: 51052, GrpcPeerToken: "existing-peer-credential"}
	restored = tr.ToModel(existing)
	if restored.GrpcPort != existing.GrpcPort || restored.GrpcPeerToken != existing.GrpcPeerToken {
		t.Error("legacy 백업의 빈 gRPC 필드는 기존 값을 보존해야 함")
	}

	if err := json.Unmarshal([]byte(`{"grpc_port":51052,"grpc_peer_token":""}`), &tr); err != nil {
		t.Fatal(err)
	}
	restored = tr.ToModel(&models.RoboClawConfig{GrpcPort: 50052, GrpcPeerToken: "existing-peer-credential"})
	if restored.GrpcPort != 51052 || restored.GrpcPeerToken != "" {
		t.Error("명시적 값은 기존 포트/토큰을 덮어써야 함")
	}
}

// TestConfigFromModelCleanupDemoDefaults 는 *bool 필드의 기본값과 false 보존을 확인한다.
func TestConfigFromModelCleanupDemoDefaults(t *testing.T) {
	// 신규 레코드: cleanup_demo_enabled 기본값은 true, 나머지 스위치는 false.
	fresh := ConfigFromModel(&models.RoboClawConfig{}, false)
	if fresh.CloidCleanupDemoEnabled == nil || !*fresh.CloidCleanupDemoEnabled {
		t.Error("cloid_cleanup_demo_enabled 기본값은 true 여야 함")
	}
	if fresh.CloidExpressionEnabled == nil || *fresh.CloidExpressionEnabled {
		t.Error("cloid_expression_enabled 기본값은 false 여야 함")
	}
	if fresh.CloidNavigationPoseEnabled == nil || *fresh.CloidNavigationPoseEnabled {
		t.Error("cloid_navigation_pose_enabled 기본값은 false 여야 함")
	}

	// 명시적 false 는 내보내기/가져오기 왕복에서 유지된다.
	off := false
	cfg := models.RoboClawConfig{
		CloidCleanupDemoEnabled:       &off,
		CloidExpressionEnabled:        &off,
		CloidNavigationPoseEnabled:    &off,
		CloidCleanupDemoMotionIDsJson: "[22,60]",
	}
	tr := ConfigFromModel(&cfg, false)
	if tr.CloidCleanupDemoEnabled == nil || *tr.CloidCleanupDemoEnabled {
		t.Fatal("명시적 false 는 내보내기에서 유지되어야 함")
	}
	model := tr.ToModel(nil)
	if model.CloidCleanupDemoEnabled == nil || *model.CloidCleanupDemoEnabled {
		t.Error("명시적 false 는 왕복 후에도 유지되어야 함")
	}
	if model.CloidCleanupDemoMotionIDsJson != "[22,60]" {
		t.Error("cleanup demo motion ID 목록은 그대로 전달되어야 함")
	}

	// 백업에 값이 없으면 기존 레코드의 false 를 보존하고,
	// 신규 레코드에는 기본값 true 를 쓴다.
	var absent ConfigTransfer
	if model := absent.ToModel(&models.RoboClawConfig{CloidCleanupDemoEnabled: &off}); model.CloidCleanupDemoEnabled == nil || *model.CloidCleanupDemoEnabled {
		t.Error("기존 레코드의 false 가 보존되어야 함")
	}
	if model := absent.ToModel(nil); model.CloidCleanupDemoEnabled == nil || !*model.CloidCleanupDemoEnabled {
		t.Error("신규 레코드는 기본값 true 를 써야 함")
	}
}
