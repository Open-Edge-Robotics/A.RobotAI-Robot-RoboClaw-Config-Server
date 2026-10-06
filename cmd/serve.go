package cmd

import (
	"fmt"
	"net/http"
	"time"

	"ai-config-server/config"
	"ai-config-server/database"
	"ai-config-server/handler"

	"github.com/wkqco33/wcli"
	"github.com/wkqco33/wcli/logging"
)

func ServeCmd() *wcli.Command {
	return &wcli.Command{
		Use:   "serve",
		Short: "HTTP 서버를 시작합니다",
		Run: func(ctx *wcli.Context) error {
			if err := handler.ValidateProductionConfig(Cfg()); err != nil {
				return fmt.Errorf("안전하지 않은 프로덕션 보안 설정: %w", err)
			}
			if err := database.Init(cfg.Database.Path); err != nil {
				return fmt.Errorf("DB 초기화 실패: %w", err)
			}
			addr := fmt.Sprintf("%s:%d", cfg.Server.Host, cfg.Server.Port)
			logging.GetLogger().Log(logging.LevelInfo, "서버 시작: http://%s", addr)
			warnInsecureDefaults(Cfg())

			r := handler.NewRouter(Cfg())

			server := &http.Server{
				Addr:              addr,
				Handler:           r,
				ReadHeaderTimeout: 5 * time.Second,
				ReadTimeout:       30 * time.Second,
				WriteTimeout:      60 * time.Second,
				IdleTimeout:       120 * time.Second,
			}
			return server.ListenAndServe()
		},
	}
}

// warnInsecureDefaults는 인증/CORS가 안전하지 않은 기본값으로 설정된 경우
// 서버 기동 시점에 눈에 띄는 경고 배너를 1회 출력합니다.
func warnInsecureDefaults(cfg *config.Config) {
	issues := handler.CheckInsecureDefaults(cfg)
	if len(issues) == 0 {
		return
	}

	logger := logging.GetLogger()
	logger.Log(logging.LevelWarn, "================================================================")
	logger.Log(logging.LevelWarn, "[SECURITY WARNING] 안전하지 않은 기본 설정이 감지되었습니다:")
	for _, issue := range issues {
		logger.Log(logging.LevelWarn, "  - %s", issue)
	}
	logger.Log(logging.LevelWarn, "내부망 전용이 아니라면 config.yaml 또는 환경변수로 반드시 값을 설정하세요.")
	logger.Log(logging.LevelWarn, "================================================================")
}
