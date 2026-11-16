package handler

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"ai-config-server/database/models"
	"ai-config-server/service/profile"
)

// ListTestScenarios GET /api/v1/scenarios
func (h *Handler) ListTestScenarios(c *gin.Context) {
	var items []models.TestScenario
	query := h.DB.WithContext(c.Request.Context())

	if robotName := c.Query("robot_name"); robotName != "" {
		query = query.Where("robot_name = ?", robotName)
	}
	if env := c.Query("environment"); env != "" {
		query = query.Where("environment = ?", env)
	}

	if err := query.Find(&items).Error; err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "테스트 시나리오 목록 조회 중 오류가 발생했습니다.", err)
		return
	}

	c.JSON(http.StatusOK, items)
}

// GetTestScenario GET /api/v1/scenarios/:id
func (h *Handler) GetTestScenario(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "올바르지 않은 ID 형식입니다.", err)
		return
	}

	var item models.TestScenario
	if err := h.DB.WithContext(c.Request.Context()).First(&item, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			LogAndRespondError(c, http.StatusNotFound, "해당 테스트 시나리오를 찾을 수 없습니다.", err)
		} else {
			LogAndRespondError(c, http.StatusInternalServerError, "테스트 시나리오 상세 정보를 조회하는 중 오류가 발생했습니다.", err)
		}
		return
	}

	c.JSON(http.StatusOK, item)
}

// CreateTestScenario POST /api/v1/scenarios
func (h *Handler) CreateTestScenario(c *gin.Context) {
	var item models.TestScenario
	if err := c.ShouldBindJSON(&item); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "요청한 JSON 데이터의 유효성 검증에 실패했습니다.", err)
		return
	}

	err := h.DB.WithContext(c.Request.Context()).Transaction(func(tx *gorm.DB) error {
		return profile.CreateScenarioInTx(tx, &item)
	})
	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "신규 테스트 시나리오를 등록하는 중 오류가 발생했습니다.", err)
		return
	}

	LogInfo("[SUCCESS] 신규 테스트 시나리오 등록 완료 | ID: %d, Name: %s, Robot: %s, Env: %s", item.ID, item.Name, item.RobotName, item.Environment)
	c.JSON(http.StatusCreated, item)
}

// CloneTestScenario POST /api/v1/scenarios/:id/clone
// 기존 테스트 시나리오를 복제하여 새 시나리오를 생성합니다.
// TestCases는 GORM 커스텀 타입(TestCaseList)으로 DB에서 직접 복사 시 JSON 직렬화가 자동 처리됩니다.
func (h *Handler) CloneTestScenario(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "올바르지 않은 ID 형식입니다.", err)
		return
	}

	var src models.TestScenario
	if err := h.DB.WithContext(c.Request.Context()).First(&src, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			LogAndRespondError(c, http.StatusNotFound, "복제 대상 테스트 시나리오를 찾을 수 없습니다.", err)
		} else {
			LogAndRespondError(c, http.StatusInternalServerError, "복제 대상 테스트 시나리오를 조회하는 중 오류가 발생했습니다.", err)
		}
		return
	}

	clone := src
	clone.ID = 0
	clone.CreatedAt = time.Time{}
	clone.UpdatedAt = time.Time{}
	clone.DeletedAt = gorm.DeletedAt{}
	clone.IsActive = false
	clone.Name = h.generateUniqueCloneName(c.Request.Context(), &models.TestScenario{}, src.Name)
	if clone.Description == "" {
		clone.Description = fmt.Sprintf("(원본 복제: %s)", src.Name)
	} else {
		clone.Description = fmt.Sprintf("%s (원본 복제: %s)", clone.Description, src.Name)
	}

	if err := h.DB.WithContext(c.Request.Context()).Create(&clone).Error; err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "복제 테스트 시나리오를 데이터베이스에 등록하는 중 오류가 발생했습니다.", err)
		return
	}

	LogInfo("[SUCCESS] 테스트 시나리오 복제 완료 | 원본 ID: %d, 복제본 ID: %d, Name: %s, Robot: %s, Env: %s", id, clone.ID, clone.Name, clone.RobotName, clone.Environment)
	c.JSON(http.StatusCreated, clone)
}

// UpdateTestScenario PUT /api/v1/scenarios/:id
func (h *Handler) UpdateTestScenario(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "올바르지 않은 ID 형식입니다.", err)
		return
	}

	var item models.TestScenario
	if err := h.DB.WithContext(c.Request.Context()).First(&item, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			LogAndRespondError(c, http.StatusNotFound, "수정 대상 테스트 시나리오를 찾을 수 없습니다.", err)
		} else {
			LogAndRespondError(c, http.StatusInternalServerError, "기존 테스트 시나리오를 조회하는 중 오류가 발생했습니다.", err)
		}
		return
	}

	var req models.TestScenario
	if err := c.ShouldBindJSON(&req); err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "수정 요청 JSON 데이터 유효성 검증에 실패했습니다.", err)
		return
	}

	req.ID = uint(id)

	err = h.DB.WithContext(c.Request.Context()).Transaction(func(tx *gorm.DB) error {
		return profile.UpdateScenarioInTx(tx, &req)
	})
	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "테스트 시나리오 변경 사항을 반영하지 못했습니다.", err)
		return
	}

	LogInfo("[SUCCESS] 테스트 시나리오 수정 완료 | ID: %d, Name: %s, Robot: %s", req.ID, req.Name, req.RobotName)
	c.JSON(http.StatusOK, req)
}

// DeleteTestScenario DELETE /api/v1/scenarios/:id
func (h *Handler) DeleteTestScenario(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "올바르지 않은 ID 형식입니다.", err)
		return
	}

	if err := h.DB.WithContext(c.Request.Context()).Delete(&models.TestScenario{}, id).Error; err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "테스트 시나리오를 삭제하는 중 오류가 발생했습니다.", err)
		return
	}

	LogInfo("[SUCCESS] 테스트 시나리오 삭제 완료 | ID: %d", id)
	c.JSON(http.StatusOK, gin.H{"deleted": id})
}

// ActivateTestScenario POST /api/v1/scenarios/:id/activate
func (h *Handler) ActivateTestScenario(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		LogAndRespondError(c, http.StatusBadRequest, "올바르지 않은 ID 형식입니다.", err)
		return
	}

	var target models.TestScenario
	if err := h.DB.WithContext(c.Request.Context()).First(&target, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			LogAndRespondError(c, http.StatusNotFound, "활성화 타겟 테스트 시나리오를 찾을 수 없습니다.", err)
		} else {
			LogAndRespondError(c, http.StatusInternalServerError, "활성화 타겟 테스트 시나리오를 조회하는 중 오류가 발생했습니다.", err)
		}
		return
	}

	// 트랜잭션을 통해 기존 설정들을 비활성화하고 대상 시나리오를 활성화
	err = h.DB.WithContext(c.Request.Context()).Transaction(func(tx *gorm.DB) error {
		return profile.ActivateScenarioInTx(tx, &target)
	})

	if err != nil {
		LogAndRespondError(c, http.StatusInternalServerError, "테스트 시나리오 활성 상태 전환을 실행하지 못했습니다.", err)
		return
	}

	LogInfo("[SUCCESS] 테스트 시나리오 활성화 완료 | ID: %d, Robot: %s, Env: %s", id, target.RobotName, target.Environment)
	c.JSON(http.StatusOK, gin.H{"message": "activated successfully", "id": id})
}

// GetActiveTestScenario GET /api/v1/scenarios/active
// 디바이스/CLI용: 특정 로봇/환경 기준 활성 시나리오를 조회합니다.
func (h *Handler) GetActiveTestScenario(c *gin.Context) {
	robotName := c.Query("robot_name")
	env := c.Query("environment")

	if robotName == "" || env == "" {
		LogAndRespondError(c, http.StatusBadRequest, "robot_name 및 environment 매개변수는 필수입니다.", nil)
		return
	}

	var scenario models.TestScenario
	err := h.DB.WithContext(c.Request.Context()).
		Where("robot_name = ? AND environment = ? AND is_active = ?", robotName, env, true).
		First(&scenario).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			LogAndRespondError(c, http.StatusNotFound, fmt.Sprintf("해당 로봇(%s)/환경(%s)에서 활성화된 테스트 시나리오를 찾을 수 없습니다.", robotName, env), err)
		} else {
			LogAndRespondError(c, http.StatusInternalServerError, "활성 테스트 시나리오를 조회하는 중 에러가 발생했습니다.", err)
		}
		return
	}

	c.JSON(http.StatusOK, scenario)
}
