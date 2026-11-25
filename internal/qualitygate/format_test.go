package qualitygate

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

func TestFormatGateRejectsUnformattedGo(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("the repository Taskfile requires a POSIX shell")
	}
	taskPath, err := exec.LookPath("task")
	if err != nil {
		t.Skip("task is not installed")
	}
	if _, err := exec.LookPath("gofmt"); err != nil {
		t.Fatal(err)
	}
	_, source, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("cannot locate repository Taskfile")
	}
	taskfile, err := os.ReadFile(filepath.Join(filepath.Dir(source), "..", "..", "Taskfile.yml"))
	if err != nil {
		t.Fatal(err)
	}

	for _, tc := range []struct {
		name, path, content string
		wantFailure         bool
	}{
		{"formatted", "main.go", "package main\n\nfunc main() {}\n", false},
		{"main", "main.go", "package main\nfunc main(){ }\n", true},
		{"testutil", "testutil/fixture.go", "package testutil\nfunc fixture(){ }\n", true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			for _, subdir := range []string{"cmd", "config", "contracts", "database", "handler", "internal", "service", "testutil", "frontend", "bin"} {
				if err := os.Mkdir(filepath.Join(dir, subdir), 0o700); err != nil {
					t.Fatal(err)
				}
			}
			writeFixture(t, filepath.Join(dir, "Taskfile.yml"), taskfile, 0o600)
			writeFixture(t, filepath.Join(dir, "main.go"), []byte("package main\n\nfunc main() {}\n"), 0o600)
			writeFixture(t, filepath.Join(dir, tc.path), []byte(tc.content), 0o600)
			// The fixture isolates the Go gate; Dart formatting is checked separately.
			writeFixture(t, filepath.Join(dir, "bin", "dart"), []byte("#!/bin/sh\nexit 0\n"), 0o700)
			ctx, cancel := context.WithTimeout(t.Context(), 15*time.Second)
			defer cancel()
			cmd := exec.CommandContext(ctx, taskPath, "fmt-check")
			cmd.Dir = dir
			cmd.Env = append(os.Environ(), "PATH="+filepath.Join(dir, "bin")+string(os.PathListSeparator)+os.Getenv("PATH"))
			output, err := cmd.CombinedOutput()
			if ctx.Err() != nil {
				t.Fatalf("format check timed out: %v", ctx.Err())
			}
			if (err != nil) != tc.wantFailure {
				t.Fatalf("unexpected format gate result: err=%v, output=%s", err, output)
			}
			if tc.wantFailure && !strings.Contains(string(output), tc.path) {
				t.Fatalf("format gate did not identify the offending file: %s", output)
			}
		})
	}
}

func TestBackendCoverageGate(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("the repository Taskfile requires a POSIX shell")
	}
	taskPath, err := exec.LookPath("task")
	if err != nil {
		t.Skip("task is not installed")
	}
	_, source, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("cannot locate repository Taskfile")
	}
	taskfile, err := os.ReadFile(filepath.Join(filepath.Dir(source), "..", "..", "Taskfile.yml"))
	if err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct {
		name, report string
		wantFailure  bool
	}{
		{"threshold", "total: (statements) 80.0%", false},
		{"below_threshold", "total: (statements) 79.9%", true},
		{"missing_total", "", true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			bin := filepath.Join(dir, "bin")
			if err := os.Mkdir(bin, 0o700); err != nil {
				t.Fatal(err)
			}
			writeFixture(t, filepath.Join(dir, "Taskfile.yml"), taskfile, 0o600)
			writeFixture(t, filepath.Join(bin, "go"), []byte("#!/bin/sh\ncase \"$1 $2\" in\n  'test ./...') exit 0 ;;\n  'tool cover') printf '%s\\n' \"$AICS_FIXTURE_REPORT\" ;;\n  *) exit 2 ;;\nesac\n"), 0o700)
			ctx, cancel := context.WithTimeout(t.Context(), 15*time.Second)
			defer cancel()
			cmd := exec.CommandContext(ctx, taskPath, "test:coverage")
			cmd.Dir = dir
			cmd.Env = append(os.Environ(), "PATH="+bin+string(os.PathListSeparator)+os.Getenv("PATH"), "AICS_FIXTURE_REPORT="+tc.report)
			output, err := cmd.CombinedOutput()
			if ctx.Err() != nil {
				t.Fatalf("coverage gate timed out: %v", ctx.Err())
			}
			if (err != nil) != tc.wantFailure {
				t.Fatalf("unexpected coverage gate result: err=%v, output=%s", err, output)
			}
		})
	}
}

func writeFixture(t *testing.T, path string, content []byte, mode os.FileMode) {
	t.Helper()
	if err := os.WriteFile(path, content, mode); err != nil {
		t.Fatal(err)
	}
}
