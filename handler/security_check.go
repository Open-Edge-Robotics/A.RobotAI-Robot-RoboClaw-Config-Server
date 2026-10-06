package handler

import (
	"fmt"
	"net"
	"net/url"
	"slices"
	"strings"

	"ai-config-server/config"
)

// CheckInsecureDefaults는 인증/CORS가 안전하지 않은 기본값(토큰 미설정, CORS 전체 허용)으로
// 되어 있는지 점검하고, 발견된 문제를 사람이 읽을 수 있는 메시지 목록으로 반환합니다.
// ValidateProductionConfig는 운영 서버가 시작되기 전에 안전하지 않은
// 인증/CORS 설정을 차단한다. 경고만 출력하는 CheckInsecureDefaults와 달리
// 호출자가 반환된 오류를 반드시 처리해야 한다.
func ValidateProductionConfig(cfg *config.Config) error {
	if cfg == nil {
		return fmt.Errorf("configuration is nil")
	}
	if !cfg.Security.RequireAuth {
		return fmt.Errorf("security.require_auth must be true in production")
	}
	if strings.TrimSpace(cfg.Security.AdminToken) == "" {
		return fmt.Errorf("security.admin_token must be configured")
	}
	if strings.TrimSpace(cfg.Security.DeviceToken) == "" {
		return fmt.Errorf("security.device_token must be configured")
	}
	if len(cfg.Security.AdminToken) < 32 || len(cfg.Security.DeviceToken) < 32 {
		return fmt.Errorf("security tokens must be at least 32 characters")
	}
	if len(cfg.Security.CorsAllowedOrigins) == 0 {
		return fmt.Errorf("security.cors_allowed_origins must contain at least one origin")
	}
	for _, origin := range cfg.Security.CorsAllowedOrigins {
		if origin == "*" {
			return fmt.Errorf("wildcard CORS origin is not allowed")
		}
		u, err := url.Parse(origin)
		if err != nil || u.Host == "" {
			return fmt.Errorf("invalid CORS origin URL: %q", origin)
		}
		if u.Scheme != "https" {
			host := u.Hostname()
			if !isLocalOrPrivate(host) {
				return fmt.Errorf("CORS origin must be an https URL: %q", origin)
			}
		}
	}
	return nil
}

func isLocalOrPrivate(host string) bool {
	if host == "localhost" {
		return true
	}
	ip := net.ParseIP(host)
	if ip == nil {
		return false
	}
	return ip.IsLoopback() || ip.IsPrivate()
}

func CheckInsecureDefaults(cfg *config.Config) []string {
	var issues []string

	if cfg.Security.AdminToken == "" {
		issues = append(issues, "admin_token이 비어 있어 관리자 API가 인증 없이 열려 있습니다.")
	}
	if cfg.Security.AdminToken == "" && cfg.Security.DeviceToken == "" {
		issues = append(issues, "admin_token과 device_token이 모두 비어 있어 디바이스 API가 인증 없이 열려 있습니다.")
	}

	corsOpen := len(cfg.Security.CorsAllowedOrigins) == 0 ||
		slices.Contains(cfg.Security.CorsAllowedOrigins, "*")
	if corsOpen {
		issues = append(issues, "cors_allowed_origins가 비어있거나 '*'로 설정되어 모든 출처의 요청을 허용합니다.")
	}

	return issues
}
