package cmd_test

import (
	"bytes"
	"strings"
	"testing"

	"ai-config-server/cmd"
)

func TestContractCmd_Help(t *testing.T) {
	c := cmd.ContractCmd()
	if c.Use != "contract" {
		t.Errorf("expected Use 'contract', got %q", c.Use)
	}
}

func TestContractCmd_CheckSubcommand(t *testing.T) {
	c := cmd.ContractCmd()
	var buf bytes.Buffer
	c.OutWriter = &buf

	// Execute check subcommand directly
	err := c.Execute([]string{"check"})
	if err != nil {
		t.Fatalf("expected contract check to succeed, got %v", err)
	}
}

func TestContractCmd_GenerateCheck(t *testing.T) {
	c := cmd.ContractCmd()
	var buf bytes.Buffer
	c.OutWriter = &buf

	err := c.Execute([]string{"generate", "--check"})
	if err != nil {
		t.Fatalf("expected contract generate --check to succeed, got %v", err)
	}
}

func TestSecretScanCmd_Execute(t *testing.T) {
	c := cmd.SecretScanCmd()
	var buf bytes.Buffer
	c.OutWriter = &buf

	err := c.Execute([]string{})
	if err != nil {
		t.Fatalf("expected secret-scan to succeed on clean repo, got %v", err)
	}
}

func TestContractCmd_UpdateHelpDefaultProject(t *testing.T) {
	c := cmd.ContractCmd()
	var buf bytes.Buffer
	c.OutWriter = &buf
	c.ErrWriter = &buf

	err := c.Execute([]string{"update", "--help"})
	if err != nil {
		t.Fatalf("unexpected error running update --help: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, "(default: wkqco33/rcf-config-contract)") {
		t.Fatalf("expected update --help to include default project, got: %s", out)
	}
}

func TestContractCmd_UpdateRequiresFlags(t *testing.T) {
	c := cmd.ContractCmd()
	var buf bytes.Buffer
	c.OutWriter = &buf
	c.ErrWriter = &buf

	err := c.Execute([]string{"update"})
	if err == nil || !strings.Contains(err.Error(), "--from 또는 --version 플래그 중 하나를 지정해야 합니다") {
		t.Fatalf("expected missing flags error, got: %v", err)
	}
}
