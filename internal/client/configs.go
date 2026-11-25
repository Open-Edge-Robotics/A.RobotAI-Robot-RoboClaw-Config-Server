package client

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
)

// Config represents a RoboClawConfig JSON document without dropping unknown fields.
type Config map[string]any

// ID returns the numeric record ID (GORM marshals ID as "ID").
func (cfg Config) ID() int {
	for _, k := range []string{"ID", "id"} {
		if v, ok := cfg[k]; ok {
			switch n := v.(type) {
			case float64:
				return int(n)
			case int:
				return n
			case int64:
				return int(n)
			}
		}
	}
	return 0
}

func (cfg Config) StringField(key string) string {
	if v, ok := cfg[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

func (cfg Config) BoolField(key string) bool {
	if v, ok := cfg[key]; ok {
		if b, ok := v.(bool); ok {
			return b
		}
	}
	return false
}

func (cfg Config) Name() string        { return cfg.StringField("name") }
func (cfg Config) RobotName() string   { return cfg.StringField("robot_name") }
func (cfg Config) Environment() string { return cfg.StringField("environment") }
func (cfg Config) IsActive() bool      { return cfg.BoolField("is_active") }

// ListConfigs calls GET /api/v1/admin/configs.
func (c *Client) ListConfigs(ctx context.Context, robotName, environment string) ([]Config, error) {
	q := url.Values{}
	if robotName != "" {
		q.Set("robot_name", robotName)
	}
	if environment != "" {
		q.Set("environment", environment)
	}
	var out []Config
	if err := c.doJSON(ctx, http.MethodGet, "/api/v1/admin/configs", q, nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// GetConfig calls GET /api/v1/admin/configs/:id.
func (c *Client) GetConfig(ctx context.Context, id int) (Config, error) {
	var out Config
	if err := c.doJSON(ctx, http.MethodGet, fmt.Sprintf("/api/v1/admin/configs/%d", id), nil, nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// CreateConfig calls POST /api/v1/admin/configs.
func (c *Client) CreateConfig(ctx context.Context, payload map[string]any) (Config, error) {
	var out Config
	if err := c.doJSON(ctx, http.MethodPost, "/api/v1/admin/configs", nil, payload, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// PatchConfig calls PATCH /api/v1/admin/configs/:id.
func (c *Client) PatchConfig(ctx context.Context, id int, patch map[string]any) (Config, error) {
	var out Config
	if err := c.doJSON(ctx, http.MethodPatch, fmt.Sprintf("/api/v1/admin/configs/%d", id), nil, patch, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// DeleteConfig calls DELETE /api/v1/admin/configs/:id.
func (c *Client) DeleteConfig(ctx context.Context, id int) (map[string]any, error) {
	var out map[string]any
	if err := c.doJSON(ctx, http.MethodDelete, fmt.Sprintf("/api/v1/admin/configs/%d", id), nil, nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// ActivateConfig calls POST /api/v1/admin/configs/:id/activate.
func (c *Client) ActivateConfig(ctx context.Context, id int) (map[string]any, error) {
	var out map[string]any
	if err := c.doJSON(ctx, http.MethodPost, fmt.Sprintf("/api/v1/admin/configs/%d/activate", id), nil, nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// CloneConfig calls POST /api/v1/admin/configs/:id/clone.
func (c *Client) CloneConfig(ctx context.Context, id int) (Config, error) {
	var out Config
	if err := c.doJSON(ctx, http.MethodPost, fmt.Sprintf("/api/v1/admin/configs/%d/clone", id), nil, nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// GetConfigFile calls GET /api/v1/admin/configs/:id/files/:filename.
func (c *Client) GetConfigFile(ctx context.Context, id int, filename string) ([]byte, error) {
	endpoint := fmt.Sprintf("/api/v1/admin/configs/%d/files/%s", id, url.PathEscape(filename))
	data, _, err := c.doRaw(ctx, http.MethodGet, endpoint, nil, nil)
	return data, err
}

// ListDeviceConfigs calls GET /api/v1/configs (Device Token or Admin Token).
func (c *Client) ListDeviceConfigs(ctx context.Context, robotName, environment string) ([]Config, error) {
	q := url.Values{}
	if robotName != "" {
		q.Set("robot_name", robotName)
	}
	if environment != "" {
		q.Set("environment", environment)
	}
	var out []Config
	if err := c.doJSON(ctx, http.MethodGet, "/api/v1/configs", q, nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// GetActiveConfig calls GET /api/v1/configs/active.
func (c *Client) GetActiveConfig(ctx context.Context, robotName, environment string) (Config, error) {
	q := url.Values{}
	q.Set("robot_name", robotName)
	q.Set("environment", environment)
	var out Config
	if err := c.doJSON(ctx, http.MethodGet, "/api/v1/configs/active", q, nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// GetActiveConfigFile calls GET /api/v1/configs/active/files/:filename.
func (c *Client) GetActiveConfigFile(ctx context.Context, robotName, environment, filename string) ([]byte, error) {
	q := url.Values{}
	q.Set("robot_name", robotName)
	q.Set("environment", environment)
	endpoint := fmt.Sprintf("/api/v1/configs/active/files/%s", url.PathEscape(filename))
	data, _, err := c.doRaw(ctx, http.MethodGet, endpoint, q, nil)
	return data, err
}

// GetActiveRuntimeConfigV2 calls GET /api/v2/device/runtime-config.
func (c *Client) GetActiveRuntimeConfigV2(ctx context.Context, robotName, environment string) (map[string]any, error) {
	q := url.Values{}
	q.Set("robot_name", robotName)
	q.Set("environment", environment)
	var out map[string]any
	if err := c.doJSON(ctx, http.MethodGet, "/api/v2/device/runtime-config", q, nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}
