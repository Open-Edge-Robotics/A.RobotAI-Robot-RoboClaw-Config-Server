package cmd

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"ai-config-server/config"
	"ai-config-server/database"
	"ai-config-server/handler"

	"github.com/gin-gonic/gin"
)

// TestServeWiringServesReady 는 serve 명령의 배선(DB 소유 → 라우터 생성)이
// 실제로 준비 상태 확인까지 동작하는지 검증한다.
func TestServeWiringServesReady(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := database.Init(filepath.Join(t.TempDir(), "serve.db"))
	if err != nil {
		t.Fatalf("DB 초기화 실패: %v", err)
	}
	t.Cleanup(func() { closeDatabase(db) })

	router := handler.NewRouter(&config.Config{}, db)

	req, err := http.NewRequest("GET", "/ready", nil)
	if err != nil {
		t.Fatal(err)
	}
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 from /ready, got %d: %s", w.Code, w.Body.String())
	}
}

// TestCloseDatabaseClosesConnection 은 서버 종료 시 소유한 DB 커넥션이 닫히는지
// 검증한다. 닫힌 뒤에는 준비 상태 확인이 503 이 되어야 한다.
func TestCloseDatabaseClosesConnection(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := database.Init(filepath.Join(t.TempDir(), "serve.db"))
	if err != nil {
		t.Fatalf("DB 초기화 실패: %v", err)
	}
	closeDatabase(db)

	sqlDB, err := db.DB()
	if err != nil {
		t.Fatalf("sql.DB 획득 실패: %v", err)
	}
	if err := sqlDB.Ping(); err == nil {
		t.Fatal("expected ping to fail after closing the connection")
	}

	router := handler.NewRouter(&config.Config{}, db)
	req, err := http.NewRequest("GET", "/ready", nil)
	if err != nil {
		t.Fatal(err)
	}
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 after closing DB, got %d", w.Code)
	}
}

// TestCloseDatabaseIgnoresNil 은 DB 없이 종료 경로를 타도 패닉이 없는지 검증한다.
func TestCloseDatabaseIgnoresNil(t *testing.T) {
	closeDatabase(nil)
}

// TestServeWithShutdownStopsOnContextCancel 은 종료 신호를 받으면 진행 중인
// 요청을 마무리한 뒤 서버와 리스너를 닫고 정상 반환하는지 검증한다.
func TestServeWithShutdownStopsOnContextCancel(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	server := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})}

	ctx, cancel := context.WithCancel(t.Context())
	done := make(chan error, 1)
	go func() { done <- serveWithShutdown(ctx, server, ln, 2*time.Second) }()

	url := "http://" + ln.Addr().String() + "/"
	waitForHTTP(t, url)
	cancel()

	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("expected graceful shutdown, got %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("serveWithShutdown did not return after cancellation")
	}

	if _, err := http.Get(url); err == nil {
		t.Fatal("expected the listener to be closed after shutdown")
	}
}

// TestServeWithShutdownReturnsServeError 는 리스너 오류가 실행 실패로
// 보고되는지 검증한다.
func TestServeWithShutdownReturnsServeError(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	if err := ln.Close(); err != nil {
		t.Fatal(err)
	}
	server := &http.Server{Handler: http.HandlerFunc(func(http.ResponseWriter, *http.Request) {})}

	err = serveWithShutdown(t.Context(), server, ln, time.Second)
	if err == nil {
		t.Fatal("expected an error when the listener is already closed")
	}
	if !strings.Contains(err.Error(), "서버 실행 실패") {
		t.Fatalf("unexpected error message: %v", err)
	}
}

// TestServeWithShutdownReportsShutdownTimeout 은 종료 대기 시간을 넘긴 요청이
// 있으면 실패로 보고하고 남은 연결을 닫는지 검증한다.
func TestServeWithShutdownReportsShutdownTimeout(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	release := make(chan struct{})
	defer close(release)
	entered := make(chan struct{}, 1)
	server := &http.Server{Handler: http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		entered <- struct{}{}
		<-release
	})}

	ctx, cancel := context.WithCancel(t.Context())
	done := make(chan error, 1)
	go func() { done <- serveWithShutdown(ctx, server, ln, 20*time.Millisecond) }()

	url := "http://" + ln.Addr().String() + "/"
	requestDone := make(chan struct{})
	go func() {
		defer close(requestDone)
		if resp, err := http.Get(url); err == nil {
			_ = resp.Body.Close()
		}
	}()
	waitForHTTPConnection(t, ln.Addr().String())
	select {
	case <-entered:
	case <-time.After(2 * time.Second):
		t.Fatal("handler did not start before shutdown")
	}
	cancel()

	select {
	case err := <-done:
		if err == nil {
			t.Fatal("expected a shutdown timeout error")
		}
		if !strings.Contains(err.Error(), "서버 종료 실패") {
			t.Fatalf("unexpected error message: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("serveWithShutdown did not return after shutdown timeout")
	}
	<-requestDone
}

// waitForHTTP 는 서버가 요청을 받을 준비가 될 때까지 제한 시간 안에서 재시도한다.
func waitForHTTP(t *testing.T, url string) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		resp, err := http.Get(url)
		if err == nil {
			_ = resp.Body.Close()
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("server did not accept requests: %s", url)
}

// waitForHTTPConnection 은 핸들러가 요청을 처리하기 시작할 때까지 기다린다.
func waitForHTTPConnection(t *testing.T, addr string) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("tcp", addr, 100*time.Millisecond)
		if err == nil {
			_ = conn.Close()
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("server did not accept connections: %s", addr)
}
