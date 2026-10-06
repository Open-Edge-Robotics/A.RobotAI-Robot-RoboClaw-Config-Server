package contract_test

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"ai-config-server/internal/contract"
)

// projectRoot returns the absolute path to the repository root.
func projectRoot(t *testing.T) string {
	t.Helper()
	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("failed to get working dir: %v", err)
	}
	// internal/contract -> ../..
	root, err := filepath.Abs(filepath.Join(wd, "..", ".."))
	if err != nil {
		t.Fatalf("failed to resolve root dir: %v", err)
	}
	return root
}

func TestCheckContractLock_RealFiles(t *testing.T) {
	root := projectRoot(t)
	contractsDir := filepath.Join(root, "contracts")

	lock, err := contract.CheckContractLock(contractsDir)
	if err != nil {
		t.Fatalf("CheckContractLock failed: %v", err)
	}
	if lock.Version == "" {
		t.Errorf("expected lock.Version to be non-empty")
	}
	if lock.Name != "rcf-runtime-config" {
		t.Errorf("expected name 'rcf-runtime-config', got %q", lock.Name)
	}
}

func TestCheckContractLock_Mismatch(t *testing.T) {
	tempDir := t.TempDir()
	// Write dummy files with mismatched hash
	lockContent := `{
		"name": "rcf-runtime-config",
		"version": "1.0.0",
		"runtime_contract_sha256": "wronghash",
		"schema_sha256": "wronghash2"
	}`
	if err := os.WriteFile(filepath.Join(tempDir, "contract.lock.json"), []byte(lockContent), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tempDir, "runtime-contract.json"), []byte("{}"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tempDir, "runtime-config.schema.json"), []byte("{}"), 0644); err != nil {
		t.Fatal(err)
	}

	_, err := contract.CheckContractLock(tempDir)
	if err == nil {
		t.Errorf("expected error due to checksum mismatch, got nil")
	}
}

func TestCheckSchemaLock_RealFiles(t *testing.T) {
	root := projectRoot(t)
	schemaFile := filepath.Join(root, "schemas", "robo-claw-runtime-config-v2.schema.json")
	lockFile := filepath.Join(root, "schemas", "schema-lock.json")

	lock, err := contract.CheckSchemaLock(schemaFile, lockFile)
	if err != nil {
		t.Fatalf("CheckSchemaLock failed: %v", err)
	}
	if lock.SchemaVersion == "" {
		t.Errorf("expected SchemaVersion to be non-empty")
	}
}

func TestRenderDartContractRendersObjectDefaultsDeterministically(t *testing.T) {
	input := []byte(`{"contract_version":"2.4.0","schema_version":"2.0","fields":[{"canonical":"system1.thresholds","type":"object","scope":"runtime","env":"SYSTEM1_THRESHOLDS","api_json":"system1_thresholds","default":{"zeta":1,"alpha":0.5,"middle":0.8},"enum":[],"minimum":null,"maximum":null,"secret":false}]}`)

	first, err := contract.RenderDartContract(input)
	if err != nil {
		t.Fatal(err)
	}
	want := []byte("defaultValue: {\n      'alpha': 0.5,\n      'middle': 0.8,\n      'zeta': 1,\n    }")
	if !bytes.Contains(first, want) {
		t.Fatalf("object default keys must render in stable sorted order, got %s", first)
	}
	for i := 0; i < 20; i++ {
		rendered, err := contract.RenderDartContract(input)
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(first, rendered) {
			t.Fatal("Dart contract rendering changed between calls")
		}
	}
}

func TestRenderDartArtifact_MatchesExisting(t *testing.T) {
	root := projectRoot(t)
	contractFile := filepath.Join(root, "contracts", "runtime-contract.json")
	existingDart := filepath.Join(root, "frontend", "lib", "models", "runtime_config_contract.g.dart")

	contractData, err := os.ReadFile(contractFile)
	if err != nil {
		t.Fatalf("failed to read contract file: %v", err)
	}

	rendered, err := contract.RenderDartContract(contractData)
	if err != nil {
		t.Fatalf("RenderDartContract failed: %v", err)
	}

	existingBytes, err := os.ReadFile(existingDart)
	if err != nil {
		t.Fatalf("failed to read existing dart file: %v", err)
	}

	if string(rendered) != string(existingBytes) {
		t.Errorf("rendered Dart content does not match existing file %s", existingDart)
	}
}

func TestUpdateContract_Success(t *testing.T) {
	bundleDir := t.TempDir()
	targetDir := t.TempDir()

	manifest := map[string]any{
		"contract_version": "3.1.2",
	}
	manifestBytes, _ := json.Marshal(manifest)
	if err := os.WriteFile(filepath.Join(bundleDir, "contract-manifest.json"), manifestBytes, 0644); err != nil {
		t.Fatal(err)
	}
	contractBytes := []byte(`{"fields": []}`)
	if err := os.WriteFile(filepath.Join(bundleDir, "runtime-contract.json"), contractBytes, 0644); err != nil {
		t.Fatal(err)
	}
	schemaBytes := []byte(`{"$schema": "test"}`)
	if err := os.WriteFile(filepath.Join(bundleDir, "runtime-config.schema.json"), schemaBytes, 0644); err != nil {
		t.Fatal(err)
	}

	version, err := contract.UpdateContract(bundleDir, targetDir)
	if err != nil {
		t.Fatalf("UpdateContract failed: %v", err)
	}
	if version != "3.1.2" {
		t.Errorf("expected version 3.1.2, got %s", version)
	}

	// Verify targetDir can pass CheckContractLock
	lock, err := contract.CheckContractLock(targetDir)
	if err != nil {
		t.Fatalf("CheckContractLock on updated target failed: %v", err)
	}
	if lock.Version != "3.1.2" {
		t.Errorf("expected lock.Version to be 3.1.2, got %s", lock.Version)
	}
	if lock.SupportedRange != ">=3.1.2,<4.0.0" {
		t.Errorf("expected supported_range '>=3.1.2,<4.0.0', got %s", lock.SupportedRange)
	}
}
