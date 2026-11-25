package clioutput

import (
	"encoding/json"
	"fmt"
	"strings"

	"ai-config-server/contracts"
)

// ContractField mirrors an entry in contracts/runtime-contract.json.
type ContractField struct {
	Canonical   string   `json:"canonical"`
	Type        string   `json:"type"`
	Scope       string   `json:"scope"`
	Default     any      `json:"default"`
	Secret      bool     `json:"secret"`
	Description string   `json:"description"`
	Enum        []string `json:"enum"`
	Minimum     *float64 `json:"minimum"`
	Maximum     *float64 `json:"maximum"`
	Env         string   `json:"env"`
	APIJSON     string   `json:"api_json"`
}

// ContractSchema represents the embedded runtime contract.
type ContractSchema struct {
	ContractVersion string          `json:"contract_version"`
	SchemaVersion   string          `json:"schema_version"`
	Fields          []ContractField `json:"fields"`
}

// LoadContractSchema parses the embedded runtime-contract.json.
func LoadContractSchema() (*ContractSchema, error) {
	var s ContractSchema
	if err := json.Unmarshal(contracts.RuntimeContractJSON, &s); err != nil {
		return nil, fmt.Errorf("내장 runtime contract 파싱 실패: %w", err)
	}
	return &s, nil
}

// SecretEnvKeys returns the set of env variable names marked secret in the contract.
func (s *ContractSchema) SecretEnvKeys() map[string]bool {
	out := make(map[string]bool)
	if s == nil {
		return out
	}
	for _, f := range s.Fields {
		if f.Secret && f.Env != "" {
			out[f.Env] = true
		}
	}
	return out
}

// FieldTypes returns a map of api_json field name to JSON schema type.
func (s *ContractSchema) FieldTypes() map[string]string {
	out := map[string]string{
		"name":                    "string",
		"robot_name":              "string",
		"environment":             "string",
		"description":             "string",
		"is_active":               "boolean",
		"soul_content":            "string",
		"skills_content":          "string",
		"troubleshooting_content": "string",
		"limits_content":          "string",
	}
	if s == nil {
		return out
	}
	for _, f := range s.Fields {
		if f.APIJSON != "" && f.Type != "" {
			out[f.APIJSON] = f.Type
		}
	}
	return out
}

// FilterFields filters contract fields by optional substring query and scope/secret flags.
func (s *ContractSchema) FilterFields(query, scope string, secretsOnly bool) []ContractField {
	if s == nil {
		return nil
	}
	q := strings.ToLower(strings.TrimSpace(query))
	sc := strings.ToLower(strings.TrimSpace(scope))
	out := make([]ContractField, 0, len(s.Fields))
	for _, f := range s.Fields {
		if secretsOnly && !f.Secret {
			continue
		}
		if sc != "" && strings.ToLower(f.Scope) != sc {
			continue
		}
		if q != "" {
			hay := strings.ToLower(f.Canonical + " " + f.APIJSON + " " + f.Env + " " + f.Description)
			if !strings.Contains(hay, q) {
				continue
			}
		}
		out = append(out, f)
	}
	return out
}
