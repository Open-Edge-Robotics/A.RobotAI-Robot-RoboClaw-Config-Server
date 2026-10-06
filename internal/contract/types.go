package contract

import "encoding/json"

// ContractLock mirrors contracts/contract.lock.json.
type ContractLock struct {
	Name                  string `json:"name"`
	Version               string `json:"version"`
	Source                string `json:"source"`
	RuntimeContractSHA256 string `json:"runtime_contract_sha256"`
	SchemaSHA256          string `json:"schema_sha256"`
	SupportedRange        string `json:"supported_range"`
}

// SchemaLock mirrors schemas/schema-lock.json.
type SchemaLock struct {
	SchemaVersion string `json:"schema_version"`
	Source        string `json:"source"`
	SHA256        string `json:"sha256"`
}

// ContractManifest mirrors contract-manifest.json in release bundles.
type ContractManifest struct {
	ContractVersion string `json:"contract_version"`
}

// RuntimeContract represents contracts/runtime-contract.json.
type RuntimeContract struct {
	ContractVersion string          `json:"contract_version"`
	SchemaVersion   string          `json:"schema_version"`
	Fields          []ContractField `json:"fields"`
}

// ContractField represents an individual field definition in RuntimeContract.
type ContractField struct {
	Canonical      string      `json:"canonical"`
	Type           string      `json:"type"`
	Scope          string      `json:"scope"`
	Env            string      `json:"env"`
	APIJson        string      `json:"api_json"`
	LaunchArgument string      `json:"launch_argument"`
	ROSParameter   string      `json:"ros_parameter"`
	Secret         bool        `json:"secret"`
	Default        any         `json:"default"`
	Enum           []any       `json:"enum"`
	Minimum        json.Number `json:"minimum"`
	Maximum        json.Number `json:"maximum"`
}
