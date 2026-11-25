package handler

import (
	"net/http"
	"path"
	"strings"

	"ai-config-server/config"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// NewRouter 는 모든 API 라우트를 중앙에서 등록하는 Gin 라우터 팩토리다.
// 라우터는 자신이 쓰는 Handler 를 직접 만들어 소유하므로, DB 핸들과 요청 제한
// 버킷 및 배포 캐시가 라우터 단위로 분리된다. DB 커넥션 소유권은 호출자에게 있다.
func NewRouter(cfg *config.Config, db *gorm.DB) *gin.Engine {
	h := NewHandler(db)
	r := gin.Default()

	r.Use(SecurityHeaders())
	r.Use(MaxRequestBody(10 << 20))
	r.Use(CORS(cfg))
	r.Use(LimitRate(20, 40))
	r.GET("/ping", Ping)
	r.GET("/ready", h.Ready)

	// Robo Claw Config API
	v1 := r.Group("/api/v1")
	{
		// 로봇 디바이스 배포 API (Device Token 필요)
		deviceGroup := v1.Group("")
		deviceGroup.Use(RequireDevice(cfg))
		{
			deviceGroup.GET("/configs", h.ListConfigs)
			deviceGroup.GET("/configs/active", h.GetActiveConfig)
			deviceGroup.GET("/configs/active/files/:filename", h.GetActiveConfigFile)
			deviceGroup.GET("/scenarios/active", h.GetActiveTestScenario)
		}

		// 설정 관리 대시보드 API (Admin Token 필요)
		adminGroup := v1.Group("/admin")
		adminGroup.Use(RequireAdmin(cfg))
		{
			adminGroup.GET("/configs", h.ListConfigs)
			adminGroup.GET("/configs/:id", h.GetConfig)
			adminGroup.GET("/configs/:id/files/:filename", h.GetConfigFile)
			adminGroup.POST("/configs", h.CreateConfig)
			adminGroup.PUT("/configs/:id", h.UpdateConfig)
			adminGroup.PATCH("/configs/:id", h.UpdateConfig)
			adminGroup.DELETE("/configs/:id", h.DeleteConfig)
			adminGroup.POST("/configs/:id/activate", h.ActivateConfig)
			adminGroup.POST("/configs/:id/clone", h.CloneConfig)

			// MCP 서버 카탈로그 (자동 검색/찾아보기)
			adminGroup.GET("/mcp/catalog", ListMcpCatalog(cfg))

			adminGroup.GET("/scenarios", h.ListTestScenarios)
			adminGroup.GET("/scenarios/:id", h.GetTestScenario)
			adminGroup.POST("/scenarios", h.CreateTestScenario)
			adminGroup.PUT("/scenarios/:id", h.UpdateTestScenario)
			adminGroup.PATCH("/scenarios/:id", h.PatchTestScenario)
			adminGroup.DELETE("/scenarios/:id", h.DeleteTestScenario)
			adminGroup.POST("/scenarios/:id/activate", h.ActivateTestScenario)
			adminGroup.POST("/scenarios/:id/clone", h.CloneTestScenario)

			// 이식용 백업 내보내기/가져오기
			adminGroup.GET("/transfer/export", h.ExportBackup)
			adminGroup.POST("/transfer/export", h.ExportBackup)
			adminGroup.POST("/transfer/import/validate", h.ValidateImport)
			adminGroup.POST("/transfer/import", h.ImportBackup)
		}
	}

	// Versioned runtime manifest. v1 device endpoints remain unchanged during migration.
	v2Device := r.Group("/api/v2/device")
	v2Device.Use(RequireDevice(cfg))
	v2Device.GET("/runtime-config", h.GetActiveRuntimeConfigV2)

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
