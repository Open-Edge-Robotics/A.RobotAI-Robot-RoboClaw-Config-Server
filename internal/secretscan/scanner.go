package secretscan

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

type Finding struct {
	Path        string
	PatternName string
}

type patternDef struct {
	name    string
	pattern *regexp.Regexp
}

var (
	credAssignRegex = regexp.MustCompile(`(?i)[\w-]*(?:api[_-]?key|access[_-]?key|secret|password|passwd|token)[\w-]*\s*[:=]\s*["']([^"'${}\s]{12,})`)

	patterns = []patternDef{
		{"private key", regexp.MustCompile(`-----BEGIN [A-Z ]*PRIVATE KEY-----`)},
		{"OpenAI-style key", regexp.MustCompile(`\bsk-[A-Za-z0-9]{20,}\b`)},
		{"GitHub token", regexp.MustCompile(`\bgh[pousr]_[A-Za-z0-9_]{20,}\b`)},
		{"Slack token", regexp.MustCompile(`\bxox[baprs]-[A-Za-z0-9-]{10,}\b`)},
		{"LangSmith token", regexp.MustCompile(`\blsv2_[A-Za-z0-9_]{20,}\b`)},
		{"credential assignment", credAssignRegex},
		{"email address", regexp.MustCompile(`\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b`)},
		{"Korean phone number", regexp.MustCompile(`\b01[016789][- ]?\d{3,4}[- ]?\d{4}\b`)},
	}

	placeholderHints = []string{
		"replace-with",
		"replace_with",
		"your-",
		"your_",
		"<",
		"changeme",
		"change-me",
		"example",
		"secret",
		"token",
		"dummy",
		"fake",
		"stub",
		"mock",
		"sample",
		"masked",
		"redacted",
		"placeholder",
		"existing",
		"1234",
		"abcd",
	}
)

func isPlaceholder(value string) bool {
	lowered := strings.ToLower(value)
	for _, h := range placeholderHints {
		if strings.Contains(lowered, h) {
			return true
		}
	}
	return false
}

// TrackedFiles returns the list of git-tracked relative file paths.
func TrackedFiles(rootDir string) ([]string, error) {
	cmd := exec.Command("git", "ls-files", "-z")
	cmd.Dir = rootDir
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("git ls-files failed: %w", err)
	}

	rawParts := bytes.Split(out, []byte{0})
	var files []string
	for _, p := range rawParts {
		if len(p) > 0 {
			files = append(files, string(p))
		}
	}
	return files, nil
}

// ScanFile inspects a single file's contents for secret patterns.
func ScanFile(absPath, relPath string) ([]Finding, error) {
	data, err := os.ReadFile(absPath)
	if err != nil {
		// If file was deleted or unreadable, ignore
		return nil, nil
	}

	// Skip binary files containing NULL bytes
	if bytes.Contains(data, []byte{0}) {
		return nil, nil
	}

	text := string(data)
	var findings []Finding

	// Check if file is in example/sample/template directory or named as such
	parts := strings.Split(relPath, string(filepath.Separator))
	skipCredentialAssign := false
	for _, part := range parts {
		lower := strings.ToLower(part)
		if lower == "example" || lower == "sample" || lower == "template" {
			skipCredentialAssign = true
			break
		}
	}

	for _, p := range patterns {
		if skipCredentialAssign && p.name == "credential assignment" {
			continue
		}

		if p.name == "credential assignment" {
			matches := p.pattern.FindAllStringSubmatch(text, -1)
			if len(matches) > 0 {
				allPlaceholders := true
				for _, match := range matches {
					if len(match) > 1 {
						val := match[1]
						if !isPlaceholder(val) {
							allPlaceholders = false
							break
						}
					}
				}
				if allPlaceholders {
					continue
				}
			}
		}

		if p.pattern.MatchString(text) {
			findings = append(findings, Finding{
				Path:        relPath,
				PatternName: p.name,
			})
		}
	}

	return findings, nil
}

// ScanRepository scans all tracked git files in rootDir.
// Returns findings, total tracked files checked, and any error.
func ScanRepository(rootDir string) ([]Finding, int, error) {
	files, err := TrackedFiles(rootDir)
	if err != nil {
		return nil, 0, err
	}

	var allFindings []Finding
	for _, relPath := range files {
		absPath := filepath.Join(rootDir, relPath)
		fileFindings, err := ScanFile(absPath, relPath)
		if err != nil {
			return nil, 0, err
		}
		allFindings = append(allFindings, fileFindings...)
	}

	return allFindings, len(files), nil
}
