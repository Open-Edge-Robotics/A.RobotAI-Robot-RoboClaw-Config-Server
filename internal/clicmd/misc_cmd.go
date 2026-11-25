package clicmd

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"ai-config-server/internal/client"
	"ai-config-server/internal/clioutput"
	"github.com/wkqco33/wcli"
)

func newDeviceCmd(rt *Runtime) *wcli.Command {
	devCmd := &wcli.Command{
		Use:       "device",
		Short:     "로봇 디바이스 관점의 배포 설정/파일/시나리오 검증",
		GroupName: "Remote",
	}

	var robot, env string
	var v2 bool
	activeCfgCmd := &wcli.Command{
		Use:   "active-config",
		Short: "로봇이 내려받는 활성 설정 조회 (v1 또는 --v2 runtime manifest)",
		Run: func(ctx *wcli.Context) error {
			if robot == "" || env == "" {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("--robot 및 --env 플래그는 필수입니다")}
			}
			cli, _, err := rt.resolveClient(true)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			if v2 {
				res, err := cli.GetActiveRuntimeConfigV2(rctx, robot, env)
				if err != nil {
					return err
				}
				return clioutput.WriteJSON(rt.out(), res)
			}
			res, err := cli.GetActiveConfig(rctx, robot, env)
			if err != nil {
				return err
			}
			return clioutput.WriteJSON(rt.out(), res)
		},
	}
	activeCfgCmd.Flags().StringVar(&robot, "robot", "r", "", "로봇 이름 (필수)")
	activeCfgCmd.Flags().StringVar(&env, "env", "e", "", "환경 이름 (필수)")
	activeCfgCmd.Flags().BoolVar(&v2, "v2", "", false, "v2 runtime-config manifest 조회")

	var fRobot, fEnv, fOut string
	var fReveal bool
	fileCmd := &wcli.Command{
		Use:   "file <filename>",
		Short: "로봇이 내려받는 활성 배포 파일(.env, ROBOT.md 등) 조회",
		Run: func(ctx *wcli.Context) error {
			if len(ctx.Args) < 1 {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("사용법: device file <filename> --robot R --env E")}
			}
			if fRobot == "" || fEnv == "" {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("--robot 및 --env 플래그는 필수입니다")}
			}
			filename := ctx.Args[0]
			cli, _, err := rt.resolveClient(true)
			if err != nil {
				return err
			}
			data, err := cli.GetActiveConfigFile(rt.reqContext(ctx), fRobot, fEnv, filename)
			if err != nil {
				return err
			}
			if fOut != "" {
				perm := os.FileMode(0o644)
				if filename == ".env" {
					perm = 0o600
				}
				if err := os.WriteFile(fOut, data, perm); err != nil {
					return fmt.Errorf("파일 저장 실패 (%s): %w", fOut, err)
				}
				if filename == ".env" {
					_ = os.Chmod(fOut, 0o600)
				}
				if rt.JSON {
					return clioutput.WriteJSON(rt.out(), map[string]any{"saved": fOut, "bytes": len(data)})
				}
				fmt.Fprintf(rt.out(), "저장 완료: %s (%d bytes)\n", fOut, len(data))
				return nil
			}
			output := string(data)
			if filename == ".env" && !fReveal {
				output = clioutput.MaskEnvContent(output, schemaSecretEnvKeys())
				fmt.Fprintln(rt.errOut(), "[안내] .env 시크릿 값이 마스킹되었습니다. 원본 저장은 --out <path>(0600) 또는 --reveal-secrets 를 사용하세요.")
			}
			_, err = fmt.Fprint(rt.out(), output)
			return err
		},
	}
	fileCmd.Flags().StringVar(&fRobot, "robot", "r", "", "로봇 이름 (필수)")
	fileCmd.Flags().StringVar(&fEnv, "env", "e", "", "환경 이름 (필수)")
	fileCmd.Flags().StringVar(&fOut, "out", "o", "", "저장할 파일 경로 (.env 는 0600)")
	fileCmd.Flags().BoolVar(&fReveal, "reveal-secrets", "", false, ".env stdout 출력 시 마스킹 해제")

	var sRobot, sEnv string
	activeScCmd := &wcli.Command{
		Use:   "active-scenario",
		Short: "로봇의 활성 테스트 시나리오 조회",
		Run: func(ctx *wcli.Context) error {
			if sRobot == "" || sEnv == "" {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("--robot 및 --env 플래그는 필수입니다")}
			}
			cli, _, err := rt.resolveClient(true)
			if err != nil {
				return err
			}
			res, err := cli.GetActiveScenario(rt.reqContext(ctx), sRobot, sEnv)
			if err != nil {
				return err
			}
			return clioutput.WriteJSON(rt.out(), res)
		},
	}
	activeScCmd.Flags().StringVar(&sRobot, "robot", "r", "", "로봇 이름 (필수)")
	activeScCmd.Flags().StringVar(&sEnv, "env", "e", "", "환경 이름 (필수)")

	devCmd.AddCommand(activeCfgCmd, fileCmd, activeScCmd)
	return devCmd
}

func newMcpCmd(rt *Runtime) *wcli.Command {
	mcpCmd := &wcli.Command{
		Use:       "mcp",
		Short:     "MCP 서버 카탈로그 조회",
		GroupName: "Remote",
	}

	var query string
	catCmd := &wcli.Command{
		Use:   "catalog",
		Short: "서버의 MCP 카탈로그 검색",
		Run: func(ctx *wcli.Context) error {
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			res, err := cli.ListMcpCatalog(rt.reqContext(ctx), query)
			if err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), res)
			}
			rows := make([][]string, 0, len(res.Servers))
			for _, s := range res.Servers {
				rows = append(rows, []string{s.Name, s.Category, s.Transport, s.DisplayName})
			}
			return clioutput.WriteTable(rt.out(), []string{"NAME", "CATEGORY", "TRANSPORT", "DISPLAY_NAME"}, rows)
		},
	}
	catCmd.Flags().StringVar(&query, "query", "q", "", "검색어 필터")

	mcpCmd.AddCommand(catCmd)
	return mcpCmd
}

func newSchemaCmd(rt *Runtime) *wcli.Command {
	schemaCmd := &wcli.Command{
		Use:       "schema",
		Short:     "내장 Runtime Contract 필드/타입/기본값 오프라인 탐색 (에이전트 참고용)",
		GroupName: "Remote",
	}

	var query, scope string
	var secretsOnly bool
	fieldsCmd := &wcli.Command{
		Use:   "fields",
		Short: "설정 필드 메타데이터(api_json, env, type, default, secret, enum) 조회",
		Run: func(ctx *wcli.Context) error {
			schema, err := clioutput.LoadContractSchema()
			if err != nil {
				return err
			}
			fields := schema.FilterFields(query, scope, secretsOnly)
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), map[string]any{
					"contract_version": schema.ContractVersion,
					"schema_version":   schema.SchemaVersion,
					"count":            len(fields),
					"fields":           fields,
				})
			}
			rows := make([][]string, 0, len(fields))
			for _, f := range fields {
				sec := ""
				if f.Secret {
					sec = "SECRET"
				}
				enumStr := ""
				if len(f.Enum) > 0 {
					enumStr = strings.Join(f.Enum, "|")
				}
				rows = append(rows, []string{f.APIJSON, f.Type, f.Env, sec, enumStr})
			}
			return clioutput.WriteTable(rt.out(), []string{"API_JSON", "TYPE", "ENV", "SECRET", "ENUM"}, rows)
		},
	}
	fieldsCmd.Flags().StringVar(&query, "query", "q", "", "필드명/env/설명 부분 일치 검색")
	fieldsCmd.Flags().StringVar(&scope, "scope", "", "", "스코프 필터 (runtime, host 등)")
	fieldsCmd.Flags().BoolVar(&secretsOnly, "secrets-only", "", false, "시크릿 필드만 출력")

	schemaCmd.AddCommand(fieldsCmd)
	return schemaCmd
}
