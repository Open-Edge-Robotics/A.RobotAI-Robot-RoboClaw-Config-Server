package testutil

import (
	"ai-config-server/config"
)

// NewTestConfig 는 기본 설정 구조체를 반환한다. overrides 로 개별 필드를 바꿀 수 있다.
func NewTestConfig(overrides ...func(*config.Config)) *config.Config {
	cfg := &config.Config{}
	// 테스트는 인증 미들웨어 자체가 아닌 핸들러 동작을 검증하는 경우가 많다.
	// 운영 설정의 fail-closed 기본값을 명시적으로 비활성화한다.
	cfg.Security.RequireAuth = false
	for _, o := range overrides {
		o(cfg)
	}
	return cfg
}
