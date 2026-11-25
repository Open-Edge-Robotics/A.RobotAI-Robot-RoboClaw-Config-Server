package client

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
)

// ExportRequest mirrors handler.ExportRequest.
type ExportRequest struct {
	IncludeSecrets   bool `json:"include_secrets"`
	IncludeConfigs   bool `json:"include_configs"`
	IncludeScenarios bool `json:"include_scenarios"`
}

// ImportOptions mirrors handler.ImportOptions.
type ImportOptions struct {
	ConflictPolicy   string `json:"conflict_policy"`
	ActivationPolicy string `json:"activation_policy"`
}

// ImportRequest sends a raw backup document JSON together with import options.
type ImportRequest struct {
	Document json.RawMessage `json:"document"`
	Options  ImportOptions   `json:"options"`
}

// McpCatalogEntry mirrors handler.McpCatalogEntry.
type McpCatalogEntry struct {
	Name        string            `json:"name"`
	DisplayName string            `json:"display_name"`
	Description string            `json:"description"`
	Category    string            `json:"category"`
	Transport   string            `json:"transport"`
	Command     string            `json:"command,omitempty"`
	Args        []string          `json:"args,omitempty"`
	Env         map[string]string `json:"env,omitempty"`
	URL         string            `json:"url,omitempty"`
	Homepage    string            `json:"homepage,omitempty"`
	Source      string            `json:"source"`
}

// McpCatalogResponse mirrors handler.mcpCatalogResponse.
type McpCatalogResponse struct {
	Source  string            `json:"source"`
	Servers []McpCatalogEntry `json:"servers"`
}

// ExportBackup calls POST /api/v1/admin/transfer/export and returns raw JSON bytes.
func (c *Client) ExportBackup(ctx context.Context, req ExportRequest) ([]byte, error) {
	data, _, err := c.doRaw(ctx, http.MethodPost, "/api/v1/admin/transfer/export", nil, req)
	return data, err
}

// ValidateImport calls POST /api/v1/admin/transfer/import/validate.
func (c *Client) ValidateImport(ctx context.Context, req ImportRequest) (map[string]any, error) {
	var out map[string]any
	if err := c.doJSON(ctx, http.MethodPost, "/api/v1/admin/transfer/import/validate", nil, req, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// ImportBackup calls POST /api/v1/admin/transfer/import.
func (c *Client) ImportBackup(ctx context.Context, req ImportRequest) (map[string]any, error) {
	var out map[string]any
	if err := c.doJSON(ctx, http.MethodPost, "/api/v1/admin/transfer/import", nil, req, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// ListMcpCatalog calls GET /api/v1/admin/mcp/catalog.
func (c *Client) ListMcpCatalog(ctx context.Context, query string) (McpCatalogResponse, error) {
	q := url.Values{}
	if query != "" {
		q.Set("q", query)
	}
	var out McpCatalogResponse
	if err := c.doJSON(ctx, http.MethodGet, "/api/v1/admin/mcp/catalog", q, nil, &out); err != nil {
		return McpCatalogResponse{}, err
	}
	return out, nil
}
