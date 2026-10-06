package handler

import (
	"crypto/subtle"
	"errors"
	"net/http"
	"strings"

	"ai-config-server/config"
	"github.com/gin-gonic/gin"
)

// extractToken은 Authorization 헤더에서 Bearer 토큰을 추출합니다.
func extractToken(c *gin.Context) (string, error) {
	authHeader := c.GetHeader("Authorization")
	if authHeader == "" {
		return "", errors.New("Authorization 헤더가 누락되었습니다.")
	}

	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return "", errors.New("Authorization 헤더 형식이 올바르지 않습니다. (예: Bearer <token>)")
	}

	return parts[1], nil
}

// RequireAdmin은 대시보드 관리자 권한을 요구하는 미들웨어입니다.
func RequireAdmin(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenSetting := cfg.Security.AdminToken
		if tokenSetting == "" && !cfg.Security.RequireAuth {
			c.Next()
			return
		}
		if tokenSetting == "" {
			LogAndRespondError(c, http.StatusUnauthorized, "인증이 구성되지 않았습니다.", errors.New("admin authentication is not configured"))
			c.Abort()
			return
		}

		token, err := extractToken(c)
		if err != nil {
			LogAndRespondError(c, http.StatusUnauthorized, "인증에 실패했습니다.", err)
			c.Abort()
			return
		}

		if !secureTokenEqual(token, tokenSetting) {
			LogAndRespondError(c, http.StatusUnauthorized, "올바르지 않은 관리자 인증 토큰입니다.", errors.New("invalid admin token"))
			c.Abort()
			return
		}

		c.Next()
	}
}

// secureTokenEqual은 토큰 비교 시 길이 및 내용에 따른 비교 시간 차이를 줄인다.
func secureTokenEqual(got, want string) bool {
	if len(got) != len(want) {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(got), []byte(want)) == 1
}

// RequireDevice는 로봇 디바이스 권한(또는 관리자 권한)을 요구하는 미들웨어입니다.
func RequireDevice(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		adminTokenSetting := cfg.Security.AdminToken
		deviceTokenSetting := cfg.Security.DeviceToken

		// 테스트/명시적 내부망 모드 외에는 토큰 누락을 허용하지 않는다.
		if adminTokenSetting == "" && deviceTokenSetting == "" && !cfg.Security.RequireAuth {
			c.Next()
			return
		}
		if adminTokenSetting == "" && deviceTokenSetting == "" {
			LogAndRespondError(c, http.StatusUnauthorized, "인증이 구성되지 않았습니다.", errors.New("device authentication is not configured"))
			c.Abort()
			return
		}

		token, err := extractToken(c)
		if err != nil {
			LogAndRespondError(c, http.StatusUnauthorized, "인증에 실패했습니다.", err)
			c.Abort()
			return
		}

		// 어드민 토큰이나 디바이스 토큰 중 하나라도 일치하면 허용
		isAdminValid := adminTokenSetting != "" && secureTokenEqual(token, adminTokenSetting)
		isDeviceValid := deviceTokenSetting != "" && secureTokenEqual(token, deviceTokenSetting)

		if !isAdminValid && !isDeviceValid {
			LogAndRespondError(c, http.StatusUnauthorized, "올바르지 않은 디바이스 인증 토큰입니다.", errors.New("invalid device token"))
			c.Abort()
			return
		}

		c.Next()
	}
}
