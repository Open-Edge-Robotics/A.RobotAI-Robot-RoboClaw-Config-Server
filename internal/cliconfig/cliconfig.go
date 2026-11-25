package cliconfig

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Profile stores connection metadata for a remote ai-config-server instance.
type Profile struct {
	URL             string `json:"url"`
	TokenEnv        string `json:"token_env,omitempty"`
	TokenFile       string `json:"token_file,omitempty"`
	Token           string `json:"token,omitempty"`
	DeviceTokenEnv  string `json:"device_token_env,omitempty"`
	DeviceTokenFile string `json:"device_token_file,omitempty"`
}

// MaskedProfile is safe for JSON/table output and never exposes raw tokens.
type MaskedProfile struct {
	Name            string `json:"name"`
	Active          bool   `json:"active"`
	URL             string `json:"url"`
	TokenSource     string `json:"token_source"`
	DeviceTokenHint string `json:"device_token_source,omitempty"`
}

// Store holds named remote server profiles on disk.
type Store struct {
	ActiveProfile string             `json:"active_profile,omitempty"`
	Profiles      map[string]Profile `json:"profiles"`
}

// ResolveOptions carries CLI flag overrides for resolving the active target server.
type ResolveOptions struct {
	ConfigPath string
	Profile    string
	URL        string
	TokenFile  string
	TokenEnv   string
	DeviceMode bool
	Getenv     func(string) string
}

// ResolvedConfig is the final connection configuration for an API request.
type ResolvedConfig struct {
	ProfileName string
	URL         string
	Token       string
	TokenSource string
}

// DefaultPath returns the path to the CLI profile store.
func DefaultPath() (string, error) {
	if p := strings.TrimSpace(os.Getenv("AICS_CONFIG_PATH")); p != "" {
		return p, nil
	}
	if xdg := strings.TrimSpace(os.Getenv("XDG_CONFIG_HOME")); xdg != "" {
		return filepath.Join(xdg, "aics", "profiles.json"), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("홈 디렉터리를 확인할 수 없습니다: %w", err)
	}
	return filepath.Join(home, ".config", "aics", "profiles.json"), nil
}

// Load reads the profile store from path. Missing files return an empty store.
func Load(path string) (*Store, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return &Store{Profiles: map[string]Profile{}}, nil
		}
		return nil, fmt.Errorf("프로필 파일 읽기 실패 (%s): %w", path, err)
	}
	var s Store
	if err := json.Unmarshal(data, &s); err != nil {
		return nil, fmt.Errorf("프로필 파일 파싱 실패 (%s): %w", path, err)
	}
	if s.Profiles == nil {
		s.Profiles = map[string]Profile{}
	}
	return &s, nil
}

// Save atomically persists the profile store with 0700 dir and 0600 file permissions.
func Save(path string, store *Store) error {
	if store == nil {
		store = &Store{Profiles: map[string]Profile{}}
	}
	if store.Profiles == nil {
		store.Profiles = map[string]Profile{}
	}
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return fmt.Errorf("설정 디렉터리 생성 실패 (%s): %w", dir, err)
	}
	data, err := json.MarshalIndent(store, "", "  ")
	if err != nil {
		return fmt.Errorf("프로필 직렬화 실패: %w", err)
	}
	data = append(data, '\n')

	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return fmt.Errorf("프로필 임시 파일 쓰기 실패: %w", err)
	}
	if err := os.Chmod(tmp, 0o600); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("프로필 파일 권한 설정 실패: %w", err)
	}
	if err := os.Rename(tmp, path); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("프로필 파일 저장 실패: %w", err)
	}
	return nil
}

// Mask returns a safe view of a profile without revealing secrets.
func (p Profile) Mask(name string, active bool) MaskedProfile {
	tokenSrc := "none"
	switch {
	case p.TokenFile != "":
		tokenSrc = "file:" + p.TokenFile
	case p.TokenEnv != "":
		tokenSrc = "env:" + p.TokenEnv
	case p.Token != "":
		tokenSrc = "stored(masked)"
	}
	devSrc := ""
	switch {
	case p.DeviceTokenFile != "":
		devSrc = "file:" + p.DeviceTokenFile
	case p.DeviceTokenEnv != "":
		devSrc = "env:" + p.DeviceTokenEnv
	}
	return MaskedProfile{
		Name:            name,
		Active:          active,
		URL:             p.URL,
		TokenSource:     tokenSrc,
		DeviceTokenHint: devSrc,
	}
}

// Resolve merges flags, environment variables, and stored profiles into a ResolvedConfig.
func Resolve(opts ResolveOptions) (ResolvedConfig, error) {
	getenv := opts.Getenv
	if getenv == nil {
		getenv = os.Getenv
	}

	cfgPath := opts.ConfigPath
	if cfgPath == "" {
		var err error
		cfgPath, err = DefaultPath()
		if err != nil {
			return ResolvedConfig{}, err
		}
	}

	store, err := Load(cfgPath)
	if err != nil {
		return ResolvedConfig{}, err
	}

	profileName := strings.TrimSpace(opts.Profile)
	explicitProfile := profileName != ""
	if profileName == "" {
		profileName = strings.TrimSpace(getenv("AICS_PROFILE"))
		if profileName != "" {
			explicitProfile = true
		}
	}
	if profileName == "" {
		profileName = store.ActiveProfile
	}

	var prof Profile
	if profileName != "" {
		var ok bool
		prof, ok = store.Profiles[profileName]
		if !ok && explicitProfile {
			return ResolvedConfig{}, fmt.Errorf("프로필 %q 을(를) 찾을 수 없습니다", profileName)
		}
	}

	resolvedURL := strings.TrimSpace(opts.URL)
	if resolvedURL == "" {
		resolvedURL = strings.TrimSpace(getenv("AICS_URL"))
	}
	if resolvedURL == "" {
		resolvedURL = strings.TrimSpace(prof.URL)
	}
	resolvedURL = strings.TrimRight(resolvedURL, "/")
	if resolvedURL == "" {
		return ResolvedConfig{}, errors.New("서버 URL이 설정되지 않았습니다 (--url, AICS_URL, 또는 'profile set' 사용)")
	}

	token, tokenSource, err := resolveToken(opts, prof, getenv)
	if err != nil {
		return ResolvedConfig{}, err
	}

	return ResolvedConfig{
		ProfileName: profileName,
		URL:         resolvedURL,
		Token:       token,
		TokenSource: tokenSource,
	}, nil
}

func resolveToken(opts ResolveOptions, prof Profile, getenv func(string) string) (string, string, error) {
	if opts.TokenFile != "" {
		tok, err := readTokenFile(opts.TokenFile)
		if err != nil {
			return "", "", err
		}
		return tok, "flag:--token-file", nil
	}
	if opts.TokenEnv != "" {
		if v := strings.TrimSpace(getenv(opts.TokenEnv)); v != "" {
			return v, "flag:--token-env:" + opts.TokenEnv, nil
		}
		return "", "", fmt.Errorf("환경변수 %s 이(가) 비어 있습니다", opts.TokenEnv)
	}

	if opts.DeviceMode {
		if v := strings.TrimSpace(getenv("AICS_DEVICE_TOKEN")); v != "" {
			return v, "env:AICS_DEVICE_TOKEN", nil
		}
		if prof.DeviceTokenFile != "" {
			tok, err := readTokenFile(prof.DeviceTokenFile)
			if err != nil {
				return "", "", err
			}
			return tok, "profile:device_token_file", nil
		}
		if prof.DeviceTokenEnv != "" {
			if v := strings.TrimSpace(getenv(prof.DeviceTokenEnv)); v != "" {
				return v, "profile:device_token_env:" + prof.DeviceTokenEnv, nil
			}
		}
	}

	if v := strings.TrimSpace(getenv("AICS_TOKEN")); v != "" {
		return v, "env:AICS_TOKEN", nil
	}
	if v := strings.TrimSpace(getenv("AI_CONFIG_SERVER_SECURITY_ADMIN_TOKEN")); v != "" {
		return v, "env:AI_CONFIG_SERVER_SECURITY_ADMIN_TOKEN", nil
	}
	if prof.TokenFile != "" {
		tok, err := readTokenFile(prof.TokenFile)
		if err != nil {
			return "", "", err
		}
		return tok, "profile:token_file", nil
	}
	if prof.TokenEnv != "" {
		if v := strings.TrimSpace(getenv(prof.TokenEnv)); v != "" {
			return v, "profile:token_env:" + prof.TokenEnv, nil
		}
		return "", "", fmt.Errorf("프로필에 설정된 환경변수 %s 이(가) 비어 있습니다", prof.TokenEnv)
	}
	if prof.Token != "" {
		return prof.Token, "profile:stored", nil
	}

	return "", "none", nil
}

func readTokenFile(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("토큰 파일 읽기 실패 (%s): %w", path, err)
	}
	tok := strings.TrimSpace(string(data))
	if tok == "" {
		return "", fmt.Errorf("토큰 파일이 비어 있습니다 (%s)", path)
	}
	return tok, nil
}
