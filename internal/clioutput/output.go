package clioutput

import (
	"encoding/json"
	"fmt"
	"io"
	"reflect"
	"sort"
	"strconv"
	"strings"
	"text/tabwriter"
)

// MaskValue replaces sensitive values in masked CLI output.
const MaskValue = "********"

// WriteJSON formats v as indented JSON to w.
func WriteJSON(w io.Writer, v any) error {
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	return enc.Encode(v)
}

// WriteTable renders a tab-aligned table to w.
func WriteTable(w io.Writer, headers []string, rows [][]string) error {
	tw := tabwriter.NewWriter(w, 0, 2, 2, ' ', 0)
	if len(headers) > 0 {
		if _, err := fmt.Fprintln(tw, strings.Join(headers, "\t")); err != nil {
			return err
		}
	}
	for _, row := range rows {
		if _, err := fmt.Fprintln(tw, strings.Join(row, "\t")); err != nil {
			return err
		}
	}
	return tw.Flush()
}

// MaskEnvContent replaces values of secret env keys in dotenv text with MaskValue.
func MaskEnvContent(raw string, secretEnvKeys map[string]bool) string {
	lines := strings.Split(raw, "\n")
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}
		eq := strings.IndexByte(line, '=')
		if eq <= 0 {
			continue
		}
		key := strings.TrimSpace(line[:eq])
		val := line[eq+1:]
		if val == "" {
			continue
		}
		if secretEnvKeys[key] || looksSensitiveEnvKey(key) {
			lines[i] = key + "=" + MaskValue
		}
	}
	return strings.Join(lines, "\n")
}

func looksSensitiveEnvKey(key string) bool {
	upper := strings.ToUpper(key)
	for _, suffix := range []string{"_API_KEY", "_SECRET_KEY", "_PUBLIC_KEY", "_TOKEN", "_SECRET", "_PASSWORD", "_CREDENTIAL"} {
		if strings.HasSuffix(upper, suffix) {
			return true
		}
	}
	return upper == "RC_MCP_SERVERS_JSON"
}

// FieldDiff represents a single key difference between two JSON object maps.
type FieldDiff struct {
	Field  string `json:"field"`
	Before any    `json:"before"`
	After  any    `json:"after"`
}

// DiffMaps compares two flat JSON maps and returns sorted diffs.
func DiffMaps(before, after map[string]any) []FieldDiff {
	keys := make(map[string]struct{}, len(before)+len(after))
	for k := range before {
		keys[k] = struct{}{}
	}
	for k := range after {
		keys[k] = struct{}{}
	}
	sorted := make([]string, 0, len(keys))
	for k := range keys {
		sorted = append(sorted, k)
	}
	sort.Strings(sorted)

	diffs := make([]FieldDiff, 0)
	for _, k := range sorted {
		bv := before[k]
		av := after[k]
		if !valuesEqual(bv, av) {
			diffs = append(diffs, FieldDiff{
				Field:  k,
				Before: bv,
				After:  av,
			})
		}
	}
	return diffs
}

func valuesEqual(a, b any) bool {
	if a == nil && b == nil {
		return true
	}
	return reflect.DeepEqual(a, b)
}

// ParseSetExpr parses a "key=value" CLI expression using optional schema type hints.
// Supported schema types: "boolean", "integer", "number", "string", "json".
func ParseSetExpr(expr string, schemaTypes map[string]string) (string, any, error) {
	eq := strings.IndexByte(expr, '=')
	if eq <= 0 {
		return "", nil, fmt.Errorf("잘못된 --set 형식입니다 (%q). key=value 형태여야 합니다", expr)
	}
	key := strings.TrimSpace(expr[:eq])
	rawVal := expr[eq+1:]
	if key == "" {
		return "", nil, fmt.Errorf("잘못된 --set 형식입니다 (%q). 키가 비어 있습니다", expr)
	}

	kind := ""
	if schemaTypes != nil {
		kind = schemaTypes[key]
	}

	switch kind {
	case "boolean":
		b, err := strconv.ParseBool(rawVal)
		if err != nil {
			return "", nil, fmt.Errorf("필드 %q 은(는) boolean 값이어야 합니다: %w", key, err)
		}
		return key, b, nil
	case "integer":
		n, err := strconv.ParseInt(rawVal, 10, 64)
		if err != nil {
			return "", nil, fmt.Errorf("필드 %q 은(는) integer 값이어야 합니다: %w", key, err)
		}
		return key, n, nil
	case "number":
		f, err := strconv.ParseFloat(rawVal, 64)
		if err != nil {
			return "", nil, fmt.Errorf("필드 %q 은(는) number 값이어야 합니다: %w", key, err)
		}
		return key, f, nil
	case "string":
		return key, rawVal, nil
	default:
		// Schema hint not available: infer bool/number/null only when exact JSON literal,
		// keeping strings intact.
		if rawVal == "true" {
			return key, true, nil
		}
		if rawVal == "false" {
			return key, false, nil
		}
		if rawVal == "null" {
			return key, nil, nil
		}
		if n, err := strconv.ParseInt(rawVal, 10, 64); err == nil {
			return key, n, nil
		}
		if f, err := strconv.ParseFloat(rawVal, 64); err == nil && strings.Contains(rawVal, ".") {
			return key, f, nil
		}
		return key, rawVal, nil
	}
}
