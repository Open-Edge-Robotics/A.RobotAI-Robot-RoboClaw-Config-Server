package database

import (
	"embed"
	"fmt"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"

	"ai-config-server/database/models"
)

//go:embed seeds/*
var seedFS embed.FS

var DB *gorm.DB

// Init DB를 초기화하고 AutoMigrate를 실행한다
func Init(dsn string) error {
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
		SkipDefaultTransaction: true,
	})
	if err != nil {
		return fmt.Errorf("DB 연결 실패: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return fmt.Errorf("SQL DB 객체 획득 실패: %w", err)
	}

	// SQLite 동시 접근 안정성 확보를 위한 WAL 모드 및 대기 타임아웃 활성화
	if _, err := sqlDB.Exec("PRAGMA journal_mode=WAL;"); err != nil {
		return fmt.Errorf("WAL 모드 설정 실패: %w", err)
	}
	if _, err := sqlDB.Exec("PRAGMA busy_timeout=5000;"); err != nil {
		return fmt.Errorf("busy_timeout 설정 실패: %w", err)
	}

	// SQLite의 쓰기 락 충돌 방지를 위해 최대 커넥션을 1개로 한정
	sqlDB.SetMaxOpenConns(1)

	if err := db.AutoMigrate(&models.RoboClawConfig{}, &models.TestScenario{}); err != nil {
		return fmt.Errorf("AutoMigrate 실패: %w", err)
	}

	DB = db
	if err := seedData(db); err != nil {
		return fmt.Errorf("초기 데이터 시드 실패: %w", err)
	}
	return nil
}

func seedData(db *gorm.DB) error {
	var count int64
	if err := db.Model(&models.RoboClawConfig{}).Count(&count).Error; err != nil {
		return fmt.Errorf("기존 설정 개수 조회 실패: %w", err)
	}
	if count > 0 {
		return nil
	}

	// 내장된 시드 파일 읽기 헬퍼
	readSeedFile := func(filename string, defaultVal string) string {
		data, err := seedFS.ReadFile("seeds/" + filename)
		if err != nil {
			return defaultVal
		}
		return string(data)
	}

	// Butler 설정 Seed
	butlerSoul := readSeedFile("ROBOT.md", "# 로봇 소울 프로필\n\n## 나는 누구인가\n나의 이름은 Claw(Butler)이다.")
	butlerSkills := readSeedFile("SKILLS.butler.md", "# 버틀러 스킬 가이드")
	butlerTrouble := readSeedFile("TROUBLESHOOTING.md", "# 장애 조치 가이드")
	butlerLimits := readSeedFile("ROBOT_LIMITS.json", `{"max_linear_speed": 0.5, "max_angular_speed": 1.0}`)

	butlerConfig := models.RoboClawConfig{
		Name:                            "Butler_Office_Standard",
		RobotName:                       "butler",
		Environment:                     "office",
		IsActive:                        true,
		Description:                     "사무실 환경 내 AI Butler 에이전트 기본 설정값",
		RosDomainId:                     30,
		LlmProvider:                     "azure",
		LlmModel:                        "gpt-4o",
		AzureOpenaiEndpoint:             "https://robot-open-ai.openai.azure.com/",
		AzureOpenaiApiKey:               "",
		EnableRag:                       true,
		LlmEmbeddingModel:               "text-embedding-3-small",
		LlmEmbeddingProvider:            "azure",
		LlmEmbeddingBaseUrl:             "https://robot-open-ai.openai.azure.com/",
		RagVectorBackend:                "qdrant",
		QdrantUrl:                       "http://10.159.172.74:6333",
		QdrantCollection:                "robo_claw_sim_azure",
		EnableGrpc:                      true,
		EnableGrpcClient:                false,
		GrpcTargetHost:                  "127.0.0.1",
		GrpcTargetPort:                  50051,
		GrpcTargetPeersJson:             "[]",
		SoulContent:                     butlerSoul,
		SkillsContent:                   butlerSkills,
		TroubleshootingContent:          butlerTrouble,
		LimitsContent:                   butlerLimits,
		ButlerScriptsDir:                "/home/seoyc/Workspace/ros/butler/products/prd_butler_v01_magok_w02/script",
		ButlerSourceDir:                 "/home/udr/workspace/butler_v01_config/cloi2_ws",
		EnableSkillLearning:             false,
		SkillLearningSuccessSampleRate:  0.1,
		SkillLearningReflectIntervalSec: 1800,
		LangsmithTracing:                false,
		LangsmithApiKey:                 "",
		LangsmithProject:                "former-0045-claw",
	}
	if err := db.Create(&butlerConfig).Error; err != nil {
		return fmt.Errorf("Butler 기본 설정 시드 실패: %w", err)
	}

	// Former 설정 Seed
	formerSkills := readSeedFile("SKILLS.former.md", "# Former 이송 로봇 스킬")
	formerConfig := models.RoboClawConfig{
		Name:                            "Former_Factory_Standard",
		RobotName:                       "former",
		Environment:                     "factory",
		IsActive:                        true,
		Description:                     "공장 환경 전용 Former 이송 로봇 기본 설정값 (Ollama 로컬 LLM 구동)",
		RosDomainId:                     35,
		LlmProvider:                     "ollama",
		LlmModel:                        "gemma4:e4b",
		OllamaBaseUrl:                   "http://10.159.172.75:11434",
		OllamaOptionsJson:               `{"num_ctx": 8192, "temperature": 0.2}`,
		EnableRag:                       false,
		EnableGrpc:                      true,
		EnableGrpcClient:                false,
		GrpcTargetHost:                  "127.0.0.1",
		GrpcTargetPort:                  50051,
		GrpcTargetPeersJson:             "[]",
		SoulContent:                     "# 로봇 소울 프로필\n\n나의 이름은 Former이고, 공장 내부 물품 운송 에이전트이다.",
		SkillsContent:                   formerSkills,
		TroubleshootingContent:          butlerTrouble,
		LimitsContent:                   `{"max_linear_speed": 1.2, "max_angular_speed": 1.5}`,
		EnableSkillLearning:             false,
		SkillLearningSuccessSampleRate:  0.1,
		SkillLearningReflectIntervalSec: 1800,
		LangsmithTracing:                false,
		LangsmithApiKey:                 "",
		LangsmithProject:                "former-0045-claw",
	}
	if err := db.Create(&formerConfig).Error; err != nil {
		return fmt.Errorf("Former 기본 설정 시드 실패: %w", err)
	}

	var scenarioCount int64
	if err := db.Model(&models.TestScenario{}).Count(&scenarioCount).Error; err != nil {
		return fmt.Errorf("기존 시나리오 개수 조회 실패: %w", err)
	}
	if scenarioCount == 0 {
		// Butler 디폴트 시나리오
		butlerScenario := models.TestScenario{
			Name:        "Butler 기본 테스트 시나리오",
			Description: "gRPC 연결성부터 AI 페르소나 능력까지 검증하는 Butler용 표준 시나리오",
			RobotName:   "butler",
			Environment: "office",
			IsActive:    true,
			TestCases: []models.TestCase{
				{ID: "tc_ping", Name: "gRPC Ping 연결성", Step: "Step 1", Type: "ping", TimeoutMs: 3000, Enabled: true},
				{ID: "tc_robot_info", Name: "로봇 정보 조회 및 정합성", Step: "Step 1", Type: "robot_info", TimeoutMs: 3000, Enabled: true},
				{ID: "tc_battery", Name: "배터리 상태 점검", Step: "Step 1", Type: "battery", TimeoutMs: 10000, Enabled: true},
				{ID: "tc_camera", Name: "카메라 이미지 획득", Step: "Step 2", Type: "camera", TimeoutMs: 5000, Enabled: true},
				{ID: "tc_slam_map", Name: "SLAM 지도 맵 수신", Step: "Step 2", Type: "map", TimeoutMs: 5000, Enabled: true},
				{ID: "tc_camera_analysis", Name: "카메라 이미지 분석 및 전달 스킬", Step: "Step 2", Type: "camera_analysis", TimeoutMs: 25000, Enabled: true},
				{ID: "tc_map_analysis", Name: "맵 이미지 분석 및 전달 스킬", Step: "Step 2", Type: "map_analysis", TimeoutMs: 25000, Enabled: true},
				{ID: "tc_guardrail", Name: "물리 가드레일 속도 제약", Step: "Step 3", Type: "navigation", TimeoutMs: 15000, Enabled: true, Params: map[string]any{"mode": "guardrail", "speed": 0.05}},
				{ID: "tc_motion_chat", Name: "자연어 기반 주행 스킬 기동", Step: "Step 3", Type: "navigation", TimeoutMs: 15000, Enabled: true, Params: map[string]any{"mode": "motion"}},
				{ID: "tc_joint_control", Name: "매니퓰레이션 관절 구동 검증", Step: "Step 3", Type: "manipulation", TimeoutMs: 15000, Enabled: true},
				{ID: "tc_persona", Name: "LLM 페르소나 및 응답 지능", Step: "Step 4", Type: "persona", TimeoutMs: 15000, Enabled: true, Params: map[string]any{"prompt": "너의 정체성과 성격에 대해 한 문장으로 답변해줘."}},
			},
		}
		if err := db.Create(&butlerScenario).Error; err != nil {
			return fmt.Errorf("Butler 기본 시나리오 시드 실패: %w", err)
		}

		// Former 디폴트 시나리오
		formerScenario := models.TestScenario{
			Name:        "Former 기본 테스트 시나리오",
			Description: "gRPC 연결성 및 AI 페르소나 능력을 검증하는 Former용 표준 시나리오 (매니퓰레이션 비활성)",
			RobotName:   "former",
			Environment: "factory",
			IsActive:    true,
			TestCases: []models.TestCase{
				{ID: "tc_ping", Name: "gRPC Ping 연결성", Step: "Step 1", Type: "ping", TimeoutMs: 3000, Enabled: true},
				{ID: "tc_robot_info", Name: "로봇 정보 조회 및 정합성", Step: "Step 1", Type: "robot_info", TimeoutMs: 3000, Enabled: true},
				{ID: "tc_battery", Name: "배터리 상태 점검", Step: "Step 1", Type: "battery", TimeoutMs: 10000, Enabled: true},
				{ID: "tc_camera", Name: "카메라 이미지 획득", Step: "Step 2", Type: "camera", TimeoutMs: 5000, Enabled: true},
				{ID: "tc_slam_map", Name: "SLAM 지도 맵 수신", Step: "Step 2", Type: "map", TimeoutMs: 5000, Enabled: true},
				{ID: "tc_camera_analysis", Name: "카메라 이미지 분석 및 전달 스킬", Step: "Step 2", Type: "camera_analysis", TimeoutMs: 25000, Enabled: true},
				{ID: "tc_map_analysis", Name: "맵 이미지 분석 및 전달 스킬", Step: "Step 2", Type: "map_analysis", TimeoutMs: 25000, Enabled: true},
				{ID: "tc_guardrail", Name: "물리 가드레일 속도 제약", Step: "Step 3", Type: "navigation", TimeoutMs: 15000, Enabled: true, Params: map[string]any{"mode": "guardrail", "speed": 0.05}},
				{ID: "tc_motion_chat", Name: "자연어 기반 주행 스킬 기동", Step: "Step 3", Type: "navigation", TimeoutMs: 15000, Enabled: true, Params: map[string]any{"mode": "motion"}},
				{ID: "tc_joint_control", Name: "매니퓰레이션 관절 구동 검증", Step: "Step 3", Type: "manipulation", TimeoutMs: 15000, Enabled: false}, // Former는 매니퓰레이션 비활성
				{ID: "tc_persona", Name: "LLM 페르소나 및 응답 지능", Step: "Step 4", Type: "persona", TimeoutMs: 15000, Enabled: true, Params: map[string]any{"prompt": "너의 정체성과 성격에 대해 한 문장으로 답변해줘."}},
			},
		}
		if err := db.Create(&formerScenario).Error; err != nil {
			return fmt.Errorf("Former 기본 시나리오 시드 실패: %w", err)
		}

		// Default 공통 시나리오
		defaultScenario := models.TestScenario{
			Name:        "기본 공통 테스트 시나리오",
			Description: "로봇 및 환경에 구애받지 않고 범용으로 사용할 수 있는 기본 테스트 시나리오",
			RobotName:   "default",
			Environment: "default",
			IsActive:    true,
			TestCases: []models.TestCase{
				{ID: "tc_ping", Name: "gRPC Ping 연결성", Step: "Step 1", Type: "ping", TimeoutMs: 3000, Enabled: true},
				{ID: "tc_robot_info", Name: "로봇 정보 조회 및 정합성", Step: "Step 1", Type: "robot_info", TimeoutMs: 3000, Enabled: true},
				{ID: "tc_battery", Name: "배터리 상태 점검", Step: "Step 1", Type: "battery", TimeoutMs: 10000, Enabled: true},
				{ID: "tc_camera", Name: "카메라 이미지 획득", Step: "Step 2", Type: "camera", TimeoutMs: 5000, Enabled: true},
				{ID: "tc_slam_map", Name: "SLAM 지도 맵 수신", Step: "Step 2", Type: "map", TimeoutMs: 5000, Enabled: true},
				{ID: "tc_camera_analysis", Name: "카메라 이미지 분석 및 전달 스킬", Step: "Step 2", Type: "camera_analysis", TimeoutMs: 25000, Enabled: true},
				{ID: "tc_map_analysis", Name: "맵 이미지 분석 및 전달 스킬", Step: "Step 2", Type: "map_analysis", TimeoutMs: 25000, Enabled: true},
				{ID: "tc_guardrail", Name: "물리 가드레일 속도 제약", Step: "Step 3", Type: "navigation", TimeoutMs: 15000, Enabled: true, Params: map[string]any{"mode": "guardrail", "speed": 0.05}},
				{ID: "tc_motion_chat", Name: "자연어 기반 주행 스킬 기동", Step: "Step 3", Type: "navigation", TimeoutMs: 15000, Enabled: true, Params: map[string]any{"mode": "motion"}},
				{ID: "tc_joint_control", Name: "매니퓰레이션 관절 구동 검증", Step: "Step 3", Type: "manipulation", TimeoutMs: 15000, Enabled: true},
				{ID: "tc_persona", Name: "LLM 페르소나 및 응답 지능", Step: "Step 4", Type: "persona", TimeoutMs: 15000, Enabled: true, Params: map[string]any{"prompt": "너의 정체성과 성격에 대해 한 문장으로 답변해줘."}},
			},
		}
		if err := db.Create(&defaultScenario).Error; err != nil {
			return fmt.Errorf("기본 공통 시나리오 시드 실패: %w", err)
		}
	}

	return nil
}
