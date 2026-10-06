package handler

import (
	"fmt"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"ai-config-server/database"
	"ai-config-server/database/models"
)

// activeCacheEntry는 로봇/환경별 활성 설정과, 이미 생성된 파일 콘텐츠를 함께 캐싱합니다.
type activeCacheEntry struct {
	config models.RoboClawConfig
	files  map[string][]byte
}

var (
	activeCache   = make(map[string]*activeCacheEntry)
	activeCacheMu sync.RWMutex
)

// clearActiveCache는 캐싱된 배포 데이터를 모두 초기화합니다.
func clearActiveCache() {
	activeCacheMu.Lock()
	activeCache = make(map[string]*activeCacheEntry)
	activeCacheMu.Unlock()
}

// GetActiveConfig GET /api/v1/configs/active
// 디바이스용: 특정 로봇/환경 기준 활성 설정을 조회합니다.
func GetActiveConfig(c *gin.Context) {
	robotName := c.Query("robot_name")
	env := c.Query("environment")

	if robotName == "" || env == "" {
		LogAndRespondError(c, http.StatusBadRequest, "robot_name 및 environment 매개변수는 필수입니다.", nil)
		return
	}

	cacheKey := robotName + ":" + env

	activeCacheMu.RLock()
	entry, found := activeCache[cacheKey]
	activeCacheMu.RUnlock()

	if found {
		response := entry.config
		maskSensitiveFields(&response)
		c.Header("Cache-Control", "no-store")
		c.JSON(http.StatusOK, response)
		return
	}

	var config models.RoboClawConfig
	err := database.DB.Where("robot_name = ? AND environment = ? AND is_active = ?", robotName, env, true).First(&config).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			LogAndRespondError(c, http.StatusNotFound, fmt.Sprintf("해당 로봇(%s)/환경(%s)에서 활성화된 설정을 찾을 수 없습니다.", robotName, env), err)
		} else {
			LogAndRespondError(c, http.StatusInternalServerError, "활성 설정을 데이터베이스에서 조회 중 에러가 발생했습니다.", err)
		}
		return
	}
	applyButlerPathDefaults(&config)

	activeCacheMu.Lock()
	if _, exists := activeCache[cacheKey]; !exists {
		activeCache[cacheKey] = &activeCacheEntry{
			config: config,
			files:  make(map[string][]byte),
		}
	} else {
		activeCache[cacheKey].config = config
	}
	activeCacheMu.Unlock()

	response := config
	maskSensitiveFields(&response)
	c.Header("Cache-Control", "no-store")
	c.JSON(http.StatusOK, response)
}

// GetActiveRuntimeConfigV2 exposes a versioned, self-describing runtime
// manifest while keeping the v1 endpoints available during migration.
func GetActiveRuntimeConfigV2(c *gin.Context) {
	robotName := c.Query("robot_name")
	env := c.Query("environment")
	if robotName == "" || env == "" {
		LogAndRespondError(c, http.StatusBadRequest, "robot_name 및 environment 매개변수는 필수입니다.", nil)
		return
	}

	var config models.RoboClawConfig
	if err := database.DB.Where("robot_name = ? AND environment = ? AND is_active = ?", robotName, env, true).First(&config).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			LogAndRespondError(c, http.StatusNotFound, "활성화된 runtime 설정을 찾을 수 없습니다.", err)
			return
		}
		LogAndRespondError(c, http.StatusInternalServerError, "runtime 설정을 조회하는 중 오류가 발생했습니다.", err)
		return
	}
	applyButlerPathDefaults(&config)

	response := config
	maskSensitiveFields(&response)
	c.Header("Cache-Control", "no-store")
	c.JSON(http.StatusOK, gin.H{
		"schema_version":  "2.0",
		"config_revision": config.UpdatedAt.UTC().Format("20060102T150405.000000000Z07:00"),
		"robot_name":      config.RobotName,
		"environment":     config.Environment,
		"config":          response,
	})
}

// GetActiveConfigFile GET /api/v1/configs/active/files/:filename
// 디바이스용: 특정 로봇/환경의 마크다운 설정 파일 또는 .env 파일을 다운로드합니다.
func GetActiveConfigFile(c *gin.Context) {
	robotName := c.Query("robot_name")
	env := c.Query("environment")
	filename := c.Param("filename")

	if robotName == "" || env == "" {
		LogAndRespondError(c, http.StatusBadRequest, "robot_name 및 environment 매개변수는 필수입니다.", nil)
		return
	}

	cacheKey := robotName + ":" + env

	activeCacheMu.RLock()
	entry, found := activeCache[cacheKey]
	var fileContent []byte
	var fileFound bool
	if found {
		fileContent, fileFound = entry.files[filename]
	}
	activeCacheMu.RUnlock()

	if fileFound {
		respondFile(c, filename, fileContent)
		return
	}

	var config models.RoboClawConfig
	if found {
		config = entry.config
	} else {
		err := database.DB.Where("robot_name = ? AND environment = ? AND is_active = ?", robotName, env, true).First(&config).Error
		if err != nil {
			if err == gorm.ErrRecordNotFound {
				LogAndRespondError(c, http.StatusNotFound, "활성화된 설정을 데이터베이스에서 찾을 수 없어 파일을 반환하지 못했습니다.", err)
			} else {
				LogAndRespondError(c, http.StatusInternalServerError, "활성 설정 파일을 구성하는 도중 에러가 발생했습니다.", err)
			}
			return
		}
		applyButlerPathDefaults(&config)
	}

	content, ok := buildConfigFileContent(&config, filename)
	if !ok {
		LogAndRespondError(c, http.StatusNotFound, "요청한 파일명을 찾을 수 없습니다. (지원: .env, ROBOT.md, SKILLS.md, TROUBLESHOOTING.md, ROBOT_LIMITS.json)", nil)
		return
	}

	activeCacheMu.Lock()
	ent, ok := activeCache[cacheKey]
	if !ok {
		ent = &activeCacheEntry{
			config: config,
			files:  make(map[string][]byte),
		}
		activeCache[cacheKey] = ent
	}
	ent.files[filename] = content
	activeCacheMu.Unlock()

	respondFile(c, filename, content)
}
