package clicmd

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"

	"ai-config-server/internal/client"
	"ai-config-server/internal/clioutput"
	"github.com/wkqco33/wcli"
)

func newConfigCmd(rt *Runtime) *wcli.Command {
	cfgCmd := &wcli.Command{
		Use:       "config",
		Aliases:   []string{"cfg"},
		Short:     "RoboClaw 설정 프로필 CRUD, 패치, 파일 관리",
		GroupName: "Remote",
	}

	cfgCmd.AddCommand(
		newConfigListCmd(rt),
		newConfigGetCmd(rt),
		newConfigCreateCmd(rt),
		newConfigPatchCmd(rt),
		newConfigDiffCmd(rt),
		newConfigActivateCmd(rt),
		newConfigCloneCmd(rt),
		newConfigDeleteCmd(rt),
		newConfigFileCmd(rt),
	)
	return cfgCmd
}

func newConfigListCmd(rt *Runtime) *wcli.Command {
	var robot, env string
	var activeOnly bool
	cmd := &wcli.Command{
		Use:   "list",
		Short: "설정 프로필 목록 조회",
		Run: func(ctx *wcli.Context) error {
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			items, err := cli.ListConfigs(rt.reqContext(ctx), robot, env)
			if err != nil {
				return err
			}
			if activeOnly {
				filtered := make([]client.Config, 0, len(items))
				for _, it := range items {
					if it.IsActive() {
						filtered = append(filtered, it)
					}
				}
				items = filtered
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), items)
			}
			rows := make([][]string, 0, len(items))
			for _, it := range items {
				act := ""
				if it.IsActive() {
					act = "ACTIVE"
				}
				rows = append(rows, []string{
					strconv.Itoa(it.ID()),
					act,
					it.RobotName(),
					it.Environment(),
					it.Name(),
					it.StringField("llm_provider") + "/" + it.StringField("llm_model"),
				})
			}
			return clioutput.WriteTable(rt.out(), []string{"ID", "STATE", "ROBOT", "ENV", "NAME", "LLM"}, rows)
		},
	}
	cmd.Flags().StringVar(&robot, "robot", "r", "", "로봇 이름으로 필터링")
	cmd.Flags().StringVar(&env, "env", "e", "", "환경 이름으로 필터링")
	cmd.Flags().BoolVar(&activeOnly, "active", "", false, "활성화된 프로필만 표시")
	return cmd
}

func newConfigGetCmd(rt *Runtime) *wcli.Command {
	var robot, env, name string
	var activeOnly bool
	cmd := &wcli.Command{
		Use:   "get [id]",
		Short: "설정 프로필 상세 조회 (시크릿 마스킹 유지)",
		Run: func(ctx *wcli.Context) error {
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			id, err := resolveConfigTarget(rctx, cli, ctx.Args, robot, env, name, activeOnly)
			if err != nil {
				return err
			}
			item, err := cli.GetConfig(rctx, id)
			if err != nil {
				return err
			}
			return clioutput.WriteJSON(rt.out(), item)
		},
	}
	cmd.Flags().StringVar(&robot, "robot", "r", "", "로봇 이름으로 대상 선택")
	cmd.Flags().StringVar(&env, "env", "e", "", "환경 이름으로 대상 선택")
	cmd.Flags().StringVar(&name, "name", "n", "", "프로필 이름으로 대상 선택")
	cmd.Flags().BoolVar(&activeOnly, "active", "", false, "활성 프로필 선택")
	return cmd
}

func applySetAndFileFlags(payload map[string]any, sets, setFiles []string) error {
	types := schemaFieldTypes()
	for _, expr := range sets {
		k, v, err := clioutput.ParseSetExpr(expr, types)
		if err != nil {
			return &client.CodeError{Code: client.ExitUsage, Err: err}
		}
		payload[k] = v
	}
	for _, expr := range setFiles {
		eq := strings.IndexByte(expr, '=')
		if eq <= 0 {
			return &client.CodeError{
				Code: client.ExitUsage,
				Err:  fmt.Errorf("잘못된 --set-file 형식입니다 (%q). key=path 형태여야 합니다", expr),
			}
		}
		key := strings.TrimSpace(expr[:eq])
		filePath := strings.TrimSpace(expr[eq+1:])
		data, err := os.ReadFile(filePath)
		if err != nil {
			return &client.CodeError{
				Code: client.ExitUsage,
				Err:  fmt.Errorf("--set-file 파일 읽기 실패 (%s): %w", filePath, err),
			}
		}
		payload[key] = string(data)
	}
	return nil
}

func newConfigCreateCmd(rt *Runtime) *wcli.Command {
	var fromPath string
	var sets []string
	var setFiles []string
	cmd := &wcli.Command{
		Use:   "create",
		Short: "신규 설정 프로필 등록 (--from JSON/stdin 및 --set/--set-file 지원)",
		Run: func(ctx *wcli.Context) error {
			payload := map[string]any{}
			if fromPath != "" {
				data, err := rt.readInputBytes(fromPath)
				if err != nil {
					return err
				}
				payload, err = decodeJSONObject(data)
				if err != nil {
					return err
				}
			}
			if err := applySetAndFileFlags(payload, sets, setFiles); err != nil {
				return err
			}
			if len(payload) == 0 {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("--from 또는 --set 으로 생성할 필드를 지정해야 합니다")}
			}

			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			created, err := cli.CreateConfig(rt.reqContext(ctx), payload)
			if err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), created)
			}
			fmt.Fprintf(rt.out(), "설정 등록 완료: ID=%d Name=%s (%s/%s)\n", created.ID(), created.Name(), created.RobotName(), created.Environment())
			return nil
		},
	}
	cmd.Flags().StringVar(&fromPath, "from", "f", "", "입력 JSON 파일 경로 ('-' 이면 stdin)")
	cmd.Flags().StringSliceVar(&sets, "set", "", nil, "필드 지정 (key=value, 반복 가능)")
	cmd.Flags().StringSliceVar(&setFiles, "set-file", "", nil, "파일 내용으로 필드 지정 (key=path, 반복 가능)")
	return cmd
}

func newConfigPatchCmd(rt *Runtime) *wcli.Command {
	var robot, env, name, fromPath string
	var activeOnly, dryRun bool
	var sets []string
	var setFiles []string
	cmd := &wcli.Command{
		Use:   "patch [id]",
		Short: "설정 프로필 부분 수정 (미언급 필드·시크릿 자동 보존, --dry-run 지원)",
		Run: func(ctx *wcli.Context) error {
			patch := map[string]any{}
			if fromPath != "" {
				data, err := rt.readInputBytes(fromPath)
				if err != nil {
					return err
				}
				patch, err = decodeJSONObject(data)
				if err != nil {
					return err
				}
			}
			if err := applySetAndFileFlags(patch, sets, setFiles); err != nil {
				return err
			}
			if len(patch) == 0 {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("수정할 필드를 --from, --set, 또는 --set-file 로 지정하세요")}
			}

			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			id, err := resolveConfigTarget(rctx, cli, ctx.Args, robot, env, name, activeOnly)
			if err != nil {
				return err
			}

			if dryRun {
				current, err := cli.GetConfig(rctx, id)
				if err != nil {
					return err
				}
				simulated := make(map[string]any, len(current))
				for k, v := range current {
					simulated[k] = v
				}
				for k, v := range patch {
					simulated[k] = v
				}
				diffs := clioutput.DiffMaps(current, simulated)
				if rt.JSON {
					return clioutput.WriteJSON(rt.out(), map[string]any{
						"dry_run": true,
						"id":      id,
						"diffs":   diffs,
					})
				}
				return writeDiffTable(rt, diffs)
			}

			updated, err := cli.PatchConfig(rctx, id, patch)
			if err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), updated)
			}
			fmt.Fprintf(rt.out(), "설정 부분 수정 완료: ID=%d Name=%s (%d개 필드 요청)\n", updated.ID(), updated.Name(), len(patch))
			return nil
		},
	}
	cmd.Flags().StringVar(&robot, "robot", "r", "", "로봇 이름으로 대상 선택")
	cmd.Flags().StringVar(&env, "env", "e", "", "환경 이름으로 대상 선택")
	cmd.Flags().StringVar(&name, "name", "n", "", "프로필 이름으로 대상 선택")
	cmd.Flags().BoolVar(&activeOnly, "active", "", false, "활성 프로필 선택")
	cmd.Flags().StringVar(&fromPath, "from", "f", "", "부분 수정 JSON 파일 경로 ('-' 이면 stdin)")
	cmd.Flags().StringSliceVar(&sets, "set", "", nil, "필드 지정 (key=value, 반복 가능)")
	cmd.Flags().StringSliceVar(&setFiles, "set-file", "", nil, "파일 내용으로 필드 지정 (key=path, 반복 가능)")
	cmd.Flags().BoolVar(&dryRun, "dry-run", "", false, "서버에 반영하지 않고 변경 diff만 미리 확인")
	return cmd
}

func newConfigDiffCmd(rt *Runtime) *wcli.Command {
	var againstPath string
	cmd := &wcli.Command{
		Use:   "diff <id1> [id2]",
		Short: "두 설정 프로필 또는 로컬 JSON 파일과의 필드 차이 비교",
		Run: func(ctx *wcli.Context) error {
			if len(ctx.Args) < 1 {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("비교할 기준 ID를 지정하세요")}
			}
			id1, err := parsePositiveID(ctx.Args[0])
			if err != nil {
				return err
			}
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			left, err := cli.GetConfig(rctx, id1)
			if err != nil {
				return err
			}

			var right map[string]any
			if againstPath != "" {
				data, err := rt.readInputBytes(againstPath)
				if err != nil {
					return err
				}
				right, err = decodeJSONObject(data)
				if err != nil {
					return err
				}
			} else if len(ctx.Args) >= 2 {
				id2, err := parsePositiveID(ctx.Args[1])
				if err != nil {
					return err
				}
				right, err = cli.GetConfig(rctx, id2)
				if err != nil {
					return err
				}
			} else {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("비교 대상 ID2 또는 --against <file.json> 을 지정하세요")}
			}

			diffs := clioutput.DiffMaps(left, right)
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), diffs)
			}
			return writeDiffTable(rt, diffs)
		},
	}
	cmd.Flags().StringVar(&againstPath, "against", "", "", "비교할 로컬 JSON 파일 경로 ('-' 이면 stdin)")
	return cmd
}

func writeDiffTable(rt *Runtime, diffs []clioutput.FieldDiff) error {
	if len(diffs) == 0 {
		fmt.Fprintln(rt.out(), "변경된 필드가 없습니다.")
		return nil
	}
	rows := make([][]string, 0, len(diffs))
	for _, d := range diffs {
		rows = append(rows, []string{d.Field, fmt.Sprintf("%v", d.Before), fmt.Sprintf("%v", d.After)})
	}
	return clioutput.WriteTable(rt.out(), []string{"FIELD", "BEFORE", "AFTER"}, rows)
}

func newConfigActivateCmd(rt *Runtime) *wcli.Command {
	var robot, env, name string
	cmd := &wcli.Command{
		Use:   "activate [id]",
		Short: "설정 프로필 활성화 (--yes 필요)",
		Run: func(ctx *wcli.Context) error {
			if err := rt.requireYes("설정 활성화"); err != nil {
				return err
			}
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			id, err := resolveConfigTarget(rctx, cli, ctx.Args, robot, env, name, false)
			if err != nil {
				return err
			}
			res, err := cli.ActivateConfig(rctx, id)
			if err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), res)
			}
			fmt.Fprintf(rt.out(), "설정 활성화 완료: ID=%d\n", id)
			return nil
		},
	}
	cmd.Flags().StringVar(&robot, "robot", "r", "", "로봇 이름으로 대상 선택")
	cmd.Flags().StringVar(&env, "env", "e", "", "환경 이름으로 대상 선택")
	cmd.Flags().StringVar(&name, "name", "n", "", "프로필 이름으로 대상 선택")
	return cmd
}

func newConfigCloneCmd(rt *Runtime) *wcli.Command {
	var robot, env, name, newName string
	var activeOnly bool
	cmd := &wcli.Command{
		Use:   "clone [id]",
		Short: "기존 설정 프로필 복제 (원본 자격 증명 보존)",
		Run: func(ctx *wcli.Context) error {
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			id, err := resolveConfigTarget(rctx, cli, ctx.Args, robot, env, name, activeOnly)
			if err != nil {
				return err
			}
			cloned, err := cli.CloneConfig(rctx, id)
			if err != nil {
				return err
			}
			if strings.TrimSpace(newName) != "" {
				cloned, err = cli.PatchConfig(rctx, cloned.ID(), map[string]any{"name": strings.TrimSpace(newName)})
				if err != nil {
					return err
				}
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), cloned)
			}
			fmt.Fprintf(rt.out(), "설정 복제 완료: 원본 ID=%d -> 복제 ID=%d (%s)\n", id, cloned.ID(), cloned.Name())
			return nil
		},
	}
	cmd.Flags().StringVar(&robot, "robot", "r", "", "로봇 이름으로 대상 선택")
	cmd.Flags().StringVar(&env, "env", "e", "", "환경 이름으로 대상 선택")
	cmd.Flags().StringVar(&name, "name", "n", "", "프로필 이름으로 대상 선택")
	cmd.Flags().BoolVar(&activeOnly, "active", "", false, "활성 프로필 선택")
	cmd.Flags().StringVar(&newName, "new-name", "", "", "복제본에 즉시 적용할 새 이름")
	return cmd
}

func newConfigDeleteCmd(rt *Runtime) *wcli.Command {
	var robot, env, name string
	cmd := &wcli.Command{
		Use:     "delete [id]",
		Aliases: []string{"rm"},
		Short:   "설정 프로필 삭제 (--yes 필요)",
		Run: func(ctx *wcli.Context) error {
			if err := rt.requireYes("설정 삭제"); err != nil {
				return err
			}
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			id, err := resolveConfigTarget(rctx, cli, ctx.Args, robot, env, name, false)
			if err != nil {
				return err
			}
			res, err := cli.DeleteConfig(rctx, id)
			if err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), res)
			}
			fmt.Fprintf(rt.out(), "설정 삭제 완료: ID=%d\n", id)
			return nil
		},
	}
	cmd.Flags().StringVar(&robot, "robot", "r", "", "로봇 이름으로 대상 선택")
	cmd.Flags().StringVar(&env, "env", "e", "", "환경 이름으로 대상 선택")
	cmd.Flags().StringVar(&name, "name", "n", "", "프로필 이름으로 대상 선택")
	return cmd
}

func newConfigFileCmd(rt *Runtime) *wcli.Command {
	fileCmd := &wcli.Command{
		Use:   "file",
		Short: "설정 프로필 파일(.env, ROBOT.md, SKILLS.md, TROUBLESHOOTING.md, ROBOT_LIMITS.json) 조회/반영",
	}

	var outPath string
	var revealSecrets bool
	getCmd := &wcli.Command{
		Use:   "get <id> <filename>",
		Short: "설정 파일 다운로드 (.env stdout 출력 시 기본 마스킹, --out 시 0600 저장)",
		Run: func(ctx *wcli.Context) error {
			if len(ctx.Args) < 2 {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("사용법: config file get <id> <filename>")}
			}
			id, err := parsePositiveID(ctx.Args[0])
			if err != nil {
				return err
			}
			filename := ctx.Args[1]
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			data, err := cli.GetConfigFile(rt.reqContext(ctx), id, filename)
			if err != nil {
				return err
			}
			if outPath != "" {
				perm := os.FileMode(0o644)
				if filename == ".env" {
					perm = 0o600
				}
				if err := os.WriteFile(outPath, data, perm); err != nil {
					return fmt.Errorf("파일 저장 실패 (%s): %w", outPath, err)
				}
				if filename == ".env" {
					_ = os.Chmod(outPath, 0o600)
				}
				if rt.JSON {
					return clioutput.WriteJSON(rt.out(), map[string]any{"saved": outPath, "bytes": len(data), "mode": fmt.Sprintf("%04o", perm)})
				}
				fmt.Fprintf(rt.out(), "저장 완료: %s (%d bytes)\n", outPath, len(data))
				return nil
			}
			output := string(data)
			if filename == ".env" && !revealSecrets {
				output = clioutput.MaskEnvContent(output, schemaSecretEnvKeys())
				fmt.Fprintln(rt.errOut(), "[안내] .env 시크릿 값이 마스킹되었습니다. 원본 저장은 --out <path>(0600) 또는 --reveal-secrets 를 사용하세요.")
			}
			_, err = fmt.Fprint(rt.out(), output)
			return err
		},
	}
	getCmd.Flags().StringVar(&outPath, "out", "o", "", "출력 저장 파일 경로 (.env 는 0600 권한으로 저장)")
	getCmd.Flags().BoolVar(&revealSecrets, "reveal-secrets", "", false, ".env stdout 출력 시 시크릿 마스킹 해제")

	var fromPath string
	setCmd := &wcli.Command{
		Use:   "set <id> <filename>",
		Short: "로컬 마크다운/JSON 파일을 설정 프로필에 PATCH 반영",
		Run: func(ctx *wcli.Context) error {
			if len(ctx.Args) < 2 {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("사용법: config file set <id> <filename> --from <path|->")}
			}
			id, err := parsePositiveID(ctx.Args[0])
			if err != nil {
				return err
			}
			filename := ctx.Args[1]
			field, ok := fileToConfigField(filename)
			if !ok {
				return &client.CodeError{
					Code: client.ExitUsage,
					Err:  fmt.Errorf("지원하지 않는 파일명입니다: %q (지원: ROBOT.md, SKILLS.md, TROUBLESHOOTING.md, ROBOT_LIMITS.json)", filename),
				}
			}
			if fromPath == "" {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("--from <path|-> 플래그가 필요합니다")}
			}
			data, err := rt.readInputBytes(fromPath)
			if err != nil {
				return err
			}
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			updated, err := cli.PatchConfig(rt.reqContext(ctx), id, map[string]any{field: string(data)})
			if err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), map[string]any{"id": updated.ID(), "file": filename, "field": field, "bytes": len(data)})
			}
			fmt.Fprintf(rt.out(), "파일 반영 완료: ID=%d %s -> %s (%d bytes)\n", updated.ID(), filename, field, len(data))
			return nil
		},
	}
	setCmd.Flags().StringVar(&fromPath, "from", "f", "", "입력 파일 경로 ('-' 이면 stdin)")

	fileCmd.AddCommand(getCmd, setCmd)
	return fileCmd
}
