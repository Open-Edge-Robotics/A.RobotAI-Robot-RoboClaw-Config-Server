package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"ai-config-server/database/models"
	"ai-config-server/service"
)

// applyButlerPathDefaults 는 butler 로봇 설정의 비어 있는 기본 경로를 채운다.
// 실제 구현은 service.ApplyButlerPathDefaults 에 있다.
func applyButlerPathDefaults(cfg *models.RoboClawConfig) {
	service.ApplyButlerPathDefaults(cfg)
}

func (h *Handler) ListConfigs(c *gin.Context) {
	var items []models.RoboClawConfig
	query := h.DB.WithContext(c.Request.Context())

	if robotName := c.Query("robot_name"); robotName != "" {
		query = query.Where("robot_name = ?", robotName)
	}
	if env := c.Query("environment"); env != "" {
		query = query.Where("environment = ?", env)
	}

	if err := query.Find(&items).Error; err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "설정 목록 조회 중 오류가 발생했습니다.", err)
		return
	}

	for i := range items {
		applyButlerPathDefaults(&items[i])
		maskSensitiveFields(&items[i])
	}

	c.JSON(http.StatusOK, items)
}

func (h *Handler) GetConfig(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "올바르지 않은 ID 형식입니다.", err)
		return
	}

	var item models.RoboClawConfig
	if err := h.DB.WithContext(c.Request.Context()).First(&item, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			LogAndRespondError(c, http.StatusNotFound, "해당 설정을 찾을 수 없습니다.", err)
		} else {
			LogAndRespondError(c, http.StatusInternalServerError, "설정 상세 정보를 조회하는 중 오류가 발생했습니다.", err)
		}
		return
	}

	applyButlerPathDefaults(&item)
	maskSensitiveFields(&item)
	c.JSON(http.StatusOK, item)
}

func (h *Handler) CreateConfig(c *gin.Context) {
	var item models.RoboClawConfig
	if err := c.ShouldBindJSON(&item); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "요청한 JSON 데이터의 유효성 검증에 실패했습니다.", err)
		return
	}

	if item.CloidCleanupDemoEnabled == nil {
		item.CloidCleanupDemoEnabled = boolPtr(true)
	}
	if item.CloidExpressionEnabled == nil {
		item.CloidExpressionEnabled = boolPtr(false)
	}
	if item.CloidNavigationPoseEnabled == nil {
		item.CloidNavigationPoseEnabled = boolPtr(false)
	}

	// JSON 포맷 사전 검증
	if err := validateJSONFields(item.LimitsContent, item.OllamaOptionsJson, item.HttpAllowedCidrsJson, item.HttpAllowedSkillsJson, item.HttpBlockedSkillsJson, item.McpServersJson, "", item.System1ConfThresholdsJson, item.CloidCleanupDemoMotionIDsJson); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "입력값의 JSON 포맷이 올바르지 않습니다.", err)
		return
	}
	if err := validateRuntimeValues(&item); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "설정값 범위 또는 의존성이 올바르지 않습니다.", err)
		return
	}
	applyButlerPathDefaults(&item)

	err := h.DB.WithContext(c.Request.Context()).Transaction(func(tx *gorm.DB) error {
		if item.IsActive {
			if err := tx.Model(&models.RoboClawConfig{}).
				Where("robot_name = ? AND environment = ?", item.RobotName, item.Environment).
				Update("is_active", false).Error; err != nil {
				return err
			}
		}
		return tx.Create(&item).Error
	})
	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "신규 설정을 데이터베이스에 등록하는 중 오류가 발생했습니다.", err)
		return
	}

	LogInfo("[SUCCESS] 신규 설정 등록 완료 | ID: %d, Name: %s, Robot: %s, Env: %s", item.ID, item.Name, item.RobotName, item.Environment)

	h.cache.clear() // 배포 데이터 동기화를 위해 캐시 초기화
	maskSensitiveFields(&item)
	c.JSON(http.StatusCreated, item)
}

func (h *Handler) UpdateConfig(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "올바르지 않은 ID 형식입니다.", err)
		return
	}

	var item models.RoboClawConfig
	if err := h.DB.WithContext(c.Request.Context()).First(&item, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			LogAndRespondError(c, http.StatusNotFound, "수정 대상 설정을 찾을 수 없습니다.", err)
		} else {
			LogAndRespondError(c, http.StatusInternalServerError, "기존 설정을 조회하는 중 오류가 발생했습니다.", err)
		}
		return
	}

	var fields map[string]json.RawMessage
	if err := c.ShouldBindJSON(&fields); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "수정 요청 JSON 데이터 유효성 검증에 실패했습니다.", err)
		return
	}

	// 기존 레코드와 요청 필드를 병합한다. 전체 모델에 직접 바인딩하면
	// 새 필드를 모르는 구형 클라이언트의 PUT 요청이 해당 필드를 zero value로
	// 초기화하는 문제가 발생한다.
	existingJSON, err := json.Marshal(item)
	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "기존 설정을 병합하는 중 오류가 발생했습니다.", err)
		return
	}
	merged := make(map[string]json.RawMessage)
	if err := json.Unmarshal(existingJSON, &merged); err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "기존 설정을 병합하는 중 오류가 발생했습니다.", err)
		return
	}
	for key, value := range fields {
		merged[key] = value
	}
	// 영속성 및 활성 상태는 일반 수정 payload가 변경할 수 없다.
	delete(merged, "ID")
	delete(merged, "id")
	delete(merged, "CreatedAt")
	delete(merged, "created_at")
	delete(merged, "UpdatedAt")
	delete(merged, "updated_at")
	delete(merged, "DeletedAt")
	delete(merged, "deleted_at")
	delete(merged, "is_active")
	mergedJSON, err := json.Marshal(merged)
	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "수정 요청을 병합하는 중 오류가 발생했습니다.", err)
		return
	}
	var req models.RoboClawConfig
	if err := json.Unmarshal(mergedJSON, &req); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "수정 요청의 필드 형식이 올바르지 않습니다.", err)
		return
	}

	// MCP 서버 목록은 자격 증명(env/headers)만 마스킹되어 내려간다.
	// - JSON 전체가 "********" 인 경우(전체 마스킹 값)는 기존 값을 그대로 보존한다.
	// - 필드 단위 마스킹이면 남아 있는 마스킹 값을 기존 저장 값으로 복원한다.
	// JSON 포맷 검증 전에 복원해야 한다(validateJSONFields 가 이 필드도 검사한다).
	if req.McpServersJson == MaskValue {
		req.McpServersJson = item.McpServersJson
	} else {
		req.McpServersJson = mergeMaskedMcpServersJson(item.McpServersJson, req.McpServersJson)
	}

	// JSON 포맷 사전 검증
	if err := validateJSONFields(req.LimitsContent, req.OllamaOptionsJson, req.HttpAllowedCidrsJson, req.HttpAllowedSkillsJson, req.HttpBlockedSkillsJson, req.McpServersJson, req.GrpcTargetPeersJson, req.System1ConfThresholdsJson, req.CloidCleanupDemoMotionIDsJson); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "입력값의 JSON 포맷이 올바르지 않습니다.", err)
		return
	}
	if err := validateRuntimeValues(&req); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "설정값 범위 또는 의존성이 올바르지 않습니다.", err)
		return
	}

	// 마스킹된 자격 증명이 그대로 전달된 경우 기존 값 유지
	if req.AzureOpenaiApiKey == "********" {
		req.AzureOpenaiApiKey = item.AzureOpenaiApiKey
	}
	if req.OpenaiApiKey == "********" {
		req.OpenaiApiKey = item.OpenaiApiKey
	}
	if req.AnthropicApiKey == "********" {
		req.AnthropicApiKey = item.AnthropicApiKey
	}
	if req.LlmEmbeddingApiKey == "********" {
		req.LlmEmbeddingApiKey = item.LlmEmbeddingApiKey
	}
	if req.DiscordBotToken == "********" {
		req.DiscordBotToken = item.DiscordBotToken
	}
	if req.SlackAppToken == "********" {
		req.SlackAppToken = item.SlackAppToken
	}
	if req.SlackBotToken == "********" {
		req.SlackBotToken = item.SlackBotToken
	}
	if req.TelegramBotToken == "********" {
		req.TelegramBotToken = item.TelegramBotToken
	}
	if req.GrpcPeerToken == "********" {
		req.GrpcPeerToken = item.GrpcPeerToken
	}
	if req.HttpReadonlyToken == "********" {
		req.HttpReadonlyToken = item.HttpReadonlyToken
	}
	if req.HttpControlToken == "********" {
		req.HttpControlToken = item.HttpControlToken
	}
	if req.QdrantApiKey == "********" {
		req.QdrantApiKey = item.QdrantApiKey
	}
	if req.LangsmithApiKey == "********" {
		req.LangsmithApiKey = item.LangsmithApiKey
	}
	if req.System1ApiKey == "********" {
		req.System1ApiKey = item.System1ApiKey
	}

	// PUT은 프로필 내용을 수정하는 API다. 활성 상태 전환은 전용 activate API에서만 수행한다.
	// 프론트엔드가 is_active를 생략하거나 오래된 클라이언트가 false를 보내도
	// 활성 프로필이 편집으로 비활성화되지 않도록 기존 값을 보존한다.
	req.IsActive = item.IsActive

	// 클라이언트가 영속성 메타데이터를 임의로 변경하지 못하게 한다.
	req.CreatedAt = item.CreatedAt
	req.UpdatedAt = item.UpdatedAt
	req.DeletedAt = item.DeletedAt

	// 고유 ID 강제 고정
	req.ID = uint(id)
	applyButlerPathDefaults(&req)

	err = h.DB.WithContext(c.Request.Context()).Transaction(func(tx *gorm.DB) error {
		if req.IsActive {
			if err := tx.Model(&models.RoboClawConfig{}).
				Where("robot_name = ? AND environment = ? AND id <> ?", req.RobotName, req.Environment, id).
				Update("is_active", false).Error; err != nil {
				return err
			}
		}
		return tx.Save(&req).Error
	})
	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "설정 변경 사항을 데이터베이스에 반영하지 못했습니다.", err)
		return
	}

	LogInfo("[SUCCESS] 설정 수정 완료 | ID: %d, Name: %s, Robot: %s", req.ID, req.Name, req.RobotName)

	h.cache.clear() // 수정 내역 즉각 배포를 위해 캐시 무효화
	maskSensitiveFields(&req)
	c.JSON(http.StatusOK, req)
}

// CloneConfig POST /api/v1/configs/:id/clone
// 기존 설정을 복제하여 새 설정 프로필을 생성합니다.
// DB에서 실제 값을 직접 복사하므로 마스킹된 자격 증명도 원본값이 그대로 복제됩니다.
func (h *Handler) CloneConfig(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "올바르지 않은 ID 형식입니다.", err)
		return
	}

	var src models.RoboClawConfig
	if err := h.DB.WithContext(c.Request.Context()).First(&src, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			LogAndRespondError(c, http.StatusNotFound, "복제 대상 설정을 찾을 수 없습니다.", err)
		} else {
			LogAndRespondError(c, http.StatusInternalServerError, "복제 대상 설정을 조회하는 중 오류가 발생했습니다.", err)
		}
		return
	}

	// 복제본 생성: ID/타임스탬프 초기화, 비활성화, 이름 자동 생성
	clone := src
	clone.ID = 0
	clone.CreatedAt = time.Time{}
	clone.UpdatedAt = time.Time{}
	clone.DeletedAt = gorm.DeletedAt{}
	clone.IsActive = false
	clone.Name = h.generateUniqueCloneName(c.Request.Context(), &models.RoboClawConfig{}, src.Name)
	applyButlerPathDefaults(&clone)
	if clone.Description == "" {
		clone.Description = fmt.Sprintf("(원본 복제: %s)", src.Name)
	} else {
		clone.Description = fmt.Sprintf("%s (원본 복제: %s)", src.Description, src.Name)
	}

	// JSON 포맷 사전 검증 (원본 데이터 보존)
	if err := validateJSONFields(clone.LimitsContent, clone.OllamaOptionsJson, clone.HttpAllowedCidrsJson, clone.HttpAllowedSkillsJson, clone.HttpBlockedSkillsJson, clone.McpServersJson, "", clone.System1ConfThresholdsJson, clone.CloidCleanupDemoMotionIDsJson); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "원본 입력값의 JSON 포맷이 올바르지 않아 복제할 수 없습니다.", err)
		return
	}

	if err := h.DB.WithContext(c.Request.Context()).Create(&clone).Error; err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "복제 설정을 데이터베이스에 등록하는 중 오류가 발생했습니다.", err)
		return
	}

	LogInfo("[SUCCESS] 설정 복제 완료 | 원본 ID: %d, 복제본 ID: %d, Name: %s, Robot: %s, Env: %s", id, clone.ID, clone.Name, clone.RobotName, clone.Environment)

	h.cache.clear() // 복제본 추가 후 캐시 초기화
	maskSensitiveFields(&clone)
	c.JSON(http.StatusCreated, clone)
}

// generateUniqueCloneName은 원본 이름에 _copy 접미사를 붙이고,
// 동일 이름이 존재하면 _copy_2, _copy_3 형태로 번호를 증가시켜 고유 이름을 생성합니다.
// model 인자는 조회 대상 GORM 모델을 지정합니다 (RoboClawConfig, TestScenario 등).
func (h *Handler) generateUniqueCloneName(ctx context.Context, model interface{}, originalName string) string {
	base := originalName + "_copy"
	var count int64
	h.DB.WithContext(ctx).Model(model).Where("name = ?", base).Count(&count)
	if count == 0 {
		return base
	}

	for i := 2; ; i++ {
		candidate := fmt.Sprintf("%s_%d", base, i)
		h.DB.WithContext(ctx).Model(model).Where("name = ?", candidate).Count(&count)
		if count == 0 {
			return candidate
		}
	}
}

// DeleteConfig DELETE /api/v1/configs/:id
func (h *Handler) DeleteConfig(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "올바르지 않은 ID 형식입니다.", err)
		return
	}

	if err := h.DB.WithContext(c.Request.Context()).Delete(&models.RoboClawConfig{}, id).Error; err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "설정을 데이터베이스에서 삭제하는 중 오류가 발생했습니다.", err)
		return
	}

	LogInfo("[SUCCESS] 설정 삭제 완료 | ID: %d", id)
	h.cache.clear() // 삭제 내역 동기화를 위해 캐시 초기화
	c.JSON(http.StatusOK, gin.H{"deleted": id})
}

// ActivateConfig POST /api/v1/configs/:id/activate
// 특정 설정을 활성화하고 동일 로봇/환경의 다른 설정을 비활성화합니다.
func (h *Handler) ActivateConfig(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "올바르지 않은 ID 형식입니다.", err)
		return
	}

	var target models.RoboClawConfig
	if err := h.DB.WithContext(c.Request.Context()).First(&target, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			LogAndRespondError(c, http.StatusNotFound, "활성화 타겟 설정을 찾을 수 없습니다.", err)
		} else {
			LogAndRespondError(c, http.StatusInternalServerError, "활성화 타겟 설정을 조회하는 중 오류가 발생했습니다.", err)
		}
		return
	}

	// 트랜잭션을 통해 기존 설정들을 비활성화하고 대상 설정을 활성화
	err = h.DB.WithContext(c.Request.Context()).Transaction(func(tx *gorm.DB) error {
		// 동일 로봇 및 환경의 모든 설정을 비활성화
		err := tx.Model(&models.RoboClawConfig{}).
			Where("robot_name = ? AND environment = ?", target.RobotName, target.Environment).
			Update("is_active", false).Error
		if err != nil {
			return err
		}

		// 대상 설정만 활성화
		err = tx.Model(&target).Update("is_active", true).Error
		if err != nil {
			return err
		}
		return nil
	})

	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "설정 활성 상태 전환 트랜잭션을 실행하지 못했습니다.", err)
		return
	}

	LogInfo("[SUCCESS] 설정 활성화 완료 | ID: %d, Robot: %s, Env: %s", id, target.RobotName, target.Environment)
	h.cache.clear() // 활성화 설정 교체 즉각 반영을 위해 캐시 무효화
	c.JSON(http.StatusOK, gin.H{"message": "activated successfully", "id": id})
}

// validateJSONFields는 입력된 문자열이 유효한 JSON 포맷인지 사전 검사합니다.
// 실제 구현은 service.ValidateJSONFields 에 있다.
func validateJSONFields(limits, ollamaOptions, allowedCidrs, allowedSkills, blockedSkills, mcpServers string, peerValues ...string) error {
	return service.ValidateJSONFields(limits, ollamaOptions, allowedCidrs, allowedSkills, blockedSkills, mcpServers, peerValues...)
}

// isShadowLogPath는 SYSTEM1_SHADOW_LOG 값이 켜기/끄기 토글이 아닌 절대 경로인지 판정한다.
// 실제 구현은 service.IsShadowLogPath 에 있다.
func isShadowLogPath(value string) bool {
	return service.IsShadowLogPath(value)
}

// validateRuntimeValues는 실행 시 필요한 값 범위와 의존 관계를 검사한다.
// 실제 구현은 service.ValidateRuntimeValues 에 있다.
func validateRuntimeValues(cfg *models.RoboClawConfig) error {
	return service.ValidateRuntimeValues(cfg)
}
