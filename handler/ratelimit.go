package handler

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

const (
	// rateLimitSweepInterval 은 만료 버킷 정리를 시도하는 주기다.
	rateLimitSweepInterval = 10 * time.Minute
	// rateLimitBucketTTL 은 이 시간 동안 요청이 없는 IP 버킷을 폐기하는 기준이다.
	rateLimitBucketTTL = 1 * time.Hour
)

// ipBucket 은 IP 한 개의 토큰 버킷 상태다. 맵 잠금이 보호하므로 자체 잠금을 두지 않는다.
type ipBucket struct {
	tokens     float64
	lastRefill time.Time
}

// ipRateLimiter 는 LimitRate 클로저 한 개가 소유하는 IP 버킷 집합이다.
// 백그라운드 goroutine 대신 요청 시점에 오래된 버킷을 정리하므로, 서버가
// 유휴 상태일 때 정리 비용이 들지 않고 종료 시 회수할 고루틴도 없다.
type ipRateLimiter struct {
	rps   float64
	burst float64
	now   func() time.Time

	mu        sync.Mutex
	buckets   map[string]*ipBucket
	lastSweep time.Time
}

func newIPRateLimiter(rps, burst float64) *ipRateLimiter {
	return &ipRateLimiter{
		rps:     rps,
		burst:   burst,
		now:     time.Now,
		buckets: make(map[string]*ipBucket),
	}
}

// allow 는 ip 의 요청 1건을 토큰 버킷 규칙으로 판정한다.
func (l *ipRateLimiter) allow(ip string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := l.now()
	if l.lastSweep.IsZero() || now.Sub(l.lastSweep) >= rateLimitSweepInterval {
		l.sweep(now)
		l.lastSweep = now
	}

	bucket, ok := l.buckets[ip]
	if !ok {
		bucket = &ipBucket{tokens: l.burst, lastRefill: now}
		l.buckets[ip] = bucket
	}

	// 시간 경과에 따른 토큰 충전
	bucket.tokens += now.Sub(bucket.lastRefill).Seconds() * l.rps
	if bucket.tokens > l.burst {
		bucket.tokens = l.burst
	}
	bucket.lastRefill = now

	if bucket.tokens < 1.0 {
		return false
	}
	bucket.tokens -= 1.0
	return true
}

// sweep 은 rateLimitBucketTTL 보다 오래 요청이 없는 버킷을 제거한다.
func (l *ipRateLimiter) sweep(now time.Time) {
	for ip, bucket := range l.buckets {
		if now.Sub(bucket.lastRefill) > rateLimitBucketTTL {
			delete(l.buckets, ip)
		}
	}
}

// bucketCount 는 추적 중인 버킷 수를 반환한다.
func (l *ipRateLimiter) bucketCount() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return len(l.buckets)
}

// LimitRate는 IP 기준 요청 제한을 적용하는 미들웨어입니다.
// rps: 초당 허용 요청 수 (Rate Per Second)
// burst: 순간 최대 허용 요청 수
//
// 버킷은 이 호출이 만든 클로저가 소유하므로 라우터(=서버)마다 제한 상태가 분리된다.
func LimitRate(rps float64, burst float64) gin.HandlerFunc {
	limiter := newIPRateLimiter(rps, burst)
	return func(c *gin.Context) {
		ip := c.ClientIP()
		if !limiter.allow(ip) {
			LogWarn("[RATE LIMIT EXCEEDED] IP: %s가 요청 제한을 초과했습니다.", ip)
			LogAndRespondError(c, http.StatusTooManyRequests, "요청 횟수가 너무 많습니다. 잠시 후 다시 시도해주세요.", nil)
			c.Abort()
			return
		}
		c.Next()
	}
}
