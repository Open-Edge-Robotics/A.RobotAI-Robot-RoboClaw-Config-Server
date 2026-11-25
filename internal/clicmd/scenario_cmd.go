package clicmd

import (
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"ai-config-server/internal/client"
	"ai-config-server/internal/clioutput"
	"github.com/wkqco33/wcli"
)

func newScenarioCmd(rt *Runtime) *wcli.Command {
	scCmd := &wcli.Command{
		Use:       "scenario",
		Aliases:   []string{"sc"},
		Short:     "테스트 시나리오 및 테스트 케이스 CRUD/관리",
		GroupName: "Remote",
	}

	scCmd.AddCommand(
		newScenarioListCmd(rt),
		newScenarioGetCmd(rt),
		newScenarioCreateCmd(rt),
		newScenarioUpdateCmd(rt),
		newScenarioPatchCmd(rt),
		newScenarioActivateCmd(rt),
		newScenarioCloneCmd(rt),
		newScenarioDeleteCmd(rt),
		newScenarioCaseCmd(rt),
	)
	return scCmd
}

func newScenarioListCmd(rt *Runtime) *wcli.Command {
	var robot, env string
	var activeOnly bool
	cmd := &wcli.Command{
		Use:   "list",
		Short: "테스트 시나리오 목록 조회",
		Run: func(ctx *wcli.Context) error {
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			items, err := cli.ListScenarios(rt.reqContext(ctx), robot, env)
			if err != nil {
				return err
			}
			if activeOnly {
				filtered := make([]client.Scenario, 0, len(items))
				for _, it := range items {
					if it.IsActive {
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
				if it.IsActive {
					act = "ACTIVE"
				}
				rows = append(rows, []string{
					strconv.FormatUint(uint64(it.ID), 10),
					act,
					it.RobotName,
					it.Environment,
					it.Name,
					strconv.Itoa(len(it.TestCases)),
				})
			}
			return clioutput.WriteTable(rt.out(), []string{"ID", "STATE", "ROBOT", "ENV", "NAME", "CASES"}, rows)
		},
	}
	cmd.Flags().StringVar(&robot, "robot", "r", "", "로봇 이름으로 필터링")
	cmd.Flags().StringVar(&env, "env", "e", "", "환경 이름으로 필터링")
	cmd.Flags().BoolVar(&activeOnly, "active", "", false, "활성화된 시나리오만 표시")
	return cmd
}

func newScenarioGetCmd(rt *Runtime) *wcli.Command {
	var robot, env, name string
	var activeOnly bool
	cmd := &wcli.Command{
		Use:   "get [id]",
		Short: "테스트 시나리오 상세 조회",
		Run: func(ctx *wcli.Context) error {
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			id, err := resolveScenarioTarget(rctx, cli, ctx.Args, robot, env, name, activeOnly)
			if err != nil {
				return err
			}
			item, err := cli.GetScenario(rctx, id)
			if err != nil {
				return err
			}
			return clioutput.WriteJSON(rt.out(), item)
		},
	}
	cmd.Flags().StringVar(&robot, "robot", "r", "", "로봇 이름으로 대상 선택")
	cmd.Flags().StringVar(&env, "env", "e", "", "환경 이름으로 대상 선택")
	cmd.Flags().StringVar(&name, "name", "n", "", "시나리오 이름으로 대상 선택")
	cmd.Flags().BoolVar(&activeOnly, "active", "", false, "활성 시나리오 선택")
	return cmd
}

func newScenarioCreateCmd(rt *Runtime) *wcli.Command {
	var fromPath string
	var sets []string
	cmd := &wcli.Command{
		Use:   "create",
		Short: "신규 테스트 시나리오 등록",
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
			if err := applySetAndFileFlags(payload, sets, nil); err != nil {
				return err
			}
			if len(payload) == 0 {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("--from 또는 --set 으로 시나리오 필드를 지정하세요")}
			}
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			created, err := cli.CreateScenario(rt.reqContext(ctx), payload)
			if err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), created)
			}
			fmt.Fprintf(rt.out(), "시나리오 등록 완료: ID=%d Name=%s (%s/%s)\n", created.ID, created.Name, created.RobotName, created.Environment)
			return nil
		},
	}
	cmd.Flags().StringVar(&fromPath, "from", "f", "", "입력 JSON 파일 경로 ('-' 이면 stdin)")
	cmd.Flags().StringSliceVar(&sets, "set", "", nil, "필드 지정 (key=value, 반복 가능)")
	return cmd
}

func newScenarioUpdateCmd(rt *Runtime) *wcli.Command {
	var fromPath string
	cmd := &wcli.Command{
		Use:   "update <id>",
		Short: "테스트 시나리오 전체 교체 (PUT)",
		Run: func(ctx *wcli.Context) error {
			if len(ctx.Args) < 1 {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("수정할 시나리오 ID를 지정하세요")}
			}
			id, err := parsePositiveID(ctx.Args[0])
			if err != nil {
				return err
			}
			if fromPath == "" {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("--from <file.json|-> 플래그가 필요합니다")}
			}
			data, err := rt.readInputBytes(fromPath)
			if err != nil {
				return err
			}
			payload, err := decodeJSONObject(data)
			if err != nil {
				return err
			}
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			updated, err := cli.UpdateScenario(rt.reqContext(ctx), id, payload)
			if err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), updated)
			}
			fmt.Fprintf(rt.out(), "시나리오 교체 완료: ID=%d Name=%s\n", updated.ID, updated.Name)
			return nil
		},
	}
	cmd.Flags().StringVar(&fromPath, "from", "f", "", "입력 JSON 파일 경로 ('-' 이면 stdin)")
	return cmd
}

func newScenarioPatchCmd(rt *Runtime) *wcli.Command {
	var robot, env, name, fromPath string
	var activeOnly bool
	var sets []string
	cmd := &wcli.Command{
		Use:   "patch [id]",
		Short: "테스트 시나리오 부분 수정 (PATCH, 미언급 필드·is_active 보존)",
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
			if err := applySetAndFileFlags(patch, sets, nil); err != nil {
				return err
			}
			if len(patch) == 0 {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("수정할 필드를 --from 또는 --set 으로 지정하세요")}
			}
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			id, err := resolveScenarioTarget(rctx, cli, ctx.Args, robot, env, name, activeOnly)
			if err != nil {
				return err
			}
			updated, err := cli.PatchScenario(rctx, id, patch)
			if err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), updated)
			}
			fmt.Fprintf(rt.out(), "시나리오 부분 수정 완료: ID=%d Name=%s\n", updated.ID, updated.Name)
			return nil
		},
	}
	cmd.Flags().StringVar(&robot, "robot", "r", "", "로봇 이름으로 대상 선택")
	cmd.Flags().StringVar(&env, "env", "e", "", "환경 이름으로 대상 선택")
	cmd.Flags().StringVar(&name, "name", "n", "", "시나리오 이름으로 대상 선택")
	cmd.Flags().BoolVar(&activeOnly, "active", "", false, "활성 시나리오 선택")
	cmd.Flags().StringVar(&fromPath, "from", "f", "", "부분 수정 JSON 파일 경로 ('-' 이면 stdin)")
	cmd.Flags().StringSliceVar(&sets, "set", "", nil, "필드 지정 (key=value, 반복 가능)")
	return cmd
}

func newScenarioActivateCmd(rt *Runtime) *wcli.Command {
	var robot, env, name string
	cmd := &wcli.Command{
		Use:   "activate [id]",
		Short: "테스트 시나리오 활성화 (--yes 필요)",
		Run: func(ctx *wcli.Context) error {
			if err := rt.requireYes("시나리오 활성화"); err != nil {
				return err
			}
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			id, err := resolveScenarioTarget(rctx, cli, ctx.Args, robot, env, name, false)
			if err != nil {
				return err
			}
			res, err := cli.ActivateScenario(rctx, id)
			if err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), res)
			}
			fmt.Fprintf(rt.out(), "시나리오 활성화 완료: ID=%d\n", id)
			return nil
		},
	}
	cmd.Flags().StringVar(&robot, "robot", "r", "", "로봇 이름으로 대상 선택")
	cmd.Flags().StringVar(&env, "env", "e", "", "환경 이름으로 대상 선택")
	cmd.Flags().StringVar(&name, "name", "n", "", "시나리오 이름으로 대상 선택")
	return cmd
}

func newScenarioCloneCmd(rt *Runtime) *wcli.Command {
	var robot, env, name, newName string
	var activeOnly bool
	cmd := &wcli.Command{
		Use:   "clone [id]",
		Short: "기존 테스트 시나리오 복제",
		Run: func(ctx *wcli.Context) error {
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			id, err := resolveScenarioTarget(rctx, cli, ctx.Args, robot, env, name, activeOnly)
			if err != nil {
				return err
			}
			cloned, err := cli.CloneScenario(rctx, id)
			if err != nil {
				return err
			}
			if strings.TrimSpace(newName) != "" {
				cloned, err = cli.PatchScenario(rctx, int(cloned.ID), map[string]any{"name": strings.TrimSpace(newName)})
				if err != nil {
					return err
				}
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), cloned)
			}
			fmt.Fprintf(rt.out(), "시나리오 복제 완료: 원본 ID=%d -> 복제 ID=%d (%s)\n", id, cloned.ID, cloned.Name)
			return nil
		},
	}
	cmd.Flags().StringVar(&robot, "robot", "r", "", "로봇 이름으로 대상 선택")
	cmd.Flags().StringVar(&env, "env", "e", "", "환경 이름으로 대상 선택")
	cmd.Flags().StringVar(&name, "name", "n", "", "시나리오 이름으로 대상 선택")
	cmd.Flags().BoolVar(&activeOnly, "active", "", false, "활성 시나리오 선택")
	cmd.Flags().StringVar(&newName, "new-name", "", "", "복제본에 즉시 적용할 새 이름")
	return cmd
}

func newScenarioDeleteCmd(rt *Runtime) *wcli.Command {
	var robot, env, name string
	cmd := &wcli.Command{
		Use:     "delete [id]",
		Aliases: []string{"rm"},
		Short:   "테스트 시나리오 삭제 (--yes 필요)",
		Run: func(ctx *wcli.Context) error {
			if err := rt.requireYes("시나리오 삭제"); err != nil {
				return err
			}
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			id, err := resolveScenarioTarget(rctx, cli, ctx.Args, robot, env, name, false)
			if err != nil {
				return err
			}
			res, err := cli.DeleteScenario(rctx, id)
			if err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), res)
			}
			fmt.Fprintf(rt.out(), "시나리오 삭제 완료: ID=%d\n", id)
			return nil
		},
	}
	cmd.Flags().StringVar(&robot, "robot", "r", "", "로봇 이름으로 대상 선택")
	cmd.Flags().StringVar(&env, "env", "e", "", "환경 이름으로 대상 선택")
	cmd.Flags().StringVar(&name, "name", "n", "", "시나리오 이름으로 대상 선택")
	return cmd
}

func newScenarioCaseCmd(rt *Runtime) *wcli.Command {
	caseCmd := &wcli.Command{
		Use:   "case",
		Short: "시나리오 내부 test_cases 항목 단위 추가/수정/삭제",
	}

	var addFrom, addID, addName, addType, addStep string
	var addTimeout int
	var addEnabled bool
	addCmd := &wcli.Command{
		Use:   "add <scenario-id>",
		Short: "시나리오에 테스트 케이스 추가",
		Run: func(ctx *wcli.Context) error {
			if len(ctx.Args) < 1 {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("시나리오 ID를 지정하세요")}
			}
			scID, err := parsePositiveID(ctx.Args[0])
			if err != nil {
				return err
			}
			var tc client.TestCase
			if addFrom != "" {
				data, err := rt.readInputBytes(addFrom)
				if err != nil {
					return err
				}
				if err := json.Unmarshal(data, &tc); err != nil {
					return &client.CodeError{Code: client.ExitUsage, Err: fmt.Errorf("테스트 케이스 JSON 파싱 실패: %w", err)}
				}
			} else {
				tc = client.TestCase{
					ID:        addID,
					Name:      addName,
					Step:      addStep,
					Type:      addType,
					TimeoutMs: addTimeout,
					Enabled:   addEnabled,
				}
			}
			if strings.TrimSpace(tc.ID) == "" || strings.TrimSpace(tc.Name) == "" {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("테스트 케이스 id와 name은 필수입니다")}
			}

			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			sc, err := cli.GetScenario(rctx, scID)
			if err != nil {
				return err
			}
			for _, existing := range sc.TestCases {
				if existing.ID == tc.ID {
					return &client.CodeError{Code: client.ExitConflict, Err: fmt.Errorf("테스트 케이스 ID %q 이(가) 이미 존재합니다", tc.ID)}
				}
			}
			sc.TestCases = append(sc.TestCases, tc)
			updated, err := cli.PatchScenario(rctx, scID, map[string]any{"test_cases": sc.TestCases})
			if err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), updated)
			}
			fmt.Fprintf(rt.out(), "테스트 케이스 추가 완료: 시나리오 ID=%d, Case=%s (총 %d건)\n", scID, tc.ID, len(updated.TestCases))
			return nil
		},
	}
	addCmd.Flags().StringVar(&addFrom, "from", "f", "", "테스트 케이스 JSON 파일 경로 ('-' 이면 stdin)")
	addCmd.Flags().StringVar(&addID, "id", "", "", "케이스 ID")
	addCmd.Flags().StringVar(&addName, "name", "", "", "케이스 이름")
	addCmd.Flags().StringVar(&addType, "type", "", "ping", "케이스 유형 (ping, battery 등)")
	addCmd.Flags().StringVar(&addStep, "step", "", "", "단계 설명")
	addCmd.Flags().IntVar(&addTimeout, "timeout-ms", "", 5000, "타임아웃(ms)")
	addCmd.Flags().BoolVar(&addEnabled, "enabled", "", true, "활성 여부")

	removeCmd := &wcli.Command{
		Use:     "remove <scenario-id> <case-id>",
		Aliases: []string{"rm"},
		Short:   "시나리오에서 특정 테스트 케이스 제거 (--yes 필요)",
		Run: func(ctx *wcli.Context) error {
			if len(ctx.Args) < 2 {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("사용법: scenario case remove <scenario-id> <case-id> --yes")}
			}
			if err := rt.requireYes("테스트 케이스 삭제"); err != nil {
				return err
			}
			scID, err := parsePositiveID(ctx.Args[0])
			if err != nil {
				return err
			}
			caseID := ctx.Args[1]
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			rctx := rt.reqContext(ctx)
			sc, err := cli.GetScenario(rctx, scID)
			if err != nil {
				return err
			}
			kept := make([]client.TestCase, 0, len(sc.TestCases))
			found := false
			for _, tc := range sc.TestCases {
				if tc.ID == caseID {
					found = true
					continue
				}
				kept = append(kept, tc)
			}
			if !found {
				return &client.CodeError{Code: client.ExitNotFound, Err: fmt.Errorf("테스트 케이스 %q 을(를) 찾을 수 없습니다", caseID)}
			}
			updated, err := cli.PatchScenario(rctx, scID, map[string]any{"test_cases": kept})
			if err != nil {
				return err
			}
			if rt.JSON {
				return clioutput.WriteJSON(rt.out(), updated)
			}
			fmt.Fprintf(rt.out(), "테스트 케이스 삭제 완료: 시나리오 ID=%d, Case=%s (남은 %d건)\n", scID, caseID, len(updated.TestCases))
			return nil
		},
	}

	caseCmd.AddCommand(addCmd, removeCmd)
	return caseCmd
}
