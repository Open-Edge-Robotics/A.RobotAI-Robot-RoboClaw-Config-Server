package clicmd

import (
	"errors"
	"fmt"
	"sort"
	"strings"

	"ai-config-server/internal/cliconfig"
	"ai-config-server/internal/client"
	"ai-config-server/internal/clioutput"
	"github.com/wkqco33/wcli"
)

func newProfileCmd(rt *Runtime) *wcli.Command {
	profileCmd := &wcli.Command{
		Use:       "profile",
		Short:     "원격 ai-config-server 접속 프로필 관리",
		GroupName: "Remote",
	}

	var setURL, setTokenEnv, setTokenFile, setDevTokenEnv, setDevTokenFile string
	var setActivate bool
	setCmd := &wcli.Command{
		Use:   "set <name>",
		Short: "접속 프로필 등록 또는 갱신",
		Run: func(ctx *wcli.Context) error {
			if len(ctx.Args) < 1 || strings.TrimSpace(ctx.Args[0]) == "" {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("프로필 이름을 지정하세요")}
			}
			name := strings.TrimSpace(ctx.Args[0])
			targetURL := strings.TrimRight(strings.TrimSpace(setURL), "/")
			if targetURL == "" {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("--url 플래그가 필요합니다")}
			}

			path, err := rt.configPath()
			if err != nil {
				return err
			}
			store, err := cliconfig.Load(path)
			if err != nil {
				return err
			}
			prof := cliconfig.Profile{
				URL:             targetURL,
				TokenEnv:        strings.TrimSpace(setTokenEnv),
				TokenFile:       strings.TrimSpace(setTokenFile),
				DeviceTokenEnv:  strings.TrimSpace(setDevTokenEnv),
				DeviceTokenFile: strings.TrimSpace(setDevTokenFile),
			}
			store.Profiles[name] = prof
			if setActivate || store.ActiveProfile == "" {
				store.ActiveProfile = name
			}
			if err := cliconfig.Save(path, store); err != nil {
				return err
			}

			masked := prof.Mask(name, store.ActiveProfile == name)
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), masked)
			}
			fmt.Fprintf(rt.out(), "프로필 %q 저장 완료 (URL: %s, Active: %t)\n", name, masked.URL, masked.Active)
			return nil
		},
	}
	setCmd.Flags().StringVar(&setURL, "url", "", "", "서버 URL (예: http://127.0.0.1:8080)")
	setCmd.Flags().StringVar(&setTokenEnv, "token-env", "", "", "관리자 토큰 환경변수 이름")
	setCmd.Flags().StringVar(&setTokenFile, "token-file", "", "", "관리자 토큰 파일 경로")
	setCmd.Flags().StringVar(&setDevTokenEnv, "device-token-env", "", "", "디바이스 토큰 환경변수 이름")
	setCmd.Flags().StringVar(&setDevTokenFile, "device-token-file", "", "", "디바이스 토큰 파일 경로")
	setCmd.Flags().BoolVar(&setActivate, "use", "", false, "저장 후 기본 프로필로 활성화")

	listCmd := &wcli.Command{
		Use:   "list",
		Short: "저장된 접속 프로필 목록 조회",
		Run: func(ctx *wcli.Context) error {
			path, err := rt.configPath()
			if err != nil {
				return err
			}
			store, err := cliconfig.Load(path)
			if err != nil {
				return err
			}
			names := make([]string, 0, len(store.Profiles))
			for name := range store.Profiles {
				names = append(names, name)
			}
			sort.Strings(names)

			items := make([]cliconfig.MaskedProfile, 0, len(names))
			for _, name := range names {
				items = append(items, store.Profiles[name].Mask(name, store.ActiveProfile == name))
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), items)
			}
			rows := make([][]string, 0, len(items))
			for _, it := range items {
				mark := ""
				if it.Active {
					mark = "*"
				}
				rows = append(rows, []string{mark, it.Name, it.URL, it.TokenSource})
			}
			return clioutput.WriteTable(rt.out(), []string{"ACTIVE", "NAME", "URL", "TOKEN_SOURCE"}, rows)
		},
	}

	useCmd := &wcli.Command{
		Use:   "use <name>",
		Short: "기본 활성 프로필 전환",
		Run: func(ctx *wcli.Context) error {
			if len(ctx.Args) < 1 || strings.TrimSpace(ctx.Args[0]) == "" {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("활성화할 프로필 이름을 지정하세요")}
			}
			name := strings.TrimSpace(ctx.Args[0])
			path, err := rt.configPath()
			if err != nil {
				return err
			}
			store, err := cliconfig.Load(path)
			if err != nil {
				return err
			}
			prof, ok := store.Profiles[name]
			if !ok {
				return &client.CodeError{Code: client.ExitNotFound, Err: fmt.Errorf("프로필 %q 을(를) 찾을 수 없습니다", name)}
			}
			store.ActiveProfile = name
			if err := cliconfig.Save(path, store); err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), prof.Mask(name, true))
			}
			fmt.Fprintf(rt.out(), "활성 프로필을 %q (%s) 로 전환했습니다\n", name, prof.URL)
			return nil
		},
	}

	removeCmd := &wcli.Command{
		Use:     "remove <name>",
		Aliases: []string{"rm", "delete"},
		Short:   "저장된 접속 프로필 삭제",
		Run: func(ctx *wcli.Context) error {
			if len(ctx.Args) < 1 || strings.TrimSpace(ctx.Args[0]) == "" {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("삭제할 프로필 이름을 지정하세요")}
			}
			name := strings.TrimSpace(ctx.Args[0])
			path, err := rt.configPath()
			if err != nil {
				return err
			}
			store, err := cliconfig.Load(path)
			if err != nil {
				return err
			}
			if _, ok := store.Profiles[name]; !ok {
				return &client.CodeError{Code: client.ExitNotFound, Err: fmt.Errorf("프로필 %q 을(를) 찾을 수 없습니다", name)}
			}
			delete(store.Profiles, name)
			if store.ActiveProfile == name {
				store.ActiveProfile = ""
			}
			if err := cliconfig.Save(path, store); err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), map[string]any{"removed": name})
			}
			fmt.Fprintf(rt.out(), "프로필 %q 삭제 완료\n", name)
			return nil
		},
	}

	profileCmd.AddCommand(setCmd, listCmd, useCmd, removeCmd)
	return profileCmd
}

func newStatusCmd(rt *Runtime) *wcli.Command {
	var deviceMode bool
	cmd := &wcli.Command{
		Use:       "status",
		Short:     "원격 서버 상태(/ping, /ready) 및 인증 토큰 유효성 점검",
		GroupName: "Remote",
		Run: func(ctx *wcli.Context) error {
			cli, resolved, err := rt.resolveClient(deviceMode)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)

			result := map[string]any{
				"profile":      resolved.ProfileName,
				"url":          resolved.URL,
				"token_source": resolved.TokenSource,
				"ping":         false,
				"ready":        false,
				"auth_ok":      false,
			}

			if _, err := cli.Ping(rctx); err != nil {
				result["ping_error"] = err.Error()
				if rt.JSON {
					_ = clioutput.WriteJSON(rt.out(), result)
				}
				return err
			}
			result["ping"] = true

			if readyResp, err := cli.Ready(rctx); err == nil && readyResp["ready"] == true {
				result["ready"] = true
			} else if err != nil {
				result["ready_error"] = err.Error()
			}

			var authErr error
			if deviceMode {
				_, authErr = cli.ListDeviceConfigs(rctx, "", "")
			} else {
				_, authErr = cli.ListConfigs(rctx, "", "")
			}
			if authErr == nil {
				result["auth_ok"] = true
			} else {
				result["auth_error"] = authErr.Error()
			}

			if rt.JSON {
				if err := clioutput.WriteJSON(rt.out(), result); err != nil {
					return err
				}
				return authErr
			}

			rows := [][]string{
				{"URL", resolved.URL},
				{"PROFILE", resolved.ProfileName},
				{"TOKEN_SOURCE", resolved.TokenSource},
				{"PING", fmt.Sprintf("%v", result["ping"])},
				{"READY", fmt.Sprintf("%v", result["ready"])},
				{"AUTH_OK", fmt.Sprintf("%v", result["auth_ok"])},
			}
			if err := clioutput.WriteTable(rt.out(), []string{"CHECK", "VALUE"}, rows); err != nil {
				return err
			}
			return authErr
		},
	}
	cmd.Flags().BoolVar(&deviceMode, "device", "", false, "디바이스 토큰 권한으로 인증 점검")
	return cmd
}
