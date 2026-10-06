package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/wkqco33/wcli/logging"
)

// APIErrorResponse는 모든 API에서 발생하는 실패 응답의 표준 형식입니다.
type APIErrorResponse struct {
	Error   string `json:"error"`
	Details string `json:"details,omitempty"`
}

// LogAndRespondError는 에러를 콘솔/로그 파일에 LevelError로 구조화하여 로깅하고,
// 클라이언트에게는 APIErrorResponse 포맷의 JSON 데이터로 일관되게 응답합니다.
func LogAndRespondError(c *gin.Context, statusCode int, userMsg string, sysErr error) {
	logger := logging.GetLogger()

	if sysErr != nil {
		logger.Log(logging.LevelError, "[API FAILED] URL: %s %s | Msg: %s | SysErr: %v", c.Request.Method, c.Request.URL.Path, userMsg, sysErr)
	} else {
		logger.Log(logging.LevelError, "[API FAILED] URL: %s %s | Msg: %s", c.Request.Method, c.Request.URL.Path, userMsg)
	}

	resp := APIErrorResponse{
		Error:   http.StatusText(statusCode),
		Details: userMsg,
	}

	// 500 에러 이외의 클라이언트 측 과실(400, 404 등)일 경우 시스템 에러 메시지도 함께 제공하여 디버깅 편의 지원
	if sysErr != nil && statusCode != http.StatusInternalServerError {
		resp.Details = userMsg + " (" + sysErr.Error() + ")"
	}

	c.JSON(statusCode, resp)
}

// LogInfo API 동작 성공 또는 정보 메시지를 서버에 남깁니다.
func LogInfo(format string, args ...any) {
	logging.GetLogger().Log(logging.LevelInfo, format, args...)
}

// LogWarn API 경고 메시지를 서버에 남깁니다.
func LogWarn(format string, args ...any) {
	logging.GetLogger().Log(logging.LevelWarn, format, args...)
}
