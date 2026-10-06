package contract

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// CheckContractLock validates the checksums of runtime-contract.json and
// runtime-config.schema.json against contract.lock.json in contractsDir.
func CheckContractLock(contractsDir string) (*ContractLock, error) {
	lockPath := filepath.Join(contractsDir, "contract.lock.json")
	lockData, err := os.ReadFile(lockPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read %s: %w", lockPath, err)
	}

	var lock ContractLock
	if err := json.Unmarshal(lockData, &lock); err != nil {
		return nil, fmt.Errorf("failed to parse %s: %w", lockPath, err)
	}

	checks := map[string]string{
		"runtime-contract.json":      lock.RuntimeContractSHA256,
		"runtime-config.schema.json": lock.SchemaSHA256,
	}

	for filename, expected := range checks {
		filePath := filepath.Join(contractsDir, filename)
		digest, err := HashFileSHA256(filePath)
		if err != nil {
			return nil, fmt.Errorf("failed to hash %s: %w", filePath, err)
		}
		if digest != expected {
			return nil, fmt.Errorf("contract checksum mismatch for %s: expected %s, got %s", filename, expected, digest)
		}
	}

	return &lock, nil
}

// CheckSchemaLock validates that schemaFile matches the sha256 in lockFile.
func CheckSchemaLock(schemaFile, lockFile string) (*SchemaLock, error) {
	lockData, err := os.ReadFile(lockFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read %s: %w", lockFile, err)
	}

	var lock SchemaLock
	if err := json.Unmarshal(lockData, &lock); err != nil {
		return nil, fmt.Errorf("failed to parse %s: %w", lockFile, err)
	}

	digest, err := HashFileSHA256(schemaFile)
	if err != nil {
		return nil, fmt.Errorf("failed to hash %s: %w", schemaFile, err)
	}

	if digest != lock.SHA256 {
		return nil, fmt.Errorf("schema checksum mismatch: expected %s, got %s", lock.SHA256, digest)
	}

	return &lock, nil
}

// HashFileSHA256 returns the lowercase hex-encoded sha256 checksum of the file.
func HashFileSHA256(filePath string) (string, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return "", err
	}
	h := sha256.Sum256(data)
	return hex.EncodeToString(h[:]), nil
}
