package handler

import (
	"testing"
	"time"
)

// TestIPRateLimiterTokenRule 은 경과 시간에 따른 토큰 충전 규칙을 고정 시간으로
// 검증한다. rps=1, burst=2 버킷에서 3번째 요청은 거절되고, 1.5초 후에는 1건이
// 다시 허용되어야 한다.
func TestIPRateLimiterTokenRule(t *testing.T) {
	now := time.Unix(1700000000, 0)
	limiter := newIPRateLimiter(1, 2)
	limiter.now = func() time.Time { return now }

	for i := 0; i < 2; i++ {
		if !limiter.allow("10.0.0.1") {
			t.Fatalf("request %d should be allowed within burst", i+1)
		}
	}
	if limiter.allow("10.0.0.1") {
		t.Fatal("third immediate request must be rejected")
	}

	now = now.Add(1500 * time.Millisecond)
	if !limiter.allow("10.0.0.1") {
		t.Fatal("expected refilled token after 1.5s")
	}
	if limiter.allow("10.0.0.1") {
		t.Fatal("expected only one refilled token to be available")
	}
}

// TestIPRateLimiterCapsRefillAtBurst 는 오래 쉰 버킷이 burst 이상으로 충전되지
// 않는지 검증한다.
func TestIPRateLimiterCapsRefillAtBurst(t *testing.T) {
	now := time.Unix(1700000000, 0)
	limiter := newIPRateLimiter(10, 2)
	limiter.now = func() time.Time { return now }

	for i := 0; i < 2; i++ {
		if !limiter.allow("10.0.0.2") {
			t.Fatalf("request %d should be allowed", i+1)
		}
	}
	now = now.Add(30 * time.Second)

	// 30초 * 10rps = 300 토큰이지만 burst 상한은 2다.
	for i := 0; i < 2; i++ {
		if !limiter.allow("10.0.0.2") {
			t.Fatalf("request %d after idle should be allowed", i+3)
		}
	}
	if limiter.allow("10.0.0.2") {
		t.Fatal("refill must be capped at burst")
	}
}

// TestIPRateLimiterSweepsIdleBucketsLazily 는 백그라운드 goroutine 없이 요청 시점에
// 1시간 이상 유휴 상태인 버킷을 정리하는지 검증한다.
func TestIPRateLimiterSweepsIdleBucketsLazily(t *testing.T) {
	now := time.Unix(1700000000, 0)
	limiter := newIPRateLimiter(1, 1)
	limiter.now = func() time.Time { return now }

	if !limiter.allow("10.0.0.3") {
		t.Fatal("expected first request to be allowed")
	}
	if got := limiter.bucketCount(); got != 1 {
		t.Fatalf("expected 1 tracked bucket, got %d", got)
	}

	// 10분 정리 주기와 1시간 유휴 기준을 모두 넘긴다.
	now = now.Add(61 * time.Minute)
	if !limiter.allow("10.0.0.4") {
		t.Fatal("expected request from another IP to be allowed")
	}
	if got := limiter.bucketCount(); got != 1 {
		t.Fatalf("expected idle bucket to be dropped, got %d buckets", got)
	}
}

// TestIPRateLimiterKeepsRecentlyUsedBuckets 는 정리 주기가 지나도 유휴 시간이
// 1시간 미만인 버킷은 유지되는지 검증한다.
func TestIPRateLimiterKeepsRecentlyUsedBuckets(t *testing.T) {
	now := time.Unix(1700000000, 0)
	limiter := newIPRateLimiter(1, 1)
	limiter.now = func() time.Time { return now }

	limiter.allow("10.0.0.5")
	now = now.Add(11 * time.Minute)
	limiter.allow("10.0.0.6")

	if got := limiter.bucketCount(); got != 2 {
		t.Fatalf("expected both buckets to be kept, got %d", got)
	}
}
