package handler

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type ipBucket struct {
	tokens     float64
	lastRefill time.Time
	mu         sync.Mutex
}

var (
	ipBuckets sync.Map
)

func init() {
	// 10분마다 오랫동안 요청이 없는(예: 1시간 이상) IP 버킷 정보를 정리하여 메모리를 관리합니다.
	go func() {
		ticker := time.NewTicker(10 * time.Minute)
		for range ticker.C {
			now := time.Now()
			ipBuckets.Range(func(key, value any) bool {
				bucket := value.(*ipBucket)
				bucket.mu.Lock()
				if now.Sub(bucket.lastRefill) > 1*time.Hour {
					ipBuckets.Delete(key)
				}
				bucket.mu.Unlock()
				return true
			})
		}
	}()
}

// LimitRate는 IP 기준 요청 제한을 적용하는 미들웨어입니다.
// rps: 초당 허용 요청 수 (Rate Per Second)
// burst: 순간 최대 허용 요청 수
func LimitRate(rps float64, burst float64) gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := c.ClientIP()

		val, _ := ipBuckets.LoadOrStore(ip, &ipBucket{
			tokens:     burst,
			lastRefill: time.Now(),
		})
		bucket := val.(*ipBucket)

		bucket.mu.Lock()
		now := time.Now()
		elapsed := now.Sub(bucket.lastRefill).Seconds()
		bucket.lastRefill = now

		// 시간 경과에 따른 토큰 충전
		bucket.tokens += elapsed * rps
		if bucket.tokens > burst {
			bucket.tokens = burst
		}

		if bucket.tokens >= 1.0 {
			bucket.tokens -= 1.0
			bucket.mu.Unlock()
			c.Next()
		} else {
			bucket.mu.Unlock()
			LogWarn("[RATE LIMIT EXCEEDED] IP: %s가 요청 제한을 초과했습니다.", ip)
			LogAndRespondError(c, http.StatusTooManyRequests, "요청 횟수가 너무 많습니다. 잠시 후 다시 시도해주세요.", nil)
			c.Abort()
		}
	}
}
