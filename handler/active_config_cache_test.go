package handler

import (
	"testing"

	"ai-config-server/database/models"
)

// TestActiveConfigCacheSeparatesCompositeKeys 는 로봇/환경 키가 구조체로
// 구분되는지 검증한다. 문자열 연결 키("a:b:c")는 값에 구분자가 들어가면
// 서로 다른 (로봇, 환경) 조합이 같은 키로 충돌했다.
func TestActiveConfigCacheSeparatesCompositeKeys(t *testing.T) {
	cache := newActiveConfigCache()
	gen := cache.currentGeneration()
	cache.storeConfig(activeCacheKey{robotName: "a", environment: "b:c"}, models.RoboClawConfig{Name: "first"}, gen)
	cache.storeConfig(activeCacheKey{robotName: "a:b", environment: "c"}, models.RoboClawConfig{Name: "second"}, gen)

	first, ok := cache.config(activeCacheKey{robotName: "a", environment: "b:c"})
	if !ok || first.Name != "first" {
		t.Fatalf("expected first entry, got %+v (ok=%t)", first, ok)
	}
	second, ok := cache.config(activeCacheKey{robotName: "a:b", environment: "c"})
	if !ok || second.Name != "second" {
		t.Fatalf("expected second entry, got %+v (ok=%t)", second, ok)
	}
}

// TestActiveConfigCacheRejectsStaleRefillAfterClear 는 무효화 이전 세대에서
// 읽은 값이 무효화 이후 캐시를 다시 채우지 못하는지 검증한다.
func TestActiveConfigCacheRejectsStaleRefillAfterClear(t *testing.T) {
	cache := newActiveConfigCache()
	key := activeCacheKey{robotName: "butler", environment: "office"}
	staleGeneration := cache.currentGeneration()

	cache.clear()

	if cache.storeConfig(key, models.RoboClawConfig{Name: "stale"}, staleGeneration) {
		t.Fatal("expected stale generation store to be rejected")
	}
	if _, ok := cache.config(key); ok {
		t.Fatal("expected stale config not to be cached")
	}

	if !cache.storeConfig(key, models.RoboClawConfig{Name: "fresh"}, cache.currentGeneration()) {
		t.Fatal("expected current generation store to be accepted")
	}
	cached, ok := cache.config(key)
	if !ok || cached.Name != "fresh" {
		t.Fatalf("expected fresh config, got %+v (ok=%t)", cached, ok)
	}
}

// TestActiveConfigCacheFileSurvivesConfigRefresh 는 설정 갱신 시 이미 생성된
// 파일 캐시가 유지되는지 검증한다.
func TestActiveConfigCacheFileSurvivesConfigRefresh(t *testing.T) {
	cache := newActiveConfigCache()
	key := activeCacheKey{robotName: "butler", environment: "office"}
	gen := cache.currentGeneration()
	cache.storeConfig(key, models.RoboClawConfig{Name: "v1"}, gen)
	cache.storeFile(key, ".env", []byte("RC_DEBUG=false\n"), models.RoboClawConfig{Name: "v1"}, gen)

	cache.storeConfig(key, models.RoboClawConfig{Name: "v2"}, gen)

	if cached, ok := cache.config(key); !ok || cached.Name != "v2" {
		t.Fatalf("expected refreshed config, got %+v (ok=%t)", cached, ok)
	}
	content, ok := cache.file(key, ".env")
	if !ok || string(content) != "RC_DEBUG=false\n" {
		t.Fatalf("expected cached file to survive, got %q (ok=%t)", content, ok)
	}
}

// TestActiveConfigCacheFileStoreKeepsConfig 는 파일만 먼저 캐시에 들어가도 같은
// 잠금 안에서 설정 본문이 함께 저장되는지 검증한다.
func TestActiveConfigCacheFileStoreKeepsConfig(t *testing.T) {
	cache := newActiveConfigCache()
	key := activeCacheKey{robotName: "butler", environment: "office"}

	cache.storeFile(key, "ROBOT.md", []byte("# soul"), models.RoboClawConfig{Name: "profile"}, cache.currentGeneration())

	cached, ok := cache.config(key)
	if !ok || cached.Name != "profile" {
		t.Fatalf("expected file store to keep the config, got %+v (ok=%t)", cached, ok)
	}
}

// TestActiveConfigCacheReturnsFileCopy 는 캐시된 파일 바이트가 복사본으로
// 반환되는지 검증한다. 반환된 슬라이스를 고쳐도 캐시 내용이 바뀌면 안 된다.
func TestActiveConfigCacheReturnsFileCopy(t *testing.T) {
	cache := newActiveConfigCache()
	key := activeCacheKey{robotName: "butler", environment: "office"}
	original := []byte("RC_DEBUG=false\n")
	cache.storeFile(key, ".env", original, models.RoboClawConfig{Name: "v1"}, cache.currentGeneration())

	first, ok := cache.file(key, ".env")
	if !ok {
		t.Fatal("expected cached file")
	}
	first[0] = 'X'

	second, ok := cache.file(key, ".env")
	if !ok || string(second) != "RC_DEBUG=false\n" {
		t.Fatalf("expected cache to be unaffected by caller mutation, got %q (ok=%t)", second, ok)
	}
}

// TestActiveConfigCacheClearDropsFiles 는 clear 가 파일 캐시까지 비우는지 검증한다.
func TestActiveConfigCacheClearDropsFiles(t *testing.T) {
	cache := newActiveConfigCache()
	key := activeCacheKey{robotName: "butler", environment: "office"}
	cache.storeFile(key, "ROBOT.md", []byte("# soul"), models.RoboClawConfig{Name: "v1"}, cache.currentGeneration())

	cache.clear()

	if _, ok := cache.file(key, "ROBOT.md"); ok {
		t.Fatal("expected clear to drop cached files")
	}
}
