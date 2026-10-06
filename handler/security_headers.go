package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

const maxRequestBodyBytes int64 = 10 << 20

// SecurityHeaders는 브라우저가 적용할 기본 보안 정책을 설정한다.
// TLS 종료는 ingress/reverse proxy가 담당하므로 HSTS는 운영 HTTPS 앞단에서
// 설정하는 것을 전제로 애플리케이션에서는 CSP와 MIME sniffing 방지를 제공한다.
func SecurityHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("Referrer-Policy", "no-referrer")
		c.Header("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		c.Header("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.gstatic.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com data:; img-src 'self' data: blob: https://www.gstatic.com; connect-src 'self' https://www.gstatic.com https://fonts.gstatic.com; object-src 'none'; frame-ancestors 'none'; base-uri 'self'")
		c.Next()
	}
}

// MaxRequestBody는 JSON import 및 설정 본문을 통한 메모리 고갈을 제한한다.
func MaxRequestBody(limit int64) gin.HandlerFunc {
	if limit <= 0 {
		limit = maxRequestBodyBytes
	}
	return func(c *gin.Context) {
		if c.Request.Body != nil {
			c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, limit)
		}
		c.Next()
	}
}
