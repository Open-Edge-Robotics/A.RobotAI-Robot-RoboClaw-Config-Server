package contract

import (
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// TestRemoteClientHasTimeout 은 release 요청 클라이언트에 상한이 설정됐는지 검증한다.
func TestRemoteClientHasTimeout(t *testing.T) {
	if got := remoteClient().Timeout; got != remoteRequestTimeout || got <= 0 {
		t.Fatalf("expected remote timeout %v, got %v", remoteRequestTimeout, got)
	}
}

// TestFetchReleaseTimesOut 은 응답이 없는 release 조회가 timeout 으로 끝나는지 검증한다.
func TestFetchReleaseTimesOut(t *testing.T) {
	block := make(chan struct{})
	server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		<-block
	}))
	// server.Close 는 진행 중 핸들러를 기다린다. 핸들러를 먼저 깨운 뒤 닫는다.
	defer func() {
		close(block)
		server.Close()
	}()

	client := server.Client()
	client.Timeout = 50 * time.Millisecond

	start := time.Now()
	_, err := fetchReleaseWith(client, server.URL)
	if err == nil {
		t.Fatal("expected a timeout error")
	}
	if !strings.Contains(err.Error(), "failed to fetch GitLab release") {
		t.Fatalf("unexpected error: %v", err)
	}
	if elapsed := time.Since(start); elapsed > 5*time.Second {
		t.Fatalf("request did not honor the timeout: %v", elapsed)
	}
}

// TestDownloadFileTimesOut 은 응답이 없는 에셋 다운로드가 timeout 으로 끝나고
// 파일을 남기지 않는지 검증한다.
func TestDownloadFileTimesOut(t *testing.T) {
	block := make(chan struct{})
	server := httptest.NewTLSServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		<-block
	}))
	// server.Close 는 진행 중 핸들러를 기다린다. 핸들러를 먼저 깨운 뒤 닫는다.
	defer func() {
		close(block)
		server.Close()
	}()

	client := server.Client()
	client.Timeout = 50 * time.Millisecond

	target := filepath.Join(t.TempDir(), "asset.json")
	err := downloadFileWith(client, server.URL+"/asset.json", target)
	if err == nil {
		t.Fatal("expected a timeout error")
	}
	if !strings.Contains(err.Error(), "failed to download release asset") {
		t.Fatalf("unexpected error: %v", err)
	}
}

// TestDownloadFileRejectsPlainHTTP 는 HTTPS 가 아닌 에셋 URL 을 거부하는지 검증한다.
func TestDownloadFileRejectsPlainHTTP(t *testing.T) {
	err := downloadFileWith(remoteClient(), "http://example.com/asset.json", filepath.Join(t.TempDir(), "a.json"))
	if err == nil || !strings.Contains(err.Error(), "must use HTTPS") {
		t.Fatalf("unexpected error: %v", err)
	}
}
