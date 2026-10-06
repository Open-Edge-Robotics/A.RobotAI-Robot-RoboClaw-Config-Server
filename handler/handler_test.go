package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"

	"ai-config-server/config"
	"ai-config-server/database"
	"ai-config-server/database/models"
	"github.com/gin-gonic/gin"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func init() {
	gin.SetMode(gin.TestMode)
}

func TestPing(t *testing.T) {
	r := gin.New()
	r.GET("/ping", Ping)

	req := httptest.NewRequest("GET", "/ping", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var resp map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}

	if resp["message"] != "pong" {
		t.Errorf("Expected 'pong', got %q", resp["message"])
	}
}

func TestRequireAdmin(t *testing.T) {
	cfg := &config.Config{}
	cfg.Security.AdminToken = "super-admin"

	r := gin.New()
	r.Use(RequireAdmin(cfg))
	r.GET("/admin-data", func(c *gin.Context) {
		c.String(http.StatusOK, "secret-data")
	})

	// 1. 토큰 누락 시 401 반환 검사
	req := httptest.NewRequest("GET", "/admin-data", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401 on missing token, got %d", w.Code)
	}

	// 2. 올바르지 않은 토큰 시 401 반환 검사
	req = httptest.NewRequest("GET", "/admin-data", nil)
	req.Header.Set("Authorization", "Bearer invalid-token")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401 on invalid token, got %d", w.Code)
	}

	// 3. 올바른 토큰 시 200 통과 검사
	req = httptest.NewRequest("GET", "/admin-data", nil)
	req.Header.Set("Authorization", "Bearer super-admin")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200 on valid token, got %d", w.Code)
	}
}

func TestValidateJSONFields(t *testing.T) {
	// 1. 올바른 JSON
	err := validateJSONFields(`{"speed": 1.2}`, `{"num_ctx": 2048}`, `[]`, `[]`, `[]`, `[]`)
	if err != nil {
		t.Errorf("Expected nil error for valid JSON, got %v", err)
	}

	// 2. 비어있는 문자열 (허용)
	err = validateJSONFields("", "", "", "", "", "")
	if err != nil {
		t.Errorf("Expected nil error for empty strings, got %v", err)
	}

	// 3. 올바르지 않은 limits JSON
	err = validateJSONFields(`{"speed": 1.2`, `{"num_ctx": 2048}`, `[]`, `[]`, `[]`, `[]`)
	if err == nil {
		t.Error("Expected error for invalid limits JSON, got nil")
	}

	// 4. 올바르지 않은 ollama options JSON
	err = validateJSONFields(`{"speed": 1.2}`, `{"num_ctx": 2048`, `[]`, `[]`, `[]`, `[]`)
	if err == nil {
		t.Error("Expected error for invalid ollama options JSON, got nil")
	}
}

func TestValidateJSONFieldsSystem1Thresholds(t *testing.T) {
	if err := validateJSONFields("", "", "", "", "", "", "", `{"skill":0.8}`); err != nil {
		t.Fatalf("expected valid System 1 thresholds object, got %v", err)
	}
	if err := validateJSONFields("", "", "", "", "", "", "", `[]`); err == nil {
		t.Fatal("expected System 1 thresholds to reject a non-object JSON value")
	}
	if err := validateRuntimeValues(&models.RoboClawConfig{
		System1ConfThresholdsJson: `{"skill":1.2}`,
	}); err == nil {
		t.Fatal("expected out-of-range System 1 confidence threshold to be rejected")
	}
}

func TestValidateJSONFieldsMcpServers(t *testing.T) {
	// 1. 올바른 stdio 서버 배열
	err := validateJSONFields("", "", "", "", "", `[{"name":"fs","transport":"stdio","command":"npx"}]`)
	if err != nil {
		t.Errorf("Expected nil error for valid mcp_servers_json, got %v", err)
	}

	// 2. 비어있는 문자열 (허용)
	err = validateJSONFields("", "", "", "", "", "")
	if err != nil {
		t.Errorf("Expected nil error for empty mcp_servers_json, got %v", err)
	}

	// 3. 올바르지 않은 JSON
	err = validateJSONFields("", "", "", "", "", `[{"name":"fs"`)
	if err == nil {
		t.Error("Expected error for invalid mcp_servers_json, got nil")
	} else if !strings.Contains(err.Error(), "mcp_servers_json") {
		t.Errorf("expected error to mention mcp_servers_json, got %v", err)
	}
}

func setupHandlerTestDB(t *testing.T) {
	t.Helper()

	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("failed to open test db: %v", err)
	}
	if err := db.AutoMigrate(&models.RoboClawConfig{}, &models.TestScenario{}); err != nil {
		t.Fatalf("failed to migrate test db: %v", err)
	}
	database.DB = db
}

func TestCreateConfigKeepsSingleActivePerRobotEnvironment(t *testing.T) {
	setupHandlerTestDB(t)

	r := gin.New()
	r.POST("/configs", CreateConfig)

	for _, name := range []string{"first", "second"} {
		body := []byte(`{"name":"` + name + `","robot_name":"butler","environment":"office","is_active":true,"limits_content":"{}"}`)
		req := httptest.NewRequest("POST", "/configs", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusCreated {
			t.Fatalf("expected status 201, got %d: %s", w.Code, w.Body.String())
		}
	}

	var activeCount int64
	if err := database.DB.Model(&models.RoboClawConfig{}).
		Where("robot_name = ? AND environment = ? AND is_active = ?", "butler", "office", true).
		Count(&activeCount).Error; err != nil {
		t.Fatal(err)
	}
	if activeCount != 1 {
		t.Fatalf("expected one active config, got %d", activeCount)
	}
}

// GORM은 struct 필드에 gorm:"default:X" 태그가 있으면, 저장 시점에 그 필드 값이
// Go 타입의 zero-value와 같을 경우 해당 컬럼을 INSERT 문에서 생략하고 DB
// DEFAULT 값으로 대체한다. bool 필드의 zero-value는 false이므로, 애플리케이션
// 기본값이 true인 bool 필드에 gorm:"default:true"를 달면 사용자가 명시적으로
// false를 저장해도 조용히 true로 되돌아가는 문제가 생긴다(enable_grpc,
// enable_task_decomposition에서 실제로 발견됨). 이 테스트는 실제 HTTP 핸들러 →
// GORM Create → DB 재조회 전 구간을 거쳐 명시적 false가 그대로 보존되는지
// 검증해 동일한 버그의 재발을 막는다.
func TestCreateConfigPreservesExplicitFalseForBoolDefaults(t *testing.T) {
	setupHandlerTestDB(t)

	r := gin.New()
	r.POST("/configs", CreateConfig)

	body := []byte(`{
		"name": "bool-default-regression",
		"robot_name": "butler",
		"environment": "office",
		"limits_content": "{}",
		"enable_grpc": false,
		"enable_task_decomposition": false
	}`)
	req := httptest.NewRequest("POST", "/configs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d: %s", w.Code, w.Body.String())
	}

	var saved models.RoboClawConfig
	if err := database.DB.Where("name = ?", "bool-default-regression").First(&saved).Error; err != nil {
		t.Fatalf("failed to reload saved config: %v", err)
	}

	if saved.EnableGrpc {
		t.Errorf("expected enable_grpc to remain false, got true")
	}
	if saved.EnableTaskDecomposition {
		t.Errorf("expected enable_task_decomposition to remain false, got true")
	}
}

func TestCreateScenarioKeepsSingleActivePerRobotEnvironment(t *testing.T) {
	setupHandlerTestDB(t)

	r := gin.New()
	r.POST("/scenarios", CreateTestScenario)

	for _, name := range []string{"first", "second"} {
		body := []byte(`{"name":"` + name + `","robot_name":"butler","environment":"office","is_active":true,"test_cases":[]}`)
		req := httptest.NewRequest("POST", "/scenarios", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusCreated {
			t.Fatalf("expected status 201, got %d: %s", w.Code, w.Body.String())
		}
	}

	var activeCount int64
	if err := database.DB.Model(&models.TestScenario{}).
		Where("robot_name = ? AND environment = ? AND is_active = ?", "butler", "office", true).
		Count(&activeCount).Error; err != nil {
		t.Fatal(err)
	}
	if activeCount != 1 {
		t.Fatalf("expected one active scenario, got %d", activeCount)
	}
}

func TestBuildEnvContentIncludesEmbeddingProviderSettings(t *testing.T) {
	cfg := models.RoboClawConfig{
		RobotName:            "former",
		Environment:          "local",
		RosDomainId:          35,
		LlmProvider:          "ollama",
		LlmModel:             "gemma4:e4b",
		EnableRag:            true,
		LlmEmbeddingProvider: "openai",
		LlmEmbeddingModel:    "text-embedding-3-large",
		LlmEmbeddingBaseUrl:  "https://api.openai.com/v1",
		LlmEmbeddingApiKey:   "embed-key",
		RagVectorBackend:     "qdrant",
		QdrantUrl:            "http://qdrant:6333",
		QdrantCollection:     "robo_claw_former_local",
		RagTopK:              2,
		RagScoreThreshold:    0.7,
		QdrantTimeoutSec:     5.0,
		RagLocalMirror:       true,
		GrpcTargetPeersJson:  "[]",
	}

	env := generateEnvContent(&cfg)
	for _, want := range []string{
		"RC_LLM_EMBEDDING_PROVIDER=openai",
		"RC_LLM_EMBEDDING_MODEL=text-embedding-3-large",
		"RC_LLM_EMBEDDING_BASE_URL=https://api.openai.com/v1",
		"RC_LLM_EMBEDDING_API_KEY=embed-key",
	} {
		if !strings.Contains(env, want) {
			t.Fatalf("expected env to contain %q\nactual:\n%s", want, env)
		}
	}
}

func TestBuildEnvContentIncludesDefaultButlerPaths(t *testing.T) {
	cfg := models.RoboClawConfig{
		RobotName:           "butler",
		Environment:         "office",
		RosDomainId:         30,
		LlmProvider:         "azure",
		LlmModel:            "gpt-4o",
		GrpcTargetPeersJson: "[]",
	}

	env := generateEnvContent(&cfg)
	for _, want := range []string{
		"RC_BUTLER_SCRIPTS_DIR=/home/seoyc/Workspace/ros/butler/products/prd_butler_v01_magok_w02/script",
		"RC_BUTLER_SOURCE_DIR=/home/udr/workspace/butler_v01_config/cloi2_ws",
	} {
		if !strings.Contains(env, want) {
			t.Fatalf("expected env to contain %q\nactual:\n%s", want, env)
		}
	}
}

func TestBuildEnvContentIncludesMcpSettings(t *testing.T) {
	cfg := models.RoboClawConfig{
		RobotName:           "former",
		Environment:         "local",
		LlmProvider:         "azure",
		LlmModel:            "gpt-4o",
		GrpcTargetPeersJson: "[]",
		EnableMcp:           true,
		McpServersJson:      `[{"name":"fs","transport":"stdio","command":"npx","args":["-y","@modelcontextprotocol/server-filesystem"]}]`,
	}

	env := generateEnvContent(&cfg)
	for _, want := range []string{
		"RC_ENABLE_MCP=true",
		`RC_MCP_SERVERS_JSON=[{"name":"fs","transport":"stdio","command":"npx","args":["-y","@modelcontextprotocol/server-filesystem"]}]`,
	} {
		if !strings.Contains(env, want) {
			t.Fatalf("expected env to contain %q\nactual:\n%s", want, env)
		}
	}
}

func TestBuildEnvContentOmitsMcpServersWhenEmpty(t *testing.T) {
	cfg := models.RoboClawConfig{
		RobotName:           "former",
		Environment:         "local",
		LlmProvider:         "azure",
		LlmModel:            "gpt-4o",
		GrpcTargetPeersJson: "[]",
		EnableMcp:           false,
		McpServersJson:      "[]",
	}

	env := generateEnvContent(&cfg)
	if !strings.Contains(env, "RC_ENABLE_MCP=false") {
		t.Fatalf("expected env to contain RC_ENABLE_MCP=false\nactual:\n%s", env)
	}
	if strings.Contains(env, "RC_MCP_SERVERS_JSON=") {
		t.Fatalf("expected env to omit RC_MCP_SERVERS_JSON when empty\nactual:\n%s", env)
	}
}

func TestBuildEnvContentIncludesTaskDecompositionSettings(t *testing.T) {
	cfg := models.RoboClawConfig{
		RobotName:                         "former",
		Environment:                       "local",
		LlmProvider:                       "azure",
		LlmModel:                          "gpt-4o",
		GrpcTargetPeersJson:               "[]",
		TaskQueueMaxSize:                  4,
		LlmFailFast:                       true,
		StrictConfig:                      true,
		EnableTaskDecomposition:           false,
		TaskDecompositionMaxSteps:         8,
		TaskStepMaxRetries:                2,
		TaskDecompositionWaitMarginCapSec: 900.0,
	}

	env := generateEnvContent(&cfg)
	for _, want := range []string{
		"RC_TASK_QUEUE_MAX_SIZE=4",
		"RC_LLM_FAIL_FAST=true",
		"RC_STRICT_CONFIG=true",
		"RC_ENABLE_TASK_DECOMPOSITION=false",
		"RC_TASK_DECOMPOSITION_MAX_STEPS=8",
		"RC_TASK_STEP_MAX_RETRIES=2",
		"RC_TASK_DECOMPOSITION_WAIT_MARGIN_CAP_SEC=900",
	} {
		if !strings.Contains(env, want) {
			t.Fatalf("expected env to contain %q\nactual:\n%s", want, env)
		}
	}
}

func TestBuildEnvContentIncludesStretchGripperCameraSettings(t *testing.T) {
	cfg := models.RoboClawConfig{
		RobotName:                   "stretch3",
		Environment:                 "lab",
		LlmProvider:                 "azure",
		LlmModel:                    "gpt-4o",
		GrpcTargetPeersJson:         "[]",
		CameraTopic:                 "/camera/color/image_raw",
		UseVision:                   true,
		GripperCameraTopic:          "/gripper_camera/color/image_rect_raw",
		GripperDepthTopic:           "/gripper_camera/aligned_depth_to_color/image_raw",
		GripperCameraInfoTopic:      "/gripper_camera/aligned_depth_to_color/camera_info",
		GripperPointcloudTopic:      "/gripper_camera/depth/color/points",
		UseGripperVision:            true,
		GripperVisionMaxInferenceHz: 5.0,
	}

	env := generateEnvContent(&cfg)
	for _, want := range []string{
		"RC_CAMERA_TOPIC=/camera/color/image_raw",
		"RC_GRIPPER_CAMERA_TOPIC=/gripper_camera/color/image_rect_raw",
		"RC_GRIPPER_DEPTH_TOPIC=/gripper_camera/aligned_depth_to_color/image_raw",
		"RC_GRIPPER_CAMERA_INFO_TOPIC=/gripper_camera/aligned_depth_to_color/camera_info",
		"RC_GRIPPER_POINTCLOUD_TOPIC=/gripper_camera/depth/color/points",
		"RC_USE_VISION=true",
		"RC_USE_GRIPPER_VISION=true",
		"RC_GRIPPER_VISION_MAX_INFERENCE_HZ=5",
	} {
		if !strings.Contains(env, want) {
			t.Fatalf("expected env to contain %q\nactual:\n%s", want, env)
		}
	}
}

// TestMaskSensitiveFieldsKeepsMcpServersVisibleWithMaskedCredentials 는 MCP 서버
// 목록이 응답에서 사라지지 않고(구조 유지) 자격 증명만 마스킹되는지 검증한다.
// 이전에는 JSON 전체가 "********" 로 치환되어 등록한 서버가 대시보드에 보이지 않았다.
func TestMaskSensitiveFieldsKeepsMcpServersVisibleWithMaskedCredentials(t *testing.T) {
	cfg := models.RoboClawConfig{
		McpServersJson: `[{"name":"fs","transport":"stdio","command":"npx","env":{"TOKEN":"secret"}}]`,
	}
	maskSensitiveFields(&cfg)

	var servers []struct {
		Name    string            `json:"name"`
		Command string            `json:"command"`
		Env     map[string]string `json:"env"`
	}
	if err := json.Unmarshal([]byte(cfg.McpServersJson), &servers); err != nil {
		t.Fatalf("expected MCP servers to stay visible, got %q: %v", cfg.McpServersJson, err)
	}
	if len(servers) != 1 || servers[0].Name != "fs" || servers[0].Command != "npx" {
		t.Errorf("expected server structure preserved, got %q", cfg.McpServersJson)
	}
	if servers[0].Env["TOKEN"] != MaskValue {
		t.Errorf("expected env credential masked, got %q", servers[0].Env["TOKEN"])
	}

	emptyCfg := models.RoboClawConfig{McpServersJson: "[]"}
	maskSensitiveFields(&emptyCfg)
	if emptyCfg.McpServersJson != "[]" {
		t.Errorf("expected empty mcp_servers_json to be left untouched, got %q", emptyCfg.McpServersJson)
	}
}

func TestUpdateConfigPreservesMaskedMcpServersJson(t *testing.T) {
	setupHandlerTestDB(t)

	r := gin.New()
	r.POST("/configs", CreateConfig)
	r.PUT("/configs/:id", UpdateConfig)

	original := `[{"name":"fs","transport":"stdio","command":"npx"}]`
	createBody, err := json.Marshal(map[string]interface{}{
		"name":             "mcp-test",
		"robot_name":       "butler",
		"environment":      "office",
		"enable_mcp":       true,
		"mcp_servers_json": original,
	})
	if err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest("POST", "/configs", bytes.NewReader(createBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d: %s", w.Code, w.Body.String())
	}

	var created models.RoboClawConfig
	if err := json.Unmarshal(w.Body.Bytes(), &created); err != nil {
		t.Fatal(err)
	}

	// 마스킹된 값을 그대로 되돌려보내는 업데이트 요청 (다른 필드만 변경)
	updateBody, err := json.Marshal(map[string]interface{}{
		"name":             "mcp-test-renamed",
		"robot_name":       "butler",
		"environment":      "office",
		"enable_mcp":       true,
		"mcp_servers_json": "********",
	})
	if err != nil {
		t.Fatal(err)
	}
	req = httptest.NewRequest("PUT", "/configs/"+strconv.Itoa(int(created.ID)), bytes.NewReader(updateBody))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var stored models.RoboClawConfig
	if err := database.DB.First(&stored, created.ID).Error; err != nil {
		t.Fatal(err)
	}
	if stored.McpServersJson != original {
		t.Errorf("expected mcp_servers_json to be preserved as %q, got %q", original, stored.McpServersJson)
	}
}

func TestBuildEnvContentUsesConfiguredButlerPaths(t *testing.T) {
	cfg := models.RoboClawConfig{
		RobotName:           "butler",
		Environment:         "office",
		RosDomainId:         30,
		LlmProvider:         "azure",
		LlmModel:            "gpt-4o",
		GrpcTargetPeersJson: "[]",
		ButlerScriptsDir:    "/custom/scripts",
		ButlerSourceDir:     "/custom/source",
	}

	env := generateEnvContent(&cfg)
	for _, want := range []string{
		"RC_BUTLER_SCRIPTS_DIR=/custom/scripts",
		"RC_BUTLER_SOURCE_DIR=/custom/source",
	} {
		if !strings.Contains(env, want) {
			t.Fatalf("expected env to contain %q\nactual:\n%s", want, env)
		}
	}
}

func TestListConfigsWithoutQueryParams(t *testing.T) {
	setupHandlerTestDB(t)

	// 테스트용 데이터 2개 생성
	cfg1 := models.RoboClawConfig{Name: "cfg-1", RobotName: "butler", Environment: "office"}
	cfg2 := models.RoboClawConfig{Name: "cfg-2", RobotName: "former", Environment: "factory"}
	database.DB.Create(&cfg1)
	database.DB.Create(&cfg2)

	r := gin.New()
	r.GET("/configs", ListConfigs)

	// 1. 파라미터 없이 전체 목록 조회
	req := httptest.NewRequest("GET", "/configs", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200 without query params, got %d: %s", w.Code, w.Body.String())
	}

	var configs []models.RoboClawConfig
	if err := json.Unmarshal(w.Body.Bytes(), &configs); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}
	if len(configs) != 2 {
		t.Fatalf("expected 2 configs, got %d", len(configs))
	}

	// 2. robot_name 필터 사용 조회
	req = httptest.NewRequest("GET", "/configs?robot_name=butler", nil)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200 with robot_name filter, got %d", w.Code)
	}
	configs = nil
	if err := json.Unmarshal(w.Body.Bytes(), &configs); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}
	if len(configs) != 1 || configs[0].RobotName != "butler" {
		t.Fatalf("expected 1 butler config, got %v", configs)
	}
}
