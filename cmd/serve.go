package cmd

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"ai-config-server/config"
	"ai-config-server/database"
	"ai-config-server/handler"

	"github.com/wkqco33/wcli"
	"github.com/wkqco33/wcli/logging"
	"gorm.io/gorm"
)

// shutdownTimeout 은 SIGTERM/SIGINT 수신 후 진행 중인 요청을 기다리는 최대 시간이다.
// 이 시간이 지나면 남은 연결을 끊고 프로세스를 종료한다.
const shutdownTimeout = 10 * time.Second

func ServeCmd() *wcli.Command {
	return &wcli.Command{
		Use:   "serve",
		Short: "HTTP 서버를 시작합니다",
		PreRun: func(_ *wcli.Context) error {
			return InitConfig()
		},
		Run: func(_ *wcli.Context) error {
			ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
			defer stop()
			return runServe(ctx, Cfg())
		},
	}
}

// runServe 는 DB 와 HTTP 서버를 조립하고 종료 신호까지 서비스를 유지한다.
// DB 커넥션 소유권은 이 함수가 가지며, 반환 전에 정리한다.
func runServe(ctx context.Context, cfg *config.Config) error {
	if err := handler.ValidateProductionConfig(cfg); err != nil {
		return fmt.Errorf("안전하지 않은 프로덕션 보안 설정: %w", err)
	}
	db, err := database.Init(cfg.Database.Path)
	if err != nil {
		return fmt.Errorf("DB 초기화 실패: %w", err)
	}
	// 정리 오류가 서버 실행 결과를 덮어쓰지 않도록 로그로만 남긴다.
	defer closeDatabase(db)

	addr := fmt.Sprintf("%s:%d", cfg.Server.Host, cfg.Server.Port)
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("서버 소켓 열기 실패: %w", err)
	}

	logging.GetLogger().Log(logging.LevelInfo, "서버 시작: http://%s", addr)
	warnInsecureDefaults(cfg)

	server := &http.Server{
		Handler:           handler.NewRouter(cfg, db),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	return serveWithShutdown(ctx, server, ln, shutdownTimeout)
}

// serveWithShutdown 은 ctx 가 취소될 때까지 서버를 서비스하고, 취소되면
// 진행 중인 요청을 정리한 뒤 반환한다. Serve 고루틴은 반드시 회수한다.
func serveWithShutdown(ctx context.Context, server *http.Server, ln net.Listener, timeout time.Duration) error {
	serveErr := make(chan error, 1)
	go func() {
		serveErr <- server.Serve(ln)
	}()

	select {
	case err := <-serveErr:
		return serverResult(err)
	case <-ctx.Done():
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		// 남은 연결을 강제로 닫아 Serve 고루틴이 반환되게 한다.
		_ = server.Close()
		<-serveErr
		return fmt.Errorf("서버 종료 실패: %w", err)
	}
	if err := serverResult(<-serveErr); err != nil {
		return err
	}
	logging.GetLogger().Log(logging.LevelInfo, "서버 종료 완료")
	return nil
}

// serverResult 는 Serve 의 정상 종료(ErrServerClosed)를 성공으로 변환한다.
func serverResult(err error) error {
	if err == nil || errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return fmt.Errorf("서버 실행 실패: %w", err)
}

// closeDatabase 는 serve 명령이 소유한 DB 커넥션을 닫는다.
// 종료 경로에서 반환 에러를 덮어쓰지 않도록 실패는 로그로만 남긴다.
func closeDatabase(db *gorm.DB) {
	if db == nil {
		return
	}
	logger := logging.GetLogger()
	sqlDB, err := db.DB()
	if err != nil {
		logger.Log(logging.LevelError, "DB 커넥션 정리 실패: %v", err)
		return
	}
	if err := sqlDB.Close(); err != nil {
		logger.Log(logging.LevelError, "DB 커넥션 종료 실패: %v", err)
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
