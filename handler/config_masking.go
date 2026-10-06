package handler

import (
	"encoding/json"
	"reflect"
	"strings"

	"ai-config-server/database/models"
)

// mcpSecretMapFields는 MCP 서버 설정에서 자격 증명이 들어가는 map 필드다.
// stdio 전송은 env, sse/streamable_http 전송은 headers 로 토큰을 전달한다.
var mcpSecretMapFields = []string{"env", "headers"}

// maskSensitiveFields는 외부 API 응답 시 민감한 API Key들을 마스킹합니다.
func maskSensitiveFields(cfg *models.RoboClawConfig) {
	if cfg.AzureOpenaiApiKey != "" {
		cfg.AzureOpenaiApiKey = "********"
	}
	if cfg.OpenaiApiKey != "" {
		cfg.OpenaiApiKey = "********"
	}
	if cfg.AnthropicApiKey != "" {
		cfg.AnthropicApiKey = "********"
	}
	if cfg.LlmEmbeddingApiKey != "" {
		cfg.LlmEmbeddingApiKey = "********"
	}
	if cfg.DiscordBotToken != "" {
		cfg.DiscordBotToken = "********"
	}
	if cfg.SlackAppToken != "" {
		cfg.SlackAppToken = "********"
	}
	if cfg.SlackBotToken != "" {
		cfg.SlackBotToken = "********"
	}
	if cfg.TelegramBotToken != "" {
		cfg.TelegramBotToken = "********"
	}
	if cfg.HttpReadonlyToken != "" {
		cfg.HttpReadonlyToken = "********"
	}
	if cfg.HttpControlToken != "" {
		cfg.HttpControlToken = "********"
	}
	if cfg.QdrantApiKey != "" {
		cfg.QdrantApiKey = "********"
	}
	if cfg.McpServersJson != "" && cfg.McpServersJson != "[]" {
		cfg.McpServersJson = maskMcpServersJson(cfg.McpServersJson)
	}
	if cfg.GrpcPeerToken != "" {
		cfg.GrpcPeerToken = "********"
	}
	if cfg.LangsmithApiKey != "" {
		cfg.LangsmithApiKey = "********"
	}
	if cfg.System1ApiKey != "" {
		cfg.System1ApiKey = "********"
	}
}

// maskMcpServersJson은 MCP 서버 목록에서 자격 증명 값(env/headers)만 마스킹한다.
//
// 서버 구조(name/transport/command/args/cwd/url/timeout)는 대시보드에서 목록을
// 확인하고 편집할 수 있도록 그대로 노출한다. 이전에는 JSON 전체를 "********" 로
// 치환해서 등록한 MCP 서버가 대시보드에 하나도 보이지 않았다.
//
// JSON 배열이 아니거나 파싱할 수 없으면 값 유출을 막기 위해 전체를 마스킹한다.
func maskMcpServersJson(raw string) string {
	if raw == "" || raw == "[]" {
		return raw
	}

	var servers []map[string]any
	if err := json.Unmarshal([]byte(raw), &servers); err != nil {
		return MaskValue
	}

	for _, server := range servers {
		maskMcpSecretMaps(server)
	}

	masked, err := json.Marshal(servers)
	if err != nil {
		return MaskValue
	}
	return string(masked)
}

// maskMcpSecretMaps는 한 MCP 서버의 자격 증명 map 값들을 마스킹한다.
// 빈 값은 키 존재 여부만 유지하고 그대로 둔다.
func maskMcpSecretMaps(server map[string]any) {
	for _, field := range mcpSecretMapFields {
		secrets, ok := server[field].(map[string]any)
		if !ok {
			continue
		}
		for key, value := range secrets {
			if s, ok := value.(string); ok && s != "" {
				secrets[key] = MaskValue
			}
		}
	}
}

// mergeMaskedMcpServersJson은 요청에 그대로 남아 있는 마스킹 값("********")을
// 기존 저장 값으로 되돌린다. 이름으로 먼저 매칭하고, 이름이 바뀐 경우에는 서버
// 실행 대상이 유일하게 일치할 때 기존 서버로 간주한다.
//
// 대시보드는 자격 증명만 마스킹된 목록을 받아 편집하므로, 사용자가 마스킹된 값을
// 건드리지 않고 저장했을 때 실제 자격 증명이 "********" 로 덮어써지면 안 된다.
// 대응하는 저장 값이 없는 마스킹 값은 실제 자격 증명으로 저장되지 않도록 제거한다.
func mergeMaskedMcpServersJson(existing, incoming string) string {
	if !strings.Contains(incoming, MaskValue) {
		return incoming
	}

	var incomingServers []map[string]any
	if err := json.Unmarshal([]byte(incoming), &incomingServers); err != nil {
		return incoming
	}

	var storedServers []map[string]any
	if err := json.Unmarshal([]byte(existing), &storedServers); err != nil {
		storedServers = nil
	}
	storedByName := make(map[string]int, len(storedServers))
	for i, server := range storedServers {
		if name, ok := server["name"].(string); ok && name != "" {
			storedByName[name] = i
		}
	}

	usedStored := make(map[int]bool, len(storedServers))
	for _, server := range incomingServers {
		name, _ := server["name"].(string)
		storedIndex, found := storedByName[name]
		if !found || usedStored[storedIndex] {
			storedIndex, found = findStoredMcpServerByIdentity(server, storedServers, usedStored)
		}
		if found {
			restoreMcpSecretMaps(server, storedServers[storedIndex])
			usedStored[storedIndex] = true
		} else {
			// 새 서버나 식별할 수 없는 서버에 마스킹 값이 그대로 저장되지 않게 한다.
			restoreMcpSecretMaps(server, nil)
		}
	}

	merged, err := json.Marshal(incomingServers)
	if err != nil {
		return incoming
	}
	return string(merged)
}

// findStoredMcpServerByIdentity는 이름 변경을 보완한다. stdio 는 command/args/cwd,
// 원격 transport 는 URL이 모두 일치하는 저장 서버가 하나뿐일 때만 매칭한다.
// 모호한 경우에는 다른 서버의 자격 증명을 잘못 복사하지 않도록 매칭하지 않는다.
func findStoredMcpServerByIdentity(incoming map[string]any, stored []map[string]any, used map[int]bool) (int, bool) {
	transport := mcpTransport(incoming)
	matches := make([]int, 0, 1)
	for i, candidate := range stored {
		if used[i] || mcpTransport(candidate) != transport {
			continue
		}
		if !sameMcpServerIdentity(incoming, candidate, transport) {
			continue
		}
		matches = append(matches, i)
	}
	if len(matches) != 1 {
		return 0, false
	}
	return matches[0], true
}

func mcpTransport(server map[string]any) string {
	transport, _ := server["transport"].(string)
	if transport == "" {
		return "stdio"
	}
	return transport
}

func sameMcpServerIdentity(incoming, stored map[string]any, transport string) bool {
	switch transport {
	case "stdio":
		command, _ := incoming["command"].(string)
		storedCommand, _ := stored["command"].(string)
		if command == "" || command != storedCommand {
			return false
		}
		return reflect.DeepEqual(mcpArgs(incoming["args"]), mcpArgs(stored["args"])) &&
			mcpString(incoming["cwd"]) == mcpString(stored["cwd"])
	case "sse", "streamable_http":
		url := mcpString(incoming["url"])
		return url != "" && url == mcpString(stored["url"])
	default:
		return false
	}
}

func mcpArgs(value any) []any {
	args, _ := value.([]any)
	if args == nil {
		return []any{}
	}
	return args
}

func mcpString(value any) string {
	text, _ := value.(string)
	return text
}

// restoreMcpSecretMaps는 요청 서버의 마스킹된 자격 증명 값을 저장된 값으로 복원한다.
func restoreMcpSecretMaps(server, stored map[string]any) {
	for _, field := range mcpSecretMapFields {
		secrets, ok := server[field].(map[string]any)
		if !ok {
			continue
		}
		storedSecrets, _ := stored[field].(map[string]any)
		for key, value := range secrets {
			if value != MaskValue {
				continue
			}
			if storedValue, ok := storedSecrets[key].(string); ok {
				secrets[key] = storedValue
				continue
			}
			delete(secrets, key)
		}
	}
}
