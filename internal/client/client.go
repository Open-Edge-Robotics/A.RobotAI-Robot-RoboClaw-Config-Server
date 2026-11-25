package client

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	// ExitOK indicates success.
	ExitOK = 0
	// ExitError indicates a general or 5xx server failure.
	ExitError = 1
	// ExitUsage indicates invalid user input or 400/422 validation failure.
	ExitUsage = 2
	// ExitAuth indicates 401/403 authentication or authorization failure.
	ExitAuth = 3
	// ExitNotFound indicates a 404 resource-not-found failure.
	ExitNotFound = 4
	// ExitConflict indicates a 409 conflict or rate-limit/timeout failure.
	ExitConflict = 5
)

// APIError represents an HTTP error returned by ai-config-server.
type APIError struct {
	StatusCode int
	Method     string
	Path       string
	ErrText    string
	Details    string
}

func (e *APIError) Error() string {
	msg := e.Details
	if msg == "" {
		msg = e.ErrText
	}
	if msg == "" {
		msg = http.StatusText(e.StatusCode)
	}
	return fmt.Sprintf("HTTP %d (%s %s): %s", e.StatusCode, e.Method, e.Path, msg)
}

// ExitCode maps the HTTP status code to a deterministic CLI exit code.
func (e *APIError) ExitCode() int {
	switch e.StatusCode {
	case http.StatusBadRequest, http.StatusUnprocessableEntity:
		return ExitUsage
	case http.StatusUnauthorized, http.StatusForbidden:
		return ExitAuth
	case http.StatusNotFound:
		return ExitNotFound
	case http.StatusConflict, http.StatusTooManyRequests:
		return ExitConflict
	default:
		return ExitError
	}
}

// CodeError wraps an arbitrary error with an explicit CLI exit code.
type CodeError struct {
	Code int
	Err  error
}

func (e *CodeError) Error() string { return e.Err.Error() }
func (e *CodeError) Unwrap() error { return e.Err }

// ExitCodeFromError extracts the CLI exit code from err.
func ExitCodeFromError(err error) int {
	if err == nil {
		return ExitOK
	}
	var ce *CodeError
	if errors.As(err, &ce) && ce.Code != 0 {
		return ce.Code
	}
	var ae *APIError
	if errors.As(err, &ae) {
		return ae.ExitCode()
	}
	return ExitError
}

// Client talks to a remote ai-config-server over HTTP.
type Client struct {
	BaseURL    string
	Token      string
	HTTPClient *http.Client
}

// New constructs a Client with sane timeout defaults.
func New(baseURL, token string, timeout time.Duration) *Client {
	if timeout <= 0 {
		timeout = 30 * time.Second
	}
	return &Client{
		BaseURL: strings.TrimRight(strings.TrimSpace(baseURL), "/"),
		Token:   strings.TrimSpace(token),
		HTTPClient: &http.Client{
			Timeout: timeout,
		},
	}
}

func (c *Client) buildURL(endpoint string, query url.Values) string {
	u := c.BaseURL + endpoint
	if len(query) > 0 {
		u += "?" + query.Encode()
	}
	return u
}

func (c *Client) doRaw(ctx context.Context, method, endpoint string, query url.Values, body any) ([]byte, http.Header, error) {
	var bodyReader io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return nil, nil, fmt.Errorf("요청 JSON 직렬화 실패: %w", err)
		}
		bodyReader = bytes.NewReader(b)
	}

	req, err := http.NewRequestWithContext(ctx, method, c.buildURL(endpoint, query), bodyReader)
	if err != nil {
		return nil, nil, fmt.Errorf("HTTP 요청 생성 실패: %w", err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	req.Header.Set("Accept", "application/json, text/plain, */*")
	if c.Token != "" {
		req.Header.Set("Authorization", "Bearer "+c.Token)
	}

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, nil, fmt.Errorf("서버 요청 실패 (%s %s): %w", method, endpoint, err)
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, resp.Header, fmt.Errorf("응답 본문 읽기 실패 (%s %s): %w", method, endpoint, err)
	}

	if resp.StatusCode >= 400 {
		apiErr := &APIError{
			StatusCode: resp.StatusCode,
			Method:     method,
			Path:       endpoint,
		}
		var parsed struct {
			Error   string `json:"error"`
			Details string `json:"details"`
		}
		if json.Unmarshal(respBytes, &parsed) == nil {
			apiErr.ErrText = parsed.Error
			apiErr.Details = parsed.Details
		} else {
			apiErr.Details = strings.TrimSpace(string(respBytes))
		}
		return nil, resp.Header, apiErr
	}

	return respBytes, resp.Header, nil
}

func (c *Client) doJSON(ctx context.Context, method, endpoint string, query url.Values, body any, out any) error {
	respBytes, _, err := c.doRaw(ctx, method, endpoint, query, body)
	if err != nil {
		return err
	}
	if out == nil || len(respBytes) == 0 {
		return nil
	}
	if err := json.Unmarshal(respBytes, out); err != nil {
		return fmt.Errorf("응답 JSON 파싱 실패 (%s %s): %w", method, endpoint, err)
	}
	return nil
}

// Ping checks GET /ping.
func (c *Client) Ping(ctx context.Context) (map[string]any, error) {
	var out map[string]any
	err := c.doJSON(ctx, http.MethodGet, "/ping", nil, nil, &out)
	return out, err
}

// Ready checks GET /ready.
func (c *Client) Ready(ctx context.Context) (map[string]any, error) {
	var out map[string]any
	err := c.doJSON(ctx, http.MethodGet, "/ready", nil, nil, &out)
	return out, err
}
