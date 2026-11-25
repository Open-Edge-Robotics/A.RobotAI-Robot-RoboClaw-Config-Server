package clicmd

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"

	"ai-config-server/internal/client"
	"ai-config-server/internal/clioutput"
	"github.com/wkqco33/wcli"
)

func newTransferCmd(rt *Runtime) *wcli.Command {
	trCmd := &wcli.Command{
		Use:       "transfer",
		Short:     "설정·시나리오 백업 내보내기/검증/가져오기",
		GroupName: "Remote",
	}

	var outPath string
	var includeSecrets, configsOnly, scenariosOnly bool
	exportCmd := &wcli.Command{
		Use:   "export",
		Short: "백업 JSON 내보내기 (--include-secrets 시 --out 0600 저장 권장)",
		Run: func(ctx *wcli.Context) error {
			if configsOnly && scenariosOnly {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("--configs-only 와 --scenarios-only 는 동시에 사용할 수 없습니다")}
			}
			incCfg := !scenariosOnly
			incSc := !configsOnly

			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			raw, err := cli.ExportBackup(rt.reqContext(ctx), client.ExportRequest{
				IncludeSecrets:   includeSecrets,
				IncludeConfigs:   incCfg,
				IncludeScenarios: incSc,
			})
			if err != nil {
				return err
			}
			if outPath != "" {
				perm := os.FileMode(0o644)
				if includeSecrets {
					perm = 0o600
				}
				if err := os.WriteFile(outPath, raw, perm); err != nil {
					return fmt.Errorf("백업 파일 저장 실패 (%s): %w", outPath, err)
				}
				if includeSecrets {
					_ = os.Chmod(outPath, 0o600)
				}
				if rt.JSON {
					return clioutput.WriteJSON(rt.out(), map[string]any{
						"saved":            outPath,
						"bytes":            len(raw),
						"includes_secrets": includeSecrets,
						"mode":             fmt.Sprintf("%04o", perm),
					})
				}
				fmt.Fprintf(rt.out(), "백업 저장 완료: %s (%d bytes, secrets=%t)\n", outPath, len(raw), includeSecrets)
				return nil
			}
			if includeSecrets {
				fmt.Fprintln(rt.errOut(), "[주의] 시크릿이 포함된 백업을 stdout으로 출력합니다. 파일 저장 시 --out <file>(0600) 사용을 권장합니다.")
			}
			_, err = rt.out().Write(raw)
			if err == nil && len(raw) > 0 && raw[len(raw)-1] != '\n' {
				_, err = fmt.Fprintln(rt.out())
			}
			return err
		},
	}
	exportCmd.Flags().StringVar(&outPath, "out", "o", "", "저장할 백업 JSON 파일 경로")
	exportCmd.Flags().BoolVar(&includeSecrets, "include-secrets", "", false, "API 키/토큰 등 시크릿 포함")
	exportCmd.Flags().BoolVar(&configsOnly, "configs-only", "", false, "설정 프로필만 내보내기")
	exportCmd.Flags().BoolVar(&scenariosOnly, "scenarios-only", "", false, "테스트 시나리오만 내보내기")

	var valFrom, valConflict, valActivation string
	validateCmd := &wcli.Command{
		Use:   "validate",
		Short: "백업 JSON 가져오기 사전 검증 (dry-run)",
		Run: func(ctx *wcli.Context) error {
			if valFrom == "" {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("--from <file.json|-> 플래그가 필요합니다")}
			}
			raw, err := rt.readInputBytes(valFrom)
			if err != nil {
				return err
			}
			if !json.Valid(raw) {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("올바른 JSON 파일이 아닙니다")}
			}
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			res, err := cli.ValidateImport(rt.reqContext(ctx), client.ImportRequest{
				Document: raw,
				Options: client.ImportOptions{
					ConflictPolicy:   valConflict,
					ActivationPolicy: valActivation,
				},
			})
			if err != nil {
				return err
			}
			return clioutput.WriteJSON(rt.out(), res)
		},
	}
	validateCmd.Flags().StringVar(&valFrom, "from", "f", "", "검증할 백업 JSON 파일 경로 ('-' 이면 stdin)")
	validateCmd.Flags().StringVar(&valConflict, "conflict", "", "skip", "충돌 정책 (skip|overwrite|copy)")
	validateCmd.Flags().StringVar(&valActivation, "activation", "", "keep_existing", "활성화 정책 (inactive|preserve|keep_existing)")

	var impFrom, impConflict, impActivation string
	var impDryRun bool
	importCmd := &wcli.Command{
		Use:   "import",
		Short: "백업 JSON 가져오기 (--dry-run 지원, overwrite 시 --yes 필요)",
		Run: func(ctx *wcli.Context) error {
			if impFrom == "" {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("--from <file.json|-> 플래그가 필요합니다")}
			}
			if !impDryRun && impConflict == "overwrite" {
				if err := rt.requireYes("백업 덮어쓰기(overwrite)"); err != nil {
					return err
				}
			}
			raw, err := rt.readInputBytes(impFrom)
			if err != nil {
				return err
			}
			if !json.Valid(raw) {
				return &client.CodeError{Code: client.ExitUsage, Err: errors.New("올바른 JSON 파일이 아닙니다")}
			}
			cli, _, err := rt.resolveClient(false)
			if err != nil {
				return err
			}
			req := client.ImportRequest{
				Document: raw,
				Options: client.ImportOptions{
					ConflictPolicy:   impConflict,
					ActivationPolicy: impActivation,
				},
			}
			if impDryRun {
				res, err := cli.ValidateImport(rt.reqContext(ctx), req)
				if err != nil {
					return err
				}
				return clioutput.WriteJSON(rt.out(), res)
			}
			res, err := cli.ImportBackup(rt.reqContext(ctx), req)
			if err != nil {
				return err
			}
			return clioutput.WriteJSON(rt.out(), res)
		},
	}
	importCmd.Flags().StringVar(&impFrom, "from", "f", "", "가져올 백업 JSON 파일 경로 ('-' 이면 stdin)")
	importCmd.Flags().StringVar(&impConflict, "conflict", "", "skip", "충돌 정책 (skip|overwrite|copy)")
	importCmd.Flags().StringVar(&impActivation, "activation", "", "keep_existing", "활성화 정책 (inactive|preserve|keep_existing)")
	importCmd.Flags().BoolVar(&impDryRun, "dry-run", "", false, "실제 반영 대신 사전 검증만 수행")

	trCmd.AddCommand(exportCmd, validateCmd, importCmd)
	return trCmd
}
