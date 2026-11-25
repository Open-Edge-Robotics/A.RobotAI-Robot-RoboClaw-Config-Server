package client

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
)

// TestCase mirrors models.TestCase for pure-Go CLI builds.
type TestCase struct {
	ID        string         `json:"id"`
	Name      string         `json:"name"`
	Step      string         `json:"step"`
	Type      string         `json:"type"`
	TimeoutMs int            `json:"timeout_ms"`
	Enabled   bool           `json:"enabled"`
	Params    map[string]any `json:"params,omitempty"`
}

// Scenario mirrors models.TestScenario for pure-Go CLI builds.
type Scenario struct {
	ID          uint       `json:"ID"`
	Name        string     `json:"name"`
	Description string     `json:"description"`
	RobotName   string     `json:"robot_name"`
	Environment string     `json:"environment"`
	IsActive    bool       `json:"is_active"`
	TestCases   []TestCase `json:"test_cases"`
}

// ListScenarios calls GET /api/v1/admin/scenarios.
func (c *Client) ListScenarios(ctx context.Context, robotName, environment string) ([]Scenario, error) {
	q := url.Values{}
	if robotName != "" {
		q.Set("robot_name", robotName)
	}
	if environment != "" {
		q.Set("environment", environment)
	}
	var out []Scenario
	if err := c.doJSON(ctx, http.MethodGet, "/api/v1/admin/scenarios", q, nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// GetScenario calls GET /api/v1/admin/scenarios/:id.
func (c *Client) GetScenario(ctx context.Context, id int) (Scenario, error) {
	var out Scenario
	if err := c.doJSON(ctx, http.MethodGet, fmt.Sprintf("/api/v1/admin/scenarios/%d", id), nil, nil, &out); err != nil {
		return Scenario{}, err
	}
	return out, nil
}

// CreateScenario calls POST /api/v1/admin/scenarios.
func (c *Client) CreateScenario(ctx context.Context, payload map[string]any) (Scenario, error) {
	var out Scenario
	if err := c.doJSON(ctx, http.MethodPost, "/api/v1/admin/scenarios", nil, payload, &out); err != nil {
		return Scenario{}, err
	}
	return out, nil
}

// UpdateScenario calls PUT /api/v1/admin/scenarios/:id.
func (c *Client) UpdateScenario(ctx context.Context, id int, payload map[string]any) (Scenario, error) {
	var out Scenario
	if err := c.doJSON(ctx, http.MethodPut, fmt.Sprintf("/api/v1/admin/scenarios/%d", id), nil, payload, &out); err != nil {
		return Scenario{}, err
	}
	return out, nil
}

// PatchScenario calls PATCH /api/v1/admin/scenarios/:id.
func (c *Client) PatchScenario(ctx context.Context, id int, patch map[string]any) (Scenario, error) {
	var out Scenario
	if err := c.doJSON(ctx, http.MethodPatch, fmt.Sprintf("/api/v1/admin/scenarios/%d", id), nil, patch, &out); err != nil {
		return Scenario{}, err
	}
	return out, nil
}

// DeleteScenario calls DELETE /api/v1/admin/scenarios/:id.
func (c *Client) DeleteScenario(ctx context.Context, id int) (map[string]any, error) {
	var out map[string]any
	if err := c.doJSON(ctx, http.MethodDelete, fmt.Sprintf("/api/v1/admin/scenarios/%d", id), nil, nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// ActivateScenario calls POST /api/v1/admin/scenarios/:id/activate.
func (c *Client) ActivateScenario(ctx context.Context, id int) (map[string]any, error) {
	var out map[string]any
	if err := c.doJSON(ctx, http.MethodPost, fmt.Sprintf("/api/v1/admin/scenarios/%d/activate", id), nil, nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// CloneScenario calls POST /api/v1/admin/scenarios/:id/clone.
func (c *Client) CloneScenario(ctx context.Context, id int) (Scenario, error) {
	var out Scenario
	if err := c.doJSON(ctx, http.MethodPost, fmt.Sprintf("/api/v1/admin/scenarios/%d/clone", id), nil, nil, &out); err != nil {
		return Scenario{}, err
	}
	return out, nil
}

// GetActiveScenario calls GET /api/v1/scenarios/active.
func (c *Client) GetActiveScenario(ctx context.Context, robotName, environment string) (Scenario, error) {
	q := url.Values{}
	q.Set("robot_name", robotName)
	q.Set("environment", environment)
	var out Scenario
	if err := c.doJSON(ctx, http.MethodGet, "/api/v1/scenarios/active", q, nil, &out); err != nil {
		return Scenario{}, err
	}
	return out, nil
}
