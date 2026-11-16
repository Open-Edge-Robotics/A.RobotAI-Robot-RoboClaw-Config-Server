package transfer

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"

	"ai-config-server/database/models"
	"ai-config-server/service"
)

// ============================================================================
// 백업 문서 식별자와 가져오기 정책 값
//
// handler 는 이 값을 그대로 재사용해 공개 상수(BackupKind 등)를 유지한다.
// ============================================================================

const (
	Kind          = "ai-config-server.portable-backup"
	SchemaVersion = 1

	ConflictSkip      = "skip"
	ConflictOverwrite = "overwrite"
	ConflictCopy      = "copy"

	ActivationInactive     = "inactive"
	ActivationPreserve     = "preserve"
	ActivationKeepExisting = "keep_existing"
)

// Document 백업 파일 최상위 구조.
// JSON 계약은 handler 의 BackupDocument 와 동일하게 유지한다.
type Document struct {
	Kind            string             `json:"kind"`
	SchemaVersion   int                `json:"schema_version"`
	ExportedAt      time.Time          `json:"exported_at"`
	IncludesSecrets bool               `json:"includes_secrets"`
	Configs         []ConfigTransfer   `json:"configs"`
	Scenarios       []ScenarioTransfer `json:"scenarios"`
}

// ImportSummary 검증 요약.
type ImportSummary struct {
	Configs              int `json:"configs"`
	Scenarios            int `json:"scenarios"`
	NewConfigs           int `json:"new_configs"`
	ConflictingConfigs   int `json:"conflicting_configs"`
	NewScenarios         int `json:"new_scenarios"`
	ConflictingScenarios int `json:"conflicting_scenarios"`
}

// Validation 가져오기 검증 결과.
type Validation struct {
	Valid           bool          `json:"valid"`
	SchemaVersion   int           `json:"schema_version"`
	IncludesSecrets bool          `json:"includes_secrets"`
	Summary         ImportSummary `json:"summary"`
	Warnings        []string      `json:"warnings"`
	Errors          []string      `json:"errors"`
}

// ImportActionResult 가져오기 실행 단위 결과.
type ImportActionResult struct {
	Created int `json:"created"`
	Updated int `json:"updated"`
	Skipped int `json:"skipped"`
}

// Result 가져오기 실행 전체 결과.
type Result struct {
	Configs   ImportActionResult `json:"configs"`
	Scenarios ImportActionResult `json:"scenarios"`
}

// ErrConfigsLoad/ErrScenariosLoad 는 기존 데이터 조회 실패를 구분하는 표식이다.
// 표식 문자열은 "설정"/"테스트 시나리오" 이며, handler 는 errors.Is 로 기존 사용자 메시지를 고른다.
var (
	ErrConfigsLoad   = errors.New("설정 조회 실패")
	ErrScenariosLoad = errors.New("테스트 시나리오 조회 실패")
)

// InvalidDocumentError 는 사전 검증 실패를 나타낸다.
// handler 는 Validation 을 기존 400 응답 본문으로 사용한다.
type InvalidDocumentError struct {
	Validation Validation
}

func (e *InvalidDocumentError) Error() string {
	return "백업 문서 사전 검증에 실패했습니다."
}

// ============================================================================
// 검증
// ============================================================================

// Validate 는 백업 문서의 구조/중복/JSON 무결성을 검증한다.
// DB와의 충돌 여부는 existingConfigs/existingScenarios 를 전달받아 판정한다.
func Validate(doc Document, existingConfigs map[string]*models.RoboClawConfig, existingScenarios map[string]*models.TestScenario) Validation {
	res := Validation{
		Valid:           true,
		SchemaVersion:   doc.SchemaVersion,
		IncludesSecrets: doc.IncludesSecrets,
		Warnings:        []string{},
		Errors:          []string{},
	}

	// kind 검증
	if doc.Kind != Kind {
		res.Errors = append(res.Errors, fmt.Sprintf("지원하지 않는 백업 종류입니다: %q (기대: %q)", doc.Kind, Kind))
	}
	// schema version 검증
	if doc.SchemaVersion != SchemaVersion {
		res.Errors = append(res.Errors, fmt.Sprintf("지원하지 않는 스키마 버전입니다: %d (지원: %d)", doc.SchemaVersion, SchemaVersion))
	}

	if !doc.IncludesSecrets {
		res.Warnings = append(res.Warnings, "민감 정보(ApiKey/Token)가 포함되지 않은 백업입니다. 덮어쓰기 시 기존 서버의 민감 값이 유지됩니다.")
	}

	// 설정 내부 중복 탐지
	seenConfigs := map[string]bool{}
	for _, cfg := range doc.Configs {
		if strings.TrimSpace(cfg.Name) == "" || strings.TrimSpace(cfg.RobotName) == "" || strings.TrimSpace(cfg.Environment) == "" {
			res.Errors = append(res.Errors, fmt.Sprintf("설정 항목에 name/robot_name/environment 가 모두 필요합니다. (name=%q, robot=%q, env=%q)", cfg.Name, cfg.RobotName, cfg.Environment))
			continue
		}
		key := TransferConfigKey(cfg.Name, cfg.RobotName, cfg.Environment)
		if seenConfigs[key] {
			res.Errors = append(res.Errors, fmt.Sprintf("백업 내에 설정 항목이 중복됩니다: %s", key))
			continue
		}
		seenConfigs[key] = true

		// 중첩 JSON 무결성 검증
		if err := service.ValidateJSONFields(cfg.LimitsContent, cfg.OllamaOptionsJson, cfg.HttpAllowedCidrsJson, cfg.HttpAllowedSkillsJson, cfg.HttpBlockedSkillsJson, strOr(cfg.McpServersJson), "", cfg.System1ConfThresholdsJson, cfg.CloidCleanupDemoMotionIDsJson); err != nil {
			res.Errors = append(res.Errors, fmt.Sprintf("설정 %q: %v", cfg.Name, err))
		}
		if cfg.GrpcTargetPeersJson != "" && !json.Valid([]byte(cfg.GrpcTargetPeersJson)) {
			res.Errors = append(res.Errors, fmt.Sprintf("설정 %q: grpc_target_peers_json 필드의 JSON 형식이 올바르지 않습니다.", cfg.Name))
		}

		if existingConfigs != nil {
			if _, exists := existingConfigs[key]; exists {
				res.Summary.ConflictingConfigs++
			} else {
				res.Summary.NewConfigs++
			}
		}
		res.Summary.Configs++
	}

	// 시나리오 내부 중복 탐지
	seenScenarios := map[string]bool{}
	for _, sc := range doc.Scenarios {
		if strings.TrimSpace(sc.Name) == "" || strings.TrimSpace(sc.RobotName) == "" || strings.TrimSpace(sc.Environment) == "" {
			res.Errors = append(res.Errors, fmt.Sprintf("시나리오 항목에 name/robot_name/environment 가 모두 필요합니다. (name=%q, robot=%q, env=%q)", sc.Name, sc.RobotName, sc.Environment))
			continue
		}
		key := TransferScenarioKey(sc.Name, sc.RobotName, sc.Environment)
		if seenScenarios[key] {
			res.Errors = append(res.Errors, fmt.Sprintf("백업 내에 시나리오 항목이 중복됩니다: %s", key))
			continue
		}
		seenScenarios[key] = true

		// 테스트 케이스 필수 필드 검증
		for i, tc := range sc.TestCases {
			if strings.TrimSpace(tc.ID) == "" || strings.TrimSpace(tc.Name) == "" || strings.TrimSpace(tc.Type) == "" {
				res.Errors = append(res.Errors, fmt.Sprintf("시나리오 %q 의 %d번째 테스트 케이스에 id/name/type 가 모두 필요합니다.", sc.Name, i+1))
			}
		}

		if existingScenarios != nil {
			if _, exists := existingScenarios[key]; exists {
				res.Summary.ConflictingScenarios++
			} else {
				res.Summary.NewScenarios++
			}
		}
		res.Summary.Scenarios++
	}

	if len(res.Errors) > 0 {
		res.Valid = false
	}
	return res
}

func strOr(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

// ============================================================================
// 내보내기
// ============================================================================

// Export 는 DB 원본(마스킹 전) 값을 읽어 이식용 백업 문서를 생성한다.
// 파일명/HTTP 응답/로그는 handler 가 담당한다.
func Export(ctx context.Context, db *gorm.DB, includeSecrets, includeConfigs, includeScenarios bool, exportedAt time.Time) (Document, error) {
	doc := Document{
		Kind:            Kind,
		SchemaVersion:   SchemaVersion,
		ExportedAt:      exportedAt,
		IncludesSecrets: includeSecrets,
		Configs:         []ConfigTransfer{},
		Scenarios:       []ScenarioTransfer{},
	}

	if includeConfigs {
		var configs []models.RoboClawConfig
		if err := db.WithContext(ctx).Find(&configs).Error; err != nil {
			return Document{}, fmt.Errorf("%w: %v", ErrConfigsLoad, err)
		}
		for i := range configs {
			doc.Configs = append(doc.Configs, ConfigFromModel(&configs[i], includeSecrets))
		}
	}

	if includeScenarios {
		var scenarios []models.TestScenario
		if err := db.WithContext(ctx).Find(&scenarios).Error; err != nil {
			return Document{}, fmt.Errorf("%w: %v", ErrScenariosLoad, err)
		}
		for i := range scenarios {
			doc.Scenarios = append(doc.Scenarios, ScenarioFromModel(&scenarios[i]))
		}
	}

	return doc, nil
}

// ============================================================================
// 가져오기
// ============================================================================

// Import 는 사전 검증 후 설정/시나리오를 하나의 트랜잭션으로 적용한다.
// 검증 실패는 *InvalidDocumentError, 기존 데이터 조회 실패는 ErrConfigsLoad/ErrScenariosLoad 로 반환한다.
func Import(ctx context.Context, db *gorm.DB, doc Document, conflictPolicy, activationPolicy string) (Result, error) {
	existingConfigs, err := LoadConfigKeyMap(db.WithContext(ctx))
	if err != nil {
		return Result{}, fmt.Errorf("%w: %v", ErrConfigsLoad, err)
	}
	existingScenarios, err := LoadScenarioKeyMap(db.WithContext(ctx))
	if err != nil {
		return Result{}, fmt.Errorf("%w: %v", ErrScenariosLoad, err)
	}
	if vr := Validate(doc, existingConfigs, existingScenarios); !vr.Valid {
		return Result{}, &InvalidDocumentError{Validation: vr}
	}

	result := Result{
		Configs:   ImportActionResult{},
		Scenarios: ImportActionResult{},
	}

	// 전체를 하나의 트랜잭션으로 처리 (중간 실패 시 전체 롤백)
	err = db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 최신화된 기존 데이터맵 (덮어쓰기/활성 처리에 사용)
		curConfigs, err := LoadConfigKeyMap(tx)
		if err != nil {
			return err
		}
		curScenarios, err := LoadScenarioKeyMap(tx)
		if err != nil {
			return err
		}

		cfgResult, err := ApplyConfigImport(tx, doc, conflictPolicy, activationPolicy, curConfigs)
		if err != nil {
			return err
		}
		result.Configs = cfgResult

		scResult, err := ApplyScenarioImport(tx, doc, conflictPolicy, activationPolicy, curScenarios)
		if err != nil {
			return err
		}
		result.Scenarios = scResult
		return nil
	})

	if err != nil {
		return Result{}, err
	}
	return result, nil
}

// ApplyConfigImport 는 설정 항목들을 트랜잭션 내에서 적용한다.
func ApplyConfigImport(tx *gorm.DB, doc Document, conflict, activation string, existing map[string]*models.RoboClawConfig) (ImportActionResult, error) {
	res := ImportActionResult{}

	for _, t := range doc.Configs {
		key := TransferConfigKey(t.Name, t.RobotName, t.Environment)
		cur := existing[key]

		switch conflict {
		case ConflictSkip:
			if cur != nil {
				res.Skipped++
				continue
			}
		case ConflictCopy:
			if cur != nil {
				newName := UniqueImportName(tx, &models.RoboClawConfig{}, t.Name)
				t.Name = newName
				key = TransferConfigKey(newName, t.RobotName, t.Environment)
				cur = nil
			}
		case ConflictOverwrite:
			// cur 유지 (nil이면 신규 생성)
		}

		effectiveActive := t.IsActive
		switch activation {
		case ActivationInactive:
			effectiveActive = false
		case ActivationKeepExisting:
			if cur != nil {
				effectiveActive = cur.IsActive
			} else {
				effectiveActive = false
			}
		}

		model := t.ToModel(cur)
		model.IsActive = effectiveActive
		service.ApplyButlerPathDefaults(&model)

		// 활성화 대상이면 같은 로봇/환경의 기존 활성 항목을 비활성화
		if effectiveActive {
			if err := tx.Model(&models.RoboClawConfig{}).
				Where("robot_name = ? AND environment = ?", model.RobotName, model.Environment).
				Update("is_active", false).Error; err != nil {
				return res, err
			}
		}

		if cur != nil && conflict != ConflictCopy {
			model.ID = cur.ID
			if err := tx.Save(&model).Error; err != nil {
				return res, err
			}
			res.Updated++
		} else {
			model.ID = 0
			if err := tx.Create(&model).Error; err != nil {
				return res, err
			}
			res.Created++
		}
	}
	return res, nil
}

// ApplyScenarioImport 는 시나리오 항목들을 트랜잭션 내에서 적용한다.
func ApplyScenarioImport(tx *gorm.DB, doc Document, conflict, activation string, existing map[string]*models.TestScenario) (ImportActionResult, error) {
	res := ImportActionResult{}

	for _, t := range doc.Scenarios {
		key := TransferScenarioKey(t.Name, t.RobotName, t.Environment)
		cur := existing[key]

		switch conflict {
		case ConflictSkip:
			if cur != nil {
				res.Skipped++
				continue
			}
		case ConflictCopy:
			if cur != nil {
				newName := UniqueImportName(tx, &models.TestScenario{}, t.Name)
				t.Name = newName
				key = TransferScenarioKey(newName, t.RobotName, t.Environment)
				cur = nil
			}
		case ConflictOverwrite:
			// cur 유지
		}

		effectiveActive := t.IsActive
		switch activation {
		case ActivationInactive:
			effectiveActive = false
		case ActivationKeepExisting:
			if cur != nil {
				effectiveActive = cur.IsActive
			} else {
				effectiveActive = false
			}
		}

		model := t.ToModel()
		model.IsActive = effectiveActive

		if effectiveActive {
			if err := tx.Model(&models.TestScenario{}).
				Where("robot_name = ? AND environment = ?", model.RobotName, model.Environment).
				Update("is_active", false).Error; err != nil {
				return res, err
			}
		}

		if cur != nil && conflict != ConflictCopy {
			model.ID = cur.ID
			if err := tx.Save(&model).Error; err != nil {
				return res, err
			}
			res.Updated++
		} else {
			model.ID = 0
			if err := tx.Create(&model).Error; err != nil {
				return res, err
			}
			res.Created++
		}
	}
	return res, nil
}

// UniqueImportName 은 base 이름이 이미 존재하면 base_import, base_import_2 ... 를 만든다.
func UniqueImportName(tx *gorm.DB, model any, base string) string {
	candidate := base + "_import"
	if !NameExists(tx, model, candidate) {
		return candidate
	}
	for i := 2; ; i++ {
		c := fmt.Sprintf("%s_%d", candidate, i)
		if !NameExists(tx, model, c) {
			return c
		}
	}
}

// NameExists 는 같은 name 을 가진 레코드가 있는지 확인한다.
func NameExists(tx *gorm.DB, model any, name string) bool {
	var count int64
	tx.Model(model).Where("name = ?", name).Count(&count)
	return count > 0
}

// ============================================================================
// 키 구성 (name + robot_name + environment)
// ============================================================================

// ConfigKey 는 설정 모델의 충돌 판정 키를 만든다.
func ConfigKey(cfg *models.RoboClawConfig) string {
	return cfg.Name + "|" + cfg.RobotName + "|" + cfg.Environment
}

// TransferConfigKey 는 전송 DTO 값으로 충돌 판정 키를 만든다.
func TransferConfigKey(name, robot, env string) string {
	return name + "|" + robot + "|" + env
}

// ScenarioKey 는 시나리오 모델의 충돌 판정 키를 만든다.
func ScenarioKey(s *models.TestScenario) string {
	return s.Name + "|" + s.RobotName + "|" + s.Environment
}

// TransferScenarioKey 는 전송 DTO 값으로 충돌 판정 키를 만든다.
func TransferScenarioKey(name, robot, env string) string {
	return name + "|" + robot + "|" + env
}

// LoadConfigKeyMap 은 모든 설정을 키맵으로 읽는다.
func LoadConfigKeyMap(tx *gorm.DB) (map[string]*models.RoboClawConfig, error) {
	var configs []models.RoboClawConfig
	if err := tx.Find(&configs).Error; err != nil {
		return nil, err
	}
	m := make(map[string]*models.RoboClawConfig, len(configs))
	for i := range configs {
		m[ConfigKey(&configs[i])] = &configs[i]
	}
	return m, nil
}

// LoadScenarioKeyMap 은 모든 시나리오를 키맵으로 읽는다.
func LoadScenarioKeyMap(tx *gorm.DB) (map[string]*models.TestScenario, error) {
	var scenarios []models.TestScenario
	if err := tx.Find(&scenarios).Error; err != nil {
		return nil, err
	}
	m := make(map[string]*models.TestScenario, len(scenarios))
	for i := range scenarios {
		m[ScenarioKey(&scenarios[i])] = &scenarios[i]
	}
	return m, nil
}
