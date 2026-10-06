package handler

import (
	"net/http"
	"path"
	"strings"

	"ai-config-server/config"
	"github.com/gin-gonic/gin"
)

// NewRouter 는 모든 API 라우트를 중앙에서 등록하는 Gin 라우터 팩토리다.
// cmd/serve.go 가 아닌 여기에서 라우트를 구성하므로, 실제 인증 미들웨어와
// URL 경로 계약을 그대로 검증하는 통합 테스트를 작성할 수 있다.
//
// TODO(로드맵): database.DB 전역 의존을 제거하고 *gorm.DB 를 인자로 받도록
// 개선한다. (AGENTS.md / docs/testing.md 참고)
func NewRouter(cfg *config.Config) *gin.Engine {
	r := gin.Default()

	r.Use(SecurityHeaders())
	r.Use(MaxRequestBody(10 << 20))
	r.Use(CORS(cfg))
	r.Use(LimitRate(20, 40))
	r.GET("/ping", Ping)
	r.GET("/ready", Ready)

	// Robo Claw Config API
	v1 := r.Group("/api/v1")
	{
		// 로봇 디바이스 배포 API (Device Token 필요)
		deviceGroup := v1.Group("")
		deviceGroup.Use(RequireDevice(cfg))
		{
			deviceGroup.GET("/configs", ListConfigs)
			deviceGroup.GET("/configs/active", GetActiveConfig)
			deviceGroup.GET("/configs/active/files/:filename", GetActiveConfigFile)
			deviceGroup.GET("/scenarios/active", GetActiveTestScenario)
		}

		// 설정 관리 대시보드 API (Admin Token 필요)
		adminGroup := v1.Group("/admin")
		adminGroup.Use(RequireAdmin(cfg))
		{
			adminGroup.GET("/configs", ListConfigs)
			adminGroup.GET("/configs/:id", GetConfig)
			adminGroup.GET("/configs/:id/files/:filename", GetConfigFile)
			adminGroup.POST("/configs", CreateConfig)
			adminGroup.PUT("/configs/:id", UpdateConfig)
			adminGroup.PATCH("/configs/:id", UpdateConfig)
			adminGroup.DELETE("/configs/:id", DeleteConfig)
			adminGroup.POST("/configs/:id/activate", ActivateConfig)
			adminGroup.POST("/configs/:id/clone", CloneConfig)

			// MCP 서버 카탈로그 (자동 검색/찾아보기)
			adminGroup.GET("/mcp/catalog", ListMcpCatalog(cfg))

			adminGroup.GET("/scenarios", ListTestScenarios)
			adminGroup.GET("/scenarios/:id", GetTestScenario)
			adminGroup.POST("/scenarios", CreateTestScenario)
			adminGroup.PUT("/scenarios/:id", UpdateTestScenario)
			adminGroup.DELETE("/scenarios/:id", DeleteTestScenario)
			adminGroup.POST("/scenarios/:id/activate", ActivateTestScenario)
			adminGroup.POST("/scenarios/:id/clone", CloneTestScenario)

			// 이식용 백업 내보내기/가져오기
			adminGroup.GET("/transfer/export", ExportBackup)
			adminGroup.POST("/transfer/export", ExportBackup)
			adminGroup.POST("/transfer/import/validate", ValidateImport)
			adminGroup.POST("/transfer/import", ImportBackup)
		}
	}

	// Versioned runtime manifest. v1 device endpoints remain unchanged during migration.
	v2Device := r.Group("/api/v2/device")
	v2Device.Use(RequireDevice(cfg))
	v2Device.GET("/runtime-config", GetActiveRuntimeConfigV2)

	// 루트 접속 시 /web/ 으로 리다이렉트
	r.GET("/", func(c *gin.Context) {
		c.Redirect(http.StatusMovedPermanently, "/web/")
	})

	// Flutter Web 빌드 산출물 정적 서빙
	r.Static("/web", "./frontend/build/web")
	r.NoRoute(func(c *gin.Context) {
		requestPath := c.Request.URL.Path
		// /web 경계를 정확히 판별한다. HasPrefix 만 쓰면 /webhook 같은
		// 다른 경로까지 SPA fallback 에 삼켜진다.
		if requestPath != "/web" && !strings.HasPrefix(requestPath, "/web/") {
			c.JSON(http.StatusNotFound, gin.H{"error": "route not found"})
			return
		}

		// 확장자가 있는 경로는 정적 산출물(js/map/json/wasm/png 등)이다.
		// 여기에 index.html 을 200 으로 돌려주면 브라우저가 HTML 을 JS/JSON 으로
		// 파싱해 "JSON.parse: unexpected character" 소스 맵 오류를 내고,
		// 누락된 자산이 성공한 것처럼 위장되어 배포/캐시 문제 추적도 어려워진다.
		if path.Ext(requestPath) != "" {
			c.JSON(http.StatusNotFound, gin.H{
				"error": "static asset not found",
				"path":  requestPath,
			})
			return
		}

		// 확장자 없는 SPA 딥링크만 index.html 로 fallback 한다.
		c.File("./frontend/build/web/index.html")
	})

	return r
}
