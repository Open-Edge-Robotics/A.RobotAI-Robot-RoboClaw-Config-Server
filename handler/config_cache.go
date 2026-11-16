package handler

import (
	"fmt"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"ai-config-server/database/models"
)

// activeCacheKey 는 배포 캐시의 조회 키다. 문자열로 이어 붙이면 값에 구분자가
// 들어갈 때 서로 다른 (로봇, 환경) 조합이 충돌하므로 구조체로 구분한다.
type activeCacheKey struct {
	robotName   string
	environment string
}

// activeCacheEntry는 로봇/환경별 활성 설정과, 이미 생성된 파일 콘텐츠를 함께 캐싱합니다.
type activeCacheEntry struct {
	config models.RoboClawConfig
	files  map[string][]byte
}

// activeConfigCache 는 Handler 한 개가 소유하는 활성 배포 캐시다.
// generation 은 무효화 세대 번호로, DB 조회 중 무효화가 일어난 뒤 뒤늦게
// 도착한 오래된 결과가 캐시를 다시 채우는 것을 막는다.
type activeConfigCache struct {
	mu         sync.RWMutex
	generation uint64
	entries    map[activeCacheKey]*activeCacheEntry
}

func newActiveConfigCache() *activeConfigCache {
	return &activeConfigCache{entries: make(map[activeCacheKey]*activeCacheEntry)}
}

// currentGeneration 은 현재 무효화 세대를 반환한다. DB 조회 전에 스냅샷을 떠서
// storeConfig/storeFile 로 넘기면, 그 사이 clear 가 실행된 경우 저장이 무시된다.
func (c *activeConfigCache) currentGeneration() uint64 {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.generation
}

// config 는 캐시된 설정의 값 복사본을 반환한다. 잠금 밖에서 원본을 읽지 않도록
// 항상 복사본만 돌려준다.
func (c *activeConfigCache) config(key activeCacheKey) (models.RoboClawConfig, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	entry, ok := c.entries[key]
	if !ok {
		return models.RoboClawConfig{}, false
	}
	return entry.config, true
}

// file 은 캐시된 파일 콘텐츠의 복사본을 반환한다.
func (c *activeConfigCache) file(key activeCacheKey, filename string) ([]byte, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	entry, ok := c.entries[key]
	if !ok {
		return nil, false
	}
	content, ok := entry.files[filename]
	if !ok {
		return nil, false
	}
	return append([]byte(nil), content...), true
}

// storeConfig 는 gen 세대에서 읽은 설정을 캐시에 넣는다. 그 사이 캐시가
// 무효화되어 세대가 바뀌었다면 오래된 값이므로 저장하지 않는다.
func (c *activeConfigCache) storeConfig(key activeCacheKey, cfg models.RoboClawConfig, gen uint64) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.generation != gen {
		return false
	}
	entry, ok := c.entries[key]
	if !ok {
		entry = &activeCacheEntry{files: make(map[string][]byte)}
		c.entries[key] = entry
	}
	entry.config = cfg
	return true
}

// storeFile 은 gen 세대에서 생성한 파일 콘텐츠를 캐시에 넣는다.
// 설정 본문도 함께 저장해, 파일 요청이 먼저 캐시를 채우더라도 이후 활성 설정
// 조회가 빈 프로필을 돌려주지 않도록 한다. 두 값은 같은 잠금 안에서 갱신된다.
func (c *activeConfigCache) storeFile(key activeCacheKey, filename string, content []byte, cfg models.RoboClawConfig, gen uint64) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.generation != gen {
		return false
	}
	entry, ok := c.entries[key]
	if !ok {
		entry = &activeCacheEntry{files: make(map[string][]byte)}
		c.entries[key] = entry
	}
	entry.config = cfg
	entry.files[filename] = append([]byte(nil), content...)
	return true
}

// clear 는 캐시를 모두 비우고 세대를 올린다. 세대 증가로 인해 진행 중이던
// 조회 결과는 캐시에 반영되지 않는다.
func (c *activeConfigCache) clear() {
	c.mu.Lock()
	c.generation++
	c.entries = make(map[activeCacheKey]*activeCacheEntry)
	c.mu.Unlock()
}

// GetActiveConfig GET /api/v1/configs/active
// 디바이스용: 특정 로봇/환경 기준 활성 설정을 조회합니다.
func (h *Handler) GetActiveConfig(c *gin.Context) {
	robotName := c.Query("robot_name")
	env := c.Query("environment")

	if robotName == "" || env == "" {
		LogAndRespondError(c, http.StatusBadRequest, "robot_name 및 environment 매개변수는 필수입니다.", nil)
		return
	}

	cacheKey := activeCacheKey{robotName: robotName, environment: env}

	if cached, found := h.cache.config(cacheKey); found {
		response := cached
		maskSensitiveFields(&response)
		c.Header("Cache-Control", "no-store")
		c.JSON(http.StatusOK, response)
		return
	}

	generation := h.cache.currentGeneration()

	var config models.RoboClawConfig
	err := h.DB.WithContext(c.Request.Context()).
		Where("robot_name = ? AND environment = ? AND is_active = ?", robotName, env, true).
		First(&config).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			LogAndRespondError(c, http.StatusNotFound, fmt.Sprintf("해당 로봇(%s)/환경(%s)에서 활성화된 설정을 찾을 수 없습니다.", robotName, env), err)
		} else {
			LogAndRespondError(c, http.StatusInternalServerError, "활성 설정을 데이터베이스에서 조회 중 에러가 발생했습니다.", err)
		}
		return
	}
	applyButlerPathDefaults(&config)

	h.cache.storeConfig(cacheKey, config, generation)

	response := config
	maskSensitiveFields(&response)
	c.Header("Cache-Control", "no-store")
	c.JSON(http.StatusOK, response)
}

// GetActiveRuntimeConfigV2 exposes a versioned, self-describing runtime
// manifest while keeping the v1 endpoints available during migration.
func (h *Handler) GetActiveRuntimeConfigV2(c *gin.Context) {
	robotName := c.Query("robot_name")
	env := c.Query("environment")
	if robotName == "" || env == "" {
		LogAndRespondError(c, http.StatusBadRequest, "robot_name 및 environment 매개변수는 필수입니다.", nil)
		return
	}

	var config models.RoboClawConfig
	if err := h.DB.WithContext(c.Request.Context()).
		Where("robot_name = ? AND environment = ? AND is_active = ?", robotName, env, true).
		First(&config).Error; err != nil {
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
func (h *Handler) GetActiveConfigFile(c *gin.Context) {
	robotName := c.Query("robot_name")
	env := c.Query("environment")
	filename := c.Param("filename")

	if robotName == "" || env == "" {
		LogAndRespondError(c, http.StatusBadRequest, "robot_name 및 environment 매개변수는 필수입니다.", nil)
		return
	}

	cacheKey := activeCacheKey{robotName: robotName, environment: env}

	if fileContent, fileFound := h.cache.file(cacheKey, filename); fileFound {
		respondFile(c, filename, fileContent)
		return
	}

	generation := h.cache.currentGeneration()

	var config models.RoboClawConfig
	if cachedConfig, found := h.cache.config(cacheKey); found {
		config = cachedConfig
	} else {
		err := h.DB.WithContext(c.Request.Context()).
			Where("robot_name = ? AND environment = ? AND is_active = ?", robotName, env, true).
			First(&config).Error
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

	h.cache.storeFile(cacheKey, filename, content, config, generation)

	respondFile(c, filename, content)
}
