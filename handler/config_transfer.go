package handler

import (
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"ai-config-server/database/models"
	"ai-config-server/service/transfer"
)

// ============================================================================
// 이식용 백업(Export/Import) 전송 포맷 정의
//
// DB 모델을 그대로 직렬화하지 않고 별도 DTO를 사용하는 이유:
//   1) GORM ID 및 CreatedAt/UpdatedAt/DeletedAt 등 가져오기 시 충돌을 유발하는
//      메타데이터를 제외한다.
//   2) 민감 정보(ApiKey, Token, MCP 서버 설정)의 포함 여부를 제어할 수 있다.
//   3) DB 스키마가 바뀌어도 백업 파일 포맷을 독립적으로 유지할 수 있다.
//   4) 민감 필드는 *string 으로 선언하여 "백업에 없음(nil)"과 "빈 문자열"을
//      구분하고, 덮어쓰기 시 기존 서버의 값을 보존할 수 있게 한다.
//
// 검증/적용/키 구성 로직은 service/transfer 가 소유한다. handler 는 HTTP
// 파싱/응답과 기존 공개 타입·상수 이름만 유지한다.
// ============================================================================

const (
	BackupKind             = transfer.Kind
	BackupSchemaVersion    = transfer.SchemaVersion
	ConflictSkip           = transfer.ConflictSkip
	ConflictOverwrite      = transfer.ConflictOverwrite
	ConflictCopy           = transfer.ConflictCopy
	ActivationInactive     = transfer.ActivationInactive
	ActivationPreserve     = transfer.ActivationPreserve
	ActivationKeepExisting = transfer.ActivationKeepExisting
)

// BackupDocument 백업 파일 최상위 구조.
type BackupDocument struct {
	Kind            string             `json:"kind"`
	SchemaVersion   int                `json:"schema_version"`
	ExportedAt      time.Time          `json:"exported_at"`
	IncludesSecrets bool               `json:"includes_secrets"`
	Configs         []ConfigTransfer   `json:"configs"`
	Scenarios       []ScenarioTransfer `json:"scenarios"`
}

// ConfigTransfer 설정 프로필 전송 DTO. 정의는 service/transfer 에 있다.
type ConfigTransfer transfer.ConfigTransfer

// ScenarioTransfer 테스트 시나리오 전송 DTO. 정의는 service/transfer 에 있다.
type ScenarioTransfer transfer.ScenarioTransfer

// TestCaseTransfer 개별 테스트 케이스 전송 DTO. 정의는 service/transfer 에 있다.
type TestCaseTransfer = transfer.TestCaseTransfer

// ImportSummary/ImportValidationResult/ImportActionResult/ImportResult 는
// service/transfer 타입의 별칭이다. JSON 계약은 동일하게 유지된다.
type (
	ImportSummary          = transfer.ImportSummary
	ImportValidationResult = transfer.Validation
	ImportActionResult     = transfer.ImportActionResult
	ImportResult           = transfer.Result
)

// ExportRequest POST /transfer/export 본문. GET 쿼리 파라미터와 동일 의미.
type ExportRequest struct {
	IncludeSecrets   bool `json:"include_secrets"`
	IncludeConfigs   bool `json:"include_configs"`
	IncludeScenarios bool `json:"include_scenarios"`
}

// ImportOptions 가져오기 옵션.
type ImportOptions struct {
	ConflictPolicy   string `json:"conflict_policy"`   // skip | overwrite | copy
	ActivationPolicy string `json:"activation_policy"` // inactive | preserve | keep_existing
}

// ImportRequest 가져오기 요청 본문.
type ImportRequest struct {
	Document BackupDocument `json:"document"`
	Options  ImportOptions  `json:"options"`
}

// ============================================================================
// 변환 헬퍼
// ============================================================================

func boolPtr(v bool) *bool { return new(v) }

// toService 는 HTTP 계층 문서를 service 문서로 변환한다.
func (d BackupDocument) toService() transfer.Document {
	return transfer.Document{
		Kind:            d.Kind,
		SchemaVersion:   d.SchemaVersion,
		ExportedAt:      d.ExportedAt,
		IncludesSecrets: d.IncludesSecrets,
		Configs:         configTransfersToService(d.Configs),
		Scenarios:       scenarioTransfersToService(d.Scenarios),
	}
}

// fromService 는 service 문서를 HTTP 계층 문서로 변환한다.
func fromService(d transfer.Document) BackupDocument {
	return BackupDocument{
		Kind:            d.Kind,
		SchemaVersion:   d.SchemaVersion,
		ExportedAt:      d.ExportedAt,
		IncludesSecrets: d.IncludesSecrets,
		Configs:         configTransfersFromService(d.Configs),
		Scenarios:       scenarioTransfersFromService(d.Scenarios),
	}
}

func configTransfersToService(in []ConfigTransfer) []transfer.ConfigTransfer {
	if in == nil {
		return nil
	}
	out := make([]transfer.ConfigTransfer, len(in))
	for i := range in {
		out[i] = transfer.ConfigTransfer(in[i])
	}
	return out
}

func configTransfersFromService(in []transfer.ConfigTransfer) []ConfigTransfer {
	if in == nil {
		return nil
	}
	out := make([]ConfigTransfer, len(in))
	for i := range in {
		out[i] = ConfigTransfer(in[i])
	}
	return out
}

func scenarioTransfersToService(in []ScenarioTransfer) []transfer.ScenarioTransfer {
	if in == nil {
		return nil
	}
	out := make([]transfer.ScenarioTransfer, len(in))
	for i := range in {
		out[i] = transfer.ScenarioTransfer(in[i])
	}
	return out
}

func scenarioTransfersFromService(in []transfer.ScenarioTransfer) []ScenarioTransfer {
	if in == nil {
		return nil
	}
	out := make([]ScenarioTransfer, len(in))
	for i := range in {
		out[i] = ScenarioTransfer(in[i])
	}
	return out
}

// configToTransfer는 DB 원본(마스킹 전)을 전송 DTO로 변환한다.
// includeSecrets=false 이면 민감 필드를 생략한다.
func configToTransfer(cfg *models.RoboClawConfig, includeSecrets bool) ConfigTransfer {
	return ConfigTransfer(transfer.ConfigFromModel(cfg, includeSecrets))
}

// toModel은 전송 DTO를 DB 모델로 변환한다. 정의는 service/transfer 에 있다.
func (t ConfigTransfer) toModel(existing *models.RoboClawConfig) models.RoboClawConfig {
	return transfer.ConfigTransfer(t).ToModel(existing)
}

// scenarioToTransfer는 DB 원본 테스트 시나리오를 전송 DTO로 변환한다.
// 정의는 service/transfer 에 있다.
func scenarioToTransfer(s *models.TestScenario) ScenarioTransfer {
	return ScenarioTransfer(transfer.ScenarioFromModel(s))
}

// toModel은 전송 DTO를 DB 모델로 변환한다. 정의는 service/transfer 에 있다.
func (t ScenarioTransfer) toModel() models.TestScenario {
	return transfer.ScenarioTransfer(t).ToModel()
}

// ============================================================================
// service/transfer 위임 헬퍼
//
// 키 구성/적용 로직은 service 가 소유한다. handler 는 검증 단계에서 쓰는 키맵
// 로딩만 위임하며, 나머지 헬퍼의 단위 테스트는 service/transfer 에 있다.
// ============================================================================

func loadConfigKeyMap(tx *gorm.DB) (map[string]*models.RoboClawConfig, error) {
	return transfer.LoadConfigKeyMap(tx)
}

func loadScenarioKeyMap(tx *gorm.DB) (map[string]*models.TestScenario, error) {
	return transfer.LoadScenarioKeyMap(tx)
}

// ============================================================================
// 내보내기 API
// ============================================================================

// ExportBackup GET|POST /api/v1/admin/transfer/export
// DB 원본(마스킹 전) 값을 읽어 이식용 백업 JSON을 생성한다.
func (h *Handler) ExportBackup(c *gin.Context) {
	var req ExportRequest
	if c.Request.Method == http.MethodPost {
		if err := c.ShouldBindJSON(&req); err != nil {
			LogAndRespondError(c, http.StatusBadRequest, "내보내기 요청 JSON 유효성 검증에 실패했습니다.", err)
			return
		}
	} else {
		req.IncludeSecrets = c.Query("include_secrets") == "true"
		req.IncludeConfigs = c.Query("include_configs") != "false"
		req.IncludeScenarios = c.Query("include_scenarios") != "false"
	}

	exported, err := transfer.Export(c.Request.Context(), h.DB, req.IncludeSecrets, req.IncludeConfigs, req.IncludeScenarios, time.Now())
	if err != nil {
		if errors.Is(err, transfer.ErrScenariosLoad) {
			LogAndRespondError(c, http.StatusInternalServerError, "테스트 시나리오 데이터를 조회하는 중 오류가 발생했습니다.", err)
			return
		}
		LogAndRespondError(c, http.StatusInternalServerError, "설정 데이터를 조회하는 중 오류가 발생했습니다.", err)
		return
	}
	doc := fromService(exported)

	LogInfo("[SUCCESS] 백업 내보내기 완료 | configs=%d, scenarios=%d, secrets=%t", len(doc.Configs), len(doc.Scenarios), req.IncludeSecrets)

	filename := fmt.Sprintf("ai-config-backup-%s.json", time.Now().Format("20060102-150405"))
	if req.IncludeSecrets {
		filename = fmt.Sprintf("ai-config-backup-with-secrets-%s.json", time.Now().Format("20060102-150405"))
	}
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%q", filename))
	c.JSON(http.StatusOK, doc)
}

// ============================================================================
// 가져오기 검증 API
// ============================================================================

// ValidateImport POST /api/v1/admin/transfer/import/validate
func (h *Handler) ValidateImport(c *gin.Context) {
	var req ImportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "검증 요청 JSON 유효성 검증에 실패했습니다.", err)
		return
	}

	ctx := c.Request.Context()
	existingConfigs, err := loadConfigKeyMap(h.DB.WithContext(ctx))
	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "기존 설정을 조회하는 중 오류가 발생했습니다.", err)
		return
	}
	existingScenarios, err := loadScenarioKeyMap(h.DB.WithContext(ctx))
	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "기존 시나리오를 조회하는 중 오류가 발생했습니다.", err)
		return
	}

	// 검증 실패 시에도 200 으로 결과를 반환해 프론트엔드가 오류 목록을 표시할 수 있게 한다.
	c.JSON(http.StatusOK, transfer.Validate(req.Document.toService(), existingConfigs, existingScenarios))
}

// ============================================================================
// 가져오기 실행 API
// ============================================================================

// ImportBackup POST /api/v1/admin/transfer/import
func (h *Handler) ImportBackup(c *gin.Context) {
	var req ImportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "가져오기 요청 JSON 유효성 검증에 실패했습니다.", err)
		return
	}

	conflict := req.Options.ConflictPolicy
	if conflict == "" {
		conflict = ConflictSkip
	}
	activation := req.Options.ActivationPolicy
	if activation == "" {
		activation = ActivationInactive
	}
	if conflict != ConflictSkip && conflict != ConflictOverwrite && conflict != ConflictCopy {
		LogAndRespondError(c, http.StatusBadRequest, "지원하지 않는 충돌 정책입니다. (skip | overwrite | copy)", nil)
		return
	}
	if activation != ActivationInactive && activation != ActivationPreserve && activation != ActivationKeepExisting {
		LogAndRespondError(c, http.StatusBadRequest, "지원하지 않는 활성 정책입니다. (inactive | preserve | keep_existing)", nil)
		return
	}

	result, err := transfer.Import(c.Request.Context(), h.DB, req.Document.toService(), conflict, activation)
	if err != nil {
		var invalid *transfer.InvalidDocumentError
		if errors.As(err, &invalid) {
			c.JSON(http.StatusBadRequest, invalid.Validation)
			return
		}
		if errors.Is(err, transfer.ErrScenariosLoad) {
			LogAndRespondError(c, http.StatusInternalServerError, "기존 시나리오를 조회하는 중 오류가 발생했습니다.", err)
			return
		}
		if errors.Is(err, transfer.ErrConfigsLoad) {
			LogAndRespondError(c, http.StatusInternalServerError, "기존 설정을 조회하는 중 오류가 발생했습니다.", err)
			return
		}
		LogAndRespondError(c, http.StatusInternalServerError, "백업 가져오기 중 오류가 발생하여 전체가 롤백되었습니다.", err)
		return
	}

	LogInfo("[SUCCESS] 백업 가져오기 완료 | configs(created=%d, updated=%d, skipped=%d), scenarios(created=%d, updated=%d, skipped=%d)",
		result.Configs.Created, result.Configs.Updated, result.Configs.Skipped,
		result.Scenarios.Created, result.Scenarios.Updated, result.Scenarios.Skipped)

	h.cache.clear() // 가져온 설정이 즉시 반영되도록 캐시 무효화
	c.JSON(http.StatusOK, result)
}
