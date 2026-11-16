package handler

import (
	"net/http"
	"testing"

	"github.com/wkqco33/wcli/logging"
)

// TestErrorLogLevel 은 예상된 4xx 가 장애 로그와 섞이지 않도록 레벨 규칙을 고정한다.
func TestErrorLogLevel(t *testing.T) {
	cases := []struct {
		name   string
		status int
		want   logging.LogLevel
	}{
		{"internal", http.StatusInternalServerError, logging.LevelError},
		{"unavailable", http.StatusServiceUnavailable, logging.LevelError},
		{"unauthorized", http.StatusUnauthorized, logging.LevelWarn},
		{"forbidden", http.StatusForbidden, logging.LevelWarn},
		{"rate_limited", http.StatusTooManyRequests, logging.LevelWarn},
		{"bad_request", http.StatusBadRequest, logging.LevelInfo},
		{"not_found", http.StatusNotFound, logging.LevelInfo},
		{"conflict", http.StatusConflict, logging.LevelInfo},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := errorLogLevel(tc.status); got != tc.want {
				t.Fatalf("status %d: expected %v, got %v", tc.status, tc.want, got)
			}
		})
	}
}
