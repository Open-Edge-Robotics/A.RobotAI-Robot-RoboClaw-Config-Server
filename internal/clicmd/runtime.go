package clicmd

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"

	"ai-config-server/internal/cliconfig"
	"ai-config-server/internal/client"
	"ai-config-server/internal/clioutput"
	"github.com/wkqco33/wcli"
)

// Runtime holds shared CLI flags and I/O streams for remote commands.
type Runtime struct {
	Out        io.Writer
	Err        io.Writer
	In         io.Reader
	ConfigPath string
	Profile    string
	URL        string
	TokenFile  string
	TokenEnv   string
	JSON       bool
	Yes        bool
	NoInput    bool
	Timeout    time.Duration
	Getenv     func(string) string
}

// DefaultRuntime returns a Runtime wired to standard OS streams.
func DefaultRuntime() *Runtime {
	return &Runtime{
		Out:     os.Stdout,
		Err:     os.Stderr,
		In:      os.Stdin,
		Timeout: 30 * time.Second,
		Getenv:  os.Getenv,
	}
}

func (rt *Runtime) out() io.Writer {
	if rt.Out != nil {
		return rt.Out
	}
	return os.Stdout
}

func (rt *Runtime) errOut() io.Writer {
	if rt.Err != nil {
		return rt.Err
	}
	return os.Stderr
}

func (rt *Runtime) in() io.Reader {
	if rt.In != nil {
		return rt.In
	}
	return os.Stdin
}

func (rt *Runtime) configPath() (string, error) {
	if rt.ConfigPath != "" {
		return rt.ConfigPath, nil
	}
	return cliconfig.DefaultPath()
}

// RegisterGlobalFlags attaches shared remote-client persistent flags to root.
func RegisterGlobalFlags(root *wcli.Command, rt *Runtime) {
	pf := root.PersistentFlags()
	pf.StringVar(&rt.Profile, "profile", "p", "", "사용할 원격 서버 프로필 이름 (AICS_PROFILE)")
	pf.StringVar(&rt.URL, "url", "", "", "원격 서버 기본 URL (AICS_URL)")
	pf.StringVar(&rt.TokenFile, "token-file", "", "", "Bearer 토큰이 저장된 파일 경로")
	pf.StringVar(&rt.TokenEnv, "token-env", "", "", "Bearer 토큰을 읽을 환경변수 이름")
	pf.StringVar(&rt.ConfigPath, "config-path", "", "", "프로필 저장 파일 경로 (기본: ~/.config/aics/profiles.json)")
	pf.BoolVar(&rt.JSON, "json", "", false, "결과를 JSON 형식으로 stdout에 출력")
	pf.BoolVar(&rt.Yes, "yes", "y", false, "파괴적 작업(삭제/활성화/덮어쓰기) 확인 승인")
	pf.BoolVar(&rt.NoInput, "no-input", "", false, "비대화형 모드 강제")
	pf.DurationVar(&rt.Timeout, "timeout", "", 30*time.Second, "HTTP 요청 타임아웃 (예: 30s)")
}

// RegisterCommands adds all remote management subcommands to root.
func RegisterCommands(root *wcli.Command, rt *Runtime) {
	RegisterGlobalFlags(root, rt)
	root.AddCommand(
		newProfileCmd(rt),
		newStatusCmd(rt),
		newConfigCmd(rt),
		newScenarioCmd(rt),
		newTransferCmd(rt),
		newDeviceCmd(rt),
		newMcpCmd(rt),
		newSchemaCmd(rt),
	)
}

// NewRootCommand creates a standalone pure-Go root command for aics-cli.
func NewRootCommand(version string, rt *Runtime) *wcli.Command {
	if rt == nil {
		rt = DefaultRuntime()
	}
	root := &wcli.Command{
		Use:           "aics-cli",
		Short:         "ai-config-server 원격 관리 CLI (Pure Go / AI 에이전트 친화형)",
		Version:       version,
		SilenceErrors: true,
		OutWriter:     rt.out(),
		ErrWriter:     rt.errOut(),
	}
	RegisterCommands(root, rt)
	root.AddCommand(wcli.NewCompletionCommand(root))
	return root
}

func (rt *Runtime) resolveClient(deviceMode bool) (*client.Client, cliconfig.ResolvedConfig, error) {
	resolved, err := cliconfig.Resolve(cliconfig.ResolveOptions{
		ConfigPath: rt.ConfigPath,
		Profile:    rt.Profile,
		URL:        rt.URL,
		TokenFile:  rt.TokenFile,
		TokenEnv:   rt.TokenEnv,
		DeviceMode: deviceMode,
		Getenv:     rt.Getenv,
	})
	if err != nil {
		return nil, cliconfig.ResolvedConfig{}, &client.CodeError{Code: client.ExitUsage, Err: err}
	}
	return client.New(resolved.URL, resolved.Token, rt.Timeout), resolved, nil
}

func (rt *Runtime) reqContext(ctx *wcli.Context) context.Context {
	if ctx != nil && ctx.Context != nil {
		return ctx.Context
	}
	return context.Background()
}

func (rt *Runtime) readInputBytes(path string) ([]byte, error) {
	if path == "-" {
		data, err := io.ReadAll(rt.in())
		if err != nil {
			return nil, fmt.Errorf("stdin 읽기 실패: %w", err)
		}
		return data, nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, &client.CodeError{Code: client.ExitUsage, Err: fmt.Errorf("입력 파일 읽기 실패 (%s): %w", path, err)}
	}
	return data, nil
}

func (rt *Runtime) requireYes(action string) error {
	if rt.Yes {
		return nil
	}
	return &client.CodeError{
		Code: client.ExitUsage,
		Err:  fmt.Errorf("%s 작업은 --yes 플래그가 필요합니다", action),
	}
}

func parsePositiveID(raw string) (int, error) {
	id, err := strconv.Atoi(strings.TrimSpace(raw))
	if err != nil || id <= 0 {
		return 0, &client.CodeError{
			Code: client.ExitUsage,
			Err:  fmt.Errorf("올바른 양의 정수 ID가 필요합니다 (입력: %q)", raw),
		}
	}
	return id, nil
}

func resolveConfigTarget(ctx context.Context, cli *client.Client, args []string, robot, env, name string, activeOnly bool) (int, error) {
	if len(args) > 0 && strings.TrimSpace(args[0]) != "" {
		return parsePositiveID(args[0])
	}
	if robot == "" && env == "" && name == "" && !activeOnly {
		return 0, &client.CodeError{
			Code: client.ExitUsage,
			Err:  errors.New("대상 ID 또는 --robot/--env/--name/--active 선택자를 지정해야 합니다"),
		}
	}
	items, err := cli.ListConfigs(ctx, robot, env)
	if err != nil {
		return 0, err
	}
	matches := make([]client.Config, 0, len(items))
	for _, it := range items {
		if activeOnly && !it.IsActive() {
			continue
		}
		if name != "" && it.Name() != name {
			continue
		}
		matches = append(matches, it)
	}
	if len(matches) == 0 {
		return 0, &client.CodeError{
			Code: client.ExitNotFound,
			Err:  errors.New("조건에 일치하는 설정 프로필을 찾을 수 없습니다"),
		}
	}
	if len(matches) > 1 {
		ids := make([]string, 0, len(matches))
		for _, m := range matches {
			ids = append(ids, fmt.Sprintf("%d(%s)", m.ID(), m.Name()))
		}
		return 0, &client.CodeError{
			Code: client.ExitUsage,
			Err:  fmt.Errorf("조건에 일치하는 설정 프로필이 %d건 있습니다 (%s). ID 또는 --name/--active 로 대상을 좁혀 주세요", len(matches), strings.Join(ids, ", ")),
		}
	}
	return matches[0].ID(), nil
}

func resolveScenarioTarget(ctx context.Context, cli *client.Client, args []string, robot, env, name string, activeOnly bool) (int, error) {
	if len(args) > 0 && strings.TrimSpace(args[0]) != "" {
		return parsePositiveID(args[0])
	}
	if robot == "" && env == "" && name == "" && !activeOnly {
		return 0, &client.CodeError{
			Code: client.ExitUsage,
			Err:  errors.New("대상 ID 또는 --robot/--env/--name/--active 선택자를 지정해야 합니다"),
		}
	}
	items, err := cli.ListScenarios(ctx, robot, env)
	if err != nil {
		return 0, err
	}
	matches := make([]client.Scenario, 0, len(items))
	for _, it := range items {
		if activeOnly && !it.IsActive {
			continue
		}
		if name != "" && it.Name != name {
			continue
		}
		matches = append(matches, it)
	}
	if len(matches) == 0 {
		return 0, &client.CodeError{
			Code: client.ExitNotFound,
			Err:  errors.New("조건에 일치하는 테스트 시나리오를 찾을 수 없습니다"),
		}
	}
	if len(matches) > 1 {
		ids := make([]string, 0, len(matches))
		for _, m := range matches {
			ids = append(ids, fmt.Sprintf("%d(%s)", m.ID, m.Name))
		}
		return 0, &client.CodeError{
			Code: client.ExitUsage,
			Err:  fmt.Errorf("조건에 일치하는 테스트 시나리오가 %d건 있습니다 (%s). ID 또는 --name/--active 로 대상을 좁혀 주세요", len(matches), strings.Join(ids, ", ")),
		}
	}
	return int(matches[0].ID), nil
}

func fileToConfigField(filename string) (string, bool) {
	switch filename {
	case "ROBOT.md":
		return "soul_content", true
	case "SKILLS.md":
		return "skills_content", true
	case "TROUBLESHOOTING.md":
		return "troubleshooting_content", true
	case "ROBOT_LIMITS.json":
		return "limits_content", true
	default:
		return "", false
	}
}

func decodeJSONObject(data []byte) (map[string]any, error) {
	var m map[string]any
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, &client.CodeError{
			Code: client.ExitUsage,
			Err:  fmt.Errorf("JSON 객체 파싱 실패: %w", err),
		}
	}
	if m == nil {
		m = map[string]any{}
	}
	return m, nil
}

func schemaFieldTypes() map[string]string {
	s, err := clioutput.LoadContractSchema()
	if err != nil {
		return nil
	}
	return s.FieldTypes()
}

func schemaSecretEnvKeys() map[string]bool {
	s, err := clioutput.LoadContractSchema()
	if err != nil {
		return map[string]bool{}
	}
	return s.SecretEnvKeys()
}
