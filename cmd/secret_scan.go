package cmd

import (
	"fmt"
	"os"

	"ai-config-server/internal/secretscan"
	"github.com/wkqco33/wcli"
)

func SecretScanCmd() *wcli.Command {
	return &wcli.Command{
		Use:   "secret-scan",
		Short: "Git 추적 파일의 시크릿/개인정보 패턴 검사",
		Run: func(ctx *wcli.Context) error {
			root, err := findRepoRoot()
			if err != nil {
				return err
			}

			findings, totalFiles, err := secretscan.ScanRepository(root)
			if err != nil {
				return fmt.Errorf("secret scan failed: %w", err)
			}

			if len(findings) > 0 {
				fmt.Fprintln(os.Stderr, "Potential sensitive data found in tracked files:")
				for _, f := range findings {
					fmt.Fprintf(os.Stderr, "  - %s: %s\n", f.Path, f.PatternName)
				}
				fmt.Fprintln(os.Stderr, "Use environment variables or an ignored local secret file.")
				return fmt.Errorf("found %d sensitive pattern matches", len(findings))
			}

			fmt.Printf("Secret scan passed (%d tracked files checked).\n", totalFiles)
			return nil
		},
	}
}
