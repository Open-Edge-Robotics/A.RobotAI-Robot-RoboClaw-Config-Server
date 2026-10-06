package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"ai-config-server/internal/contract"
	"github.com/wkqco33/wcli"
)

// findRepoRoot finds the repository root by looking for go.mod or contracts directory.
func findRepoRoot() (string, error) {
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	dir := wd
	for {
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return wd, nil
}

func ContractCmd() *wcli.Command {
	contractCmd := &wcli.Command{
		Use:   "contract",
		Short: "Runtime contract 및 schema 관리/검증 명령어",
	}

	var schemaOnly bool
	var contractOnly bool
	checkCmd := &wcli.Command{
		Use:   "check",
		Short: "Vendored runtime contract 및 schema lock checksum 검증",
		Run: func(ctx *wcli.Context) error {
			root, err := findRepoRoot()
			if err != nil {
				return err
			}

			contractsDir := filepath.Join(root, "contracts")
			schemaFile := filepath.Join(root, "schemas", "robo-claw-runtime-config-v2.schema.json")
			schemaLockFile := filepath.Join(root, "schemas", "schema-lock.json")
			dartFile := filepath.Join(root, "frontend", "lib", "models", "runtime_config_contract.g.dart")
			runtimeContractFile := filepath.Join(contractsDir, "runtime-contract.json")

			if !contractOnly {
				lock, err := contract.CheckSchemaLock(schemaFile, schemaLockFile)
				if err != nil {
					return err
				}
				fmt.Printf("schema lock valid: %s (%s)\n", lock.SchemaVersion, lock.SHA256)
			}

			if !schemaOnly {
				lock, err := contract.CheckContractLock(contractsDir)
				if err != nil {
					return err
				}
				fmt.Printf("contract lock valid: %s\n", lock.Version)

				// Verify Dart contract artifact is up to date
				if _, err := os.Stat(dartFile); err == nil {
					upToDate, err := contract.GenerateDartArtifact(runtimeContractFile, dartFile, true)
					if err != nil {
						return err
					}
					if !upToDate {
						return fmt.Errorf("dart contract is stale. Run 'aics contract generate'")
					}
					fmt.Println("Dart contract is up to date.")
				}
			}

			return nil
		},
	}
	checkCmd.Flags().BoolVar(&schemaOnly, "schema-only", "", false, "스키마 락만 검증")
	checkCmd.Flags().BoolVar(&contractOnly, "contract-only", "", false, "컨트랙트 락만 검증")

	var checkStale bool
	generateCmd := &wcli.Command{
		Use:   "generate",
		Short: "Vendored runtime contract에서 Flutter Dart artifact 생성",
		Run: func(ctx *wcli.Context) error {
			root, err := findRepoRoot()
			if err != nil {
				return err
			}

			runtimeContractFile := filepath.Join(root, "contracts", "runtime-contract.json")
			dartFile := filepath.Join(root, "frontend", "lib", "models", "runtime_config_contract.g.dart")

			upToDate, err := contract.GenerateDartArtifact(runtimeContractFile, dartFile, checkStale)
			if err != nil {
				return err
			}

			if checkStale {
				if !upToDate {
					return fmt.Errorf("dart contract is stale. Run 'aics contract generate'")
				}
				fmt.Println("Dart contract is up to date.")
			} else {
				fmt.Printf("generated: %s\n", dartFile)
			}
			return nil
		},
	}
	generateCmd.Flags().BoolVar(&checkStale, "check", "", false, "파일을 덮어쓰지 않고 최신 상태인지 검사")

	var sourceDir string
	var version string
	var project = "wkqco33/rcf-config-contract"
	updateCmd := &wcli.Command{
		Use:   "update",
		Short: "GitLab contract release bundle로부터 contract 갱신",
		Run: func(ctx *wcli.Context) error {
			root, err := findRepoRoot()
			if err != nil {
				return err
			}

			targetDir := filepath.Join(root, "contracts")
			var updatedVersion string
			if sourceDir != "" {
				updatedVersion, err = contract.UpdateContract(sourceDir, targetDir)
			} else if version != "" {
				updatedVersion, err = contract.UpdateContractFromGitLab(project, version, targetDir)
			} else {
				return fmt.Errorf("--from 또는 --version 플래그 중 하나를 지정해야 합니다")
			}
			if err != nil {
				return err
			}

			fmt.Printf("updated rcf runtime contract: %s\n", updatedVersion)
			return nil
		},
	}
	updateCmd.Flags().StringVar(&sourceDir, "from", "", "", "릴리스 번들 디렉터리 경로")
	updateCmd.Flags().StringVar(&version, "version", "", "", "GitLab Release version (예: v2.0.1)")
	updateCmd.Flags().StringVar(&project, "project", "", "wkqco33/rcf-config-contract", "GitLab project path")

	contractCmd.AddCommand(checkCmd, generateCmd, updateCmd)
	return contractCmd
}
