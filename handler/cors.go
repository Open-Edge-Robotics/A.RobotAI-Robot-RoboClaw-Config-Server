package handler

import (
	"net/http"

	"ai-config-server/config"
	"github.com/gin-gonic/gin"
)

// CORS는 허용된 Origin에 대해 크로스 오리진 요청을 처리하는 미들웨어입니다.
func CORS(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		if origin == "" {
			c.Next()
			return
		}

		// 허용 리스트 검증
		allowed := false
		if len(cfg.Security.CorsAllowedOrigins) == 0 {
			// 기본적으로 아무것도 설정 안 되어 있으면 모두 허용 (내부망 편의)
			allowed = true
		} else {
			for _, o := range cfg.Security.CorsAllowedOrigins {
				if o == "*" || o == origin {
					allowed = true
					break
				}
			}
		}

		if allowed {
			c.Header("Access-Control-Allow-Origin", origin)
			c.Header("Vary", "Origin")
			// 와일드카드 Origin과 credentials를 함께 사용하지 않는다.
			// 운영 설정에서는 ValidateProductionConfig가 와일드카드를 거부한다.
			if len(cfg.Security.CorsAllowedOrigins) > 0 {
				c.Header("Access-Control-Allow-Credentials", "true")
			}
			c.Header("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
			c.Header("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")
		}

		// Preflight OPTIONS 요청 신속 처리
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}
