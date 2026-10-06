package contract

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// UpdateContract updates the vendored contract from a downloaded release bundle.
// It verifies the required files in sourceDir, generates contract.lock.json with updated checksums,
// and copies the files into targetDir. Returns the contract version.
func UpdateContract(sourceDir, targetDir string) (string, error) {
	required := []string{"runtime-contract.json", "runtime-config.schema.json", "contract-manifest.json"}
	var missing []string
	for _, name := range required {
		path := filepath.Join(sourceDir, name)
		if fi, err := os.Stat(path); err != nil || fi.IsDir() {
			missing = append(missing, name)
		}
	}
	if len(missing) > 0 {
		return "", fmt.Errorf("contract bundle missing: %s", strings.Join(missing, ", "))
	}

	manifestBytes, err := os.ReadFile(filepath.Join(sourceDir, "contract-manifest.json"))
	if err != nil {
		return "", fmt.Errorf("failed to read contract-manifest.json: %w", err)
	}

	var manifest ContractManifest
	if err := json.Unmarshal(manifestBytes, &manifest); err != nil {
		return "", fmt.Errorf("failed to parse contract-manifest.json: %w", err)
	}
	version := strings.TrimSpace(manifest.ContractVersion)
	if version == "" {
		return "", fmt.Errorf("contract manifest missing contract_version")
	}

	contractBytes, err := os.ReadFile(filepath.Join(sourceDir, "runtime-contract.json"))
	if err != nil {
		return "", fmt.Errorf("failed to read runtime-contract.json: %w", err)
	}
	schemaBytes, err := os.ReadFile(filepath.Join(sourceDir, "runtime-config.schema.json"))
	if err != nil {
		return "", fmt.Errorf("failed to read runtime-config.schema.json: %w", err)
	}

	contractHash := sha256.Sum256(contractBytes)
	contractSHA256 := hex.EncodeToString(contractHash[:])

	schemaHash := sha256.Sum256(schemaBytes)
	schemaSHA256 := hex.EncodeToString(schemaHash[:])

	// Calculate supported_range, e.g. "2.0.1" -> ">=2.0.1,<3.0.0"
	parts := strings.Split(version, ".")
	major, err := strconv.Atoi(parts[0])
	if err != nil {
		return "", fmt.Errorf("invalid semantic version %q: %w", version, err)
	}
	supportedRange := fmt.Sprintf(">=%s,<%d.0.0", version, major+1)

	lock := ContractLock{
		Name:                  "rcf-runtime-config",
		Version:               version,
		Source:                fmt.Sprintf("gitlab-release://rcf-config-contract/v%s", version),
		RuntimeContractSHA256: contractSHA256,
		SchemaSHA256:          schemaSHA256,
		SupportedRange:        supportedRange,
	}

	lockBytes, err := json.MarshalIndent(lock, "", "  ")
	if err != nil {
		return "", fmt.Errorf("failed to marshal contract.lock.json: %w", err)
	}
	lockBytes = append(lockBytes, '\n')

	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create target dir %s: %w", targetDir, err)
	}

	if err := os.WriteFile(filepath.Join(targetDir, "runtime-contract.json"), contractBytes, 0644); err != nil {
		return "", fmt.Errorf("failed to write runtime-contract.json: %w", err)
	}
	if err := os.WriteFile(filepath.Join(targetDir, "runtime-config.schema.json"), schemaBytes, 0644); err != nil {
		return "", fmt.Errorf("failed to write runtime-config.schema.json: %w", err)
	}
	if err := os.WriteFile(filepath.Join(targetDir, "contract.lock.json"), lockBytes, 0644); err != nil {
		return "", fmt.Errorf("failed to write contract.lock.json: %w", err)
	}

	return version, nil
}
