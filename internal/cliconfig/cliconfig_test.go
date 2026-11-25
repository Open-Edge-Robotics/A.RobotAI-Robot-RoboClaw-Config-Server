package cliconfig

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSaveLoadPermissionsAndMask(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "nested", "profiles.json")

	store := &Store{
		ActiveProfile: "prod",
		Profiles: map[string]Profile{
			"prod": {
				URL:      "https://cfg.example.com",
				TokenEnv: "PROD_TOKEN",
			},
			"local": {
				URL:   "http://127.0.0.1:8080",
				Token: "super-secret-value",
			},
		},
	}

	if err := Save(path, store); err != nil {
		t.Fatalf("Save failed: %v", err)
	}

	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("Stat failed: %v", err)
	}
	if perm := info.Mode().Perm(); perm != 0o600 {
		t.Errorf("expected file mode 0600, got %o", perm)
	}

	loaded, err := Load(path)
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}
	if loaded.ActiveProfile != "prod" || len(loaded.Profiles) != 2 {
		t.Fatalf("unexpected loaded store: %+v", loaded)
	}

	masked := loaded.Profiles["local"].Mask("local", false)
	if masked.TokenSource != "stored(masked)" {
		t.Errorf("expected stored(masked), got %q", masked.TokenSource)
	}
}

func TestResolvePrecedence(t *testing.T) {
	dir := t.TempDir()
	cfgPath := filepath.Join(dir, "profiles.json")
	tokFile := filepath.Join(dir, "tok")
	if err := os.WriteFile(tokFile, []byte("file-token\n"), 0o600); err != nil {
		t.Fatalf("write token file: %v", err)
	}

	store := &Store{
		ActiveProfile: "dev",
		Profiles: map[string]Profile{
			"dev": {
				URL:            "http://dev.local:8080/",
				TokenEnv:       "DEV_ADMIN_TOKEN",
				DeviceTokenEnv: "DEV_DEVICE_TOKEN",
			},
		},
	}
	if err := Save(cfgPath, store); err != nil {
		t.Fatalf("Save failed: %v", err)
	}

	envMap := map[string]string{
		"DEV_ADMIN_TOKEN":  "prof-admin-tok",
		"DEV_DEVICE_TOKEN": "prof-dev-tok",
	}
	getenv := func(k string) string { return envMap[k] }

	// 1. Default active profile
	got, err := Resolve(ResolveOptions{ConfigPath: cfgPath, Getenv: getenv})
	if err != nil {
		t.Fatalf("Resolve active profile failed: %v", err)
	}
	if got.URL != "http://dev.local:8080" || got.Token != "prof-admin-tok" {
		t.Fatalf("unexpected resolved config: %+v", got)
	}

	// 2. Device mode prefers device token
	gotDev, err := Resolve(ResolveOptions{ConfigPath: cfgPath, DeviceMode: true, Getenv: getenv})
	if err != nil {
		t.Fatalf("Resolve device mode failed: %v", err)
	}
	if gotDev.Token != "prof-dev-tok" {
		t.Fatalf("expected device token, got %q", gotDev.Token)
	}

	// 3. Explicit flags override env and profile
	envMap["AICS_URL"] = "http://env.local"
	envMap["AICS_TOKEN"] = "env-tok"
	gotFlag, err := Resolve(ResolveOptions{
		ConfigPath: cfgPath,
		URL:        "http://flag.local/",
		TokenFile:  tokFile,
		Getenv:     getenv,
	})
	if err != nil {
		t.Fatalf("Resolve flags failed: %v", err)
	}
	if gotFlag.URL != "http://flag.local" || gotFlag.Token != "file-token" {
		t.Fatalf("unexpected flag override: %+v", gotFlag)
	}
}

func TestResolveErrors(t *testing.T) {
	dir := t.TempDir()
	cfgPath := filepath.Join(dir, "profiles.json")
	emptyEnv := func(string) string { return "" }

	if _, err := Resolve(ResolveOptions{ConfigPath: cfgPath, Getenv: emptyEnv}); err == nil {
		t.Fatal("expected error when URL is missing")
	}
	if _, err := Resolve(ResolveOptions{ConfigPath: cfgPath, Profile: "missing", Getenv: emptyEnv}); err == nil {
		t.Fatal("expected error when explicit profile does not exist")
	}
	if _, err := Resolve(ResolveOptions{ConfigPath: cfgPath, URL: "http://x", TokenEnv: "EMPTY_VAR", Getenv: emptyEnv}); err == nil {
		t.Fatal("expected error when --token-env is empty")
	}
}

func TestDefaultPathAndFileTokens(t *testing.T) {
	t.Setenv("AICS_CONFIG_PATH", "/tmp/custom-aics.json")
	if p, err := DefaultPath(); err != nil || p != "/tmp/custom-aics.json" {
		t.Fatalf("expected AICS_CONFIG_PATH, got %q err=%v", p, err)
	}

	t.Setenv("AICS_CONFIG_PATH", "")
	t.Setenv("XDG_CONFIG_HOME", "/tmp/xdg-test")
	if p, err := DefaultPath(); err != nil || p != filepath.Join("/tmp/xdg-test", "aics", "profiles.json") {
		t.Fatalf("expected XDG path, got %q err=%v", p, err)
	}

	dir := t.TempDir()
	cfgPath := filepath.Join(dir, "profiles.json")
	adminTokFile := filepath.Join(dir, "admin.tok")
	devTokFile := filepath.Join(dir, "dev.tok")
	if err := os.WriteFile(adminTokFile, []byte("adm-from-file\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(devTokFile, []byte("dev-from-file\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	prof := Profile{
		URL:             "http://127.0.0.1:8080",
		TokenFile:       adminTokFile,
		DeviceTokenFile: devTokFile,
	}
	if err := Save(cfgPath, &Store{ActiveProfile: "f", Profiles: map[string]Profile{"f": prof}}); err != nil {
		t.Fatal(err)
	}

	masked := prof.Mask("f", true)
	if masked.TokenSource != "file:"+adminTokFile || masked.DeviceTokenHint != "file:"+devTokFile {
		t.Fatalf("unexpected masked profile: %+v", masked)
	}

	emptyEnv := func(string) string { return "" }
	resAdm, err := Resolve(ResolveOptions{ConfigPath: cfgPath, Getenv: emptyEnv})
	if err != nil || resAdm.Token != "adm-from-file" {
		t.Fatalf("expected admin token from file, got %+v err=%v", resAdm, err)
	}
	resDev, err := Resolve(ResolveOptions{ConfigPath: cfgPath, DeviceMode: true, Getenv: emptyEnv})
	if err != nil || resDev.Token != "dev-from-file" {
		t.Fatalf("expected device token from file, got %+v err=%v", resDev, err)
	}
}
