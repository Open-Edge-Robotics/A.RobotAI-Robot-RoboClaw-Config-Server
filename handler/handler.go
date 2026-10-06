package handler

import (
	"net/http"

	"ai-config-server/database"
	"github.com/gin-gonic/gin"
)

// Ping GET /ping
// 서버 구동 및 접속 상태를 테스트하기 위한 헬스체크 핑 API입니다.
func Ping(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "pong"})
}

// Ready verifies that the process can reach its configured database.
func Ready(c *gin.Context) {
	if database.DB == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"ready": false, "error": "database is not initialized"})
		return
	}
	sqlDB, err := database.DB.DB()
	if err != nil || sqlDB.Ping() != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"ready": false, "error": "database is unavailable"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ready": true})
}
