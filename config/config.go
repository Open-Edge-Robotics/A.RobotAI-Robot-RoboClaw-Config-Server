package config

// Config 애플리케이션 설정 구조체
type Config struct {
	Server struct {
		Host string `wcli:"HOST" default:"0.0.0.0"`
		Port int    `wcli:"PORT" default:"8080"`
	} `wcli:"SERVER"`
	Log struct {
		Level string `wcli:"LEVEL" default:"info"`
	} `wcli:"LOG"`
	Database struct {
		Path string `wcli:"PATH" default:"ai-config-server.db"`
	} `wcli:"DATABASE"`
	Security struct {
		AdminToken  string `wcli:"ADMIN_TOKEN" default:""`
		DeviceToken string `wcli:"DEVICE_TOKEN" default:""`
		// RequireAuth 는 인증 토큰이 누락된 경우 fail-closed 할지 결정한다.
		// 운영 환경에서는 반드시 true여야 한다.
		RequireAuth        bool     `wcli:"REQUIRE_AUTH" default:"true"`
		CorsAllowedOrigins []string `wcli:"CORS_ALLOWED_ORIGINS"`
	} `wcli:"SECURITY"`
	MCP struct {
		// RegistryURL이 설정되면 MCP 서버 카탈로그 조회 시 해당 레지스트리를
		// 먼저 시도하고, 실패하거나 비어 있으면 내장 큐레이티드 카탈로그로 폴백한다.
		// 예: https://registry.modelcontextprotocol.io
		RegistryURL string `wcli:"REGISTRY_URL" default:""`
	} `wcli:"MCP"`
}
