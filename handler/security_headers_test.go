package handler

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestSecurityHeadersMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(SecurityHeaders())
	r.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	headers := map[string]string{
		"X-Content-Type-Options": "nosniff",
		"X-Frame-Options":        "DENY",
		"Referrer-Policy":        "no-referrer",
		"Permissions-Policy":     "camera=(), microphone=(), geolocation=()",
	}

	for header, expected := range headers {
		got := w.Header().Get(header)
		if got != expected {
			t.Errorf("header %s: expected %q, got %q", header, expected, got)
		}
	}

	csp := w.Header().Get("Content-Security-Policy")
	if csp == "" {
		t.Fatal("Content-Security-Policy header is missing")
	}

	// Flutter Web 엔진 및 폰트 로드에 필요한 도메인이 CSP에 포함되어 있는지 검증
	requiredCSPElements := []string{
		"default-src 'self'",
		"script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.gstatic.com",
		"style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
		"font-src 'self' https://fonts.gstatic.com data:",
		"connect-src 'self' https://www.gstatic.com https://fonts.gstatic.com",
		"img-src 'self' data: blob: https://www.gstatic.com",
		"object-src 'none'",
		"frame-ancestors 'none'",
		"base-uri 'self'",
	}

	for _, elem := range requiredCSPElements {
		if !strings.Contains(csp, elem) {
			t.Errorf("Content-Security-Policy missing required directive: %q. Full CSP: %s", elem, csp)
		}
	}
}

func TestMaxRequestBodyMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(MaxRequestBody(1024))
	r.POST("/upload", func(c *gin.Context) {
		buf := make([]byte, 2048)
		_, err := c.Request.Body.Read(buf)
		if err != nil && err.Error() == "http: request body too large" {
			c.String(http.StatusRequestEntityTooLarge, "too large")
			return
		}
		c.String(http.StatusOK, "ok")
	})

	// 허용 크기 이하 본문
	smallBody := bytes.Repeat([]byte("a"), 512)
	reqSmall := httptest.NewRequest(http.MethodPost, "/upload", bytes.NewReader(smallBody))
	wSmall := httptest.NewRecorder()
	r.ServeHTTP(wSmall, reqSmall)
	if wSmall.Code != http.StatusOK {
		t.Errorf("expected status 200 for small body, got %d", wSmall.Code)
	}

	// 허용 크기 초과 본문
	largeBody := bytes.Repeat([]byte("a"), 2048)
	reqLarge := httptest.NewRequest(http.MethodPost, "/upload", bytes.NewReader(largeBody))
	wLarge := httptest.NewRecorder()
	r.ServeHTTP(wLarge, reqLarge)
	if wLarge.Code != http.StatusRequestEntityTooLarge {
		t.Errorf("expected status 413 for oversized body, got %d", wLarge.Code)
	}
}
