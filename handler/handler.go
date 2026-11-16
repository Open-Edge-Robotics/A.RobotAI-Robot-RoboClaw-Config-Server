package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// Handler 는 HTTP 계층이 사용하는 상태(DB 핸들, 배포 캐시)를 소유한다.
// 서버마다 별도 Handler 를 만들기 때문에 테스트나 멀티 서버 구성에서도
// 요청 상태가 서로 섞이지 않는다.
type Handler struct {
	DB    *gorm.DB
	cache *activeConfigCache
}

// NewHandler 는 주어진 DB 로 Handler 를 만든다. DB 커넥션의 소유권은 호출자에게
// 있으며 Handler 는 닫지 않는다.
func NewHandler(db *gorm.DB) *Handler {
	return &Handler{DB: db, cache: newActiveConfigCache()}
}

// Ping GET /ping
// 서버 구동 및 접속 상태를 테스트하기 위한 헬스체크 핑 API입니다.
func Ping(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "pong"})
}

// Ready verifies that the process can reach its configured database.
func (h *Handler) Ready(c *gin.Context) {
	if h.DB == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"ready": false, "error": "database is not initialized"})
		return
	}
	sqlDB, err := h.DB.DB()
	if err != nil || sqlDB.Ping() != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"ready": false, "error": "database is unavailable"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ready": true})
}
