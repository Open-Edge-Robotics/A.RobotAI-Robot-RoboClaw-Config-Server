package handler

import (
	"testing"

	"ai-config-server/config"
)

func TestValidateProductionConfig(t *testing.T) {
	valid := &config.Config{}
	valid.Security.RequireAuth = true
	valid.Security.AdminToken = "12345678901234567890123456789012"
	valid.Security.DeviceToken = "abcdefghijklmnopqrstuvwxyz123456"
	valid.Security.CorsAllowedOrigins = []string{"https://dashboard.example.com"}
	if err := ValidateProductionConfig(valid); err != nil {
		t.Fatalf("expected valid production config, got %v", err)
	}

	for name, mutate := range map[string]func(*config.Config){
		"auth disabled":       func(c *config.Config) { c.Security.RequireAuth = false },
		"missing admin token": func(c *config.Config) { c.Security.AdminToken = "" },
		"short device token":  func(c *config.Config) { c.Security.DeviceToken = "short" },
		"wildcard origin":     func(c *config.Config) { c.Security.CorsAllowedOrigins = []string{"*"} },
		"http origin":         func(c *config.Config) { c.Security.CorsAllowedOrigins = []string{"http://dashboard.example.com"} },
	} {
		t.Run(name, func(t *testing.T) {
			cfg := *valid
			mutate(&cfg)
			if err := ValidateProductionConfig(&cfg); err == nil {
				t.Fatal("expected unsafe production config to be rejected")
			}
		})
	}

	t.Run("localhost and private IP origins allow http", func(t *testing.T) {
		cfg := *valid
		cfg.Security.CorsAllowedOrigins = []string{
			"http://localhost:8080",
			"http://127.0.0.1:8080",
			"http://192.168.50.30:8080",
			"http://10.0.0.1:8080",
		}
		if err := ValidateProductionConfig(&cfg); err != nil {
			t.Fatalf("expected localhost/private IP with http to be allowed, got %v", err)
		}
	})
}

func TestCheckInsecureDefaults(t *testing.T) {
	t.Run("모든 값이 안전하게 설정된 경우 문제 없음", func(t *testing.T) {
		cfg := &config.Config{}
		cfg.Security.AdminToken = "admin-secret"
		cfg.Security.DeviceToken = "device-secret"
		cfg.Security.CorsAllowedOrigins = []string{"https://dashboard.internal"}

		issues := CheckInsecureDefaults(cfg)
		if len(issues) != 0 {
			t.Fatalf("expected no issues, got %v", issues)
		}
	})

	t.Run("admin_token만 비어있으면 관리자 API 경고만 발생", func(t *testing.T) {
		cfg := &config.Config{}
		cfg.Security.DeviceToken = "device-secret"
		cfg.Security.CorsAllowedOrigins = []string{"https://dashboard.internal"}

		issues := CheckInsecureDefaults(cfg)
		if len(issues) != 1 {
			t.Fatalf("expected exactly 1 issue, got %v", issues)
		}
	})

	t.Run("admin_token과 device_token이 모두 비어있으면 두 경고 모두 발생", func(t *testing.T) {
		cfg := &config.Config{}
		cfg.Security.CorsAllowedOrigins = []string{"https://dashboard.internal"}

		issues := CheckInsecureDefaults(cfg)
		if len(issues) != 2 {
			t.Fatalf("expected exactly 2 issues, got %v", issues)
		}
	})

	t.Run("CORS 미설정 또는 와일드카드는 경고 발생", func(t *testing.T) {
		cfg := &config.Config{}
		cfg.Security.AdminToken = "admin-secret"
		cfg.Security.DeviceToken = "device-secret"

		issues := CheckInsecureDefaults(cfg)
		if len(issues) != 1 {
			t.Fatalf("expected exactly 1 issue for empty CORS list, got %v", issues)
		}

		cfg.Security.CorsAllowedOrigins = []string{"*"}
		issues = CheckInsecureDefaults(cfg)
		if len(issues) != 1 {
			t.Fatalf("expected exactly 1 issue for wildcard CORS, got %v", issues)
		}
	})
}
