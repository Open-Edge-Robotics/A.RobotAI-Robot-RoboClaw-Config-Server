package secretscan_test

import (
	"os"
	"path/filepath"
	"testing"

	"ai-config-server/internal/secretscan"
)

func projectRoot(t *testing.T) string {
	t.Helper()
	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("failed to get working dir: %v", err)
	}
	root, err := filepath.Abs(filepath.Join(wd, "..", ".."))
	if err != nil {
		t.Fatalf("failed to resolve root dir: %v", err)
	}
	return root
}

func TestScanRepository_CurrentRepoPasses(t *testing.T) {
	root := projectRoot(t)
	findings, totalFiles, err := secretscan.ScanRepository(root)
	if err != nil {
		t.Fatalf("ScanRepository failed: %v", err)
	}
	if len(findings) > 0 {
		for _, f := range findings {
			t.Errorf("unexpected sensitive finding in %s: %s", f.Path, f.PatternName)
		}
	}
	if totalFiles == 0 {
		t.Errorf("expected at least 1 tracked file, got 0")
	}
}

func TestScanFile_DetectsSecrets(t *testing.T) {
	tempDir := t.TempDir()

	tests := []struct {
		name        string
		content     string
		fileName    string
		expectMatch string
	}{
		{
			name:        "OpenAI key",
			content:     "API_KEY=s" + "k-abcdefghijklmnopqrstuvwxyz123",
			fileName:    "config.env",
			expectMatch: "OpenAI-style key",
		},
		{
			name:        "Private key",
			content:     "-----BEGIN " + "RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA0...",
			fileName:    "key.pem",
			expectMatch: "private key",
		},
		{
			name:        "Real credential assignment",
			content:     "api" + "_key: \"my_prod_key_xyz99887766\"",
			fileName:    "test.yaml",
			expectMatch: "credential assignment",
		},
		{
			name:        "Placeholder credential assignment (allowed)",
			content:     "api" + `_key: "dummy-secret-placeholder-value"`,
			fileName:    "test.yaml",
			expectMatch: "",
		},
		{
			name:        "Binary file ignored",
			content:     "fake s" + "k-" + "abcdefghijklmnopqrstuvwxyz123 \x00 binary",
			fileName:    "data.bin",
			expectMatch: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			path := filepath.Join(tempDir, tt.fileName)
			if err := os.WriteFile(path, []byte(tt.content), 0644); err != nil {
				t.Fatal(err)
			}
			findings, err := secretscan.ScanFile(path, tt.fileName)
			if err != nil {
				t.Fatalf("ScanFile error: %v", err)
			}
			if tt.expectMatch == "" {
				if len(findings) > 0 {
					t.Errorf("expected no findings, got %+v", findings)
				}
			} else {
				found := false
				for _, f := range findings {
					if f.PatternName == tt.expectMatch {
						found = true
						break
					}
				}
				if !found {
					t.Errorf("expected finding %q, got %+v", tt.expectMatch, findings)
				}
			}
		})
	}
}
