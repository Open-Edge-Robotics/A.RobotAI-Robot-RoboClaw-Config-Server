package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"strings"
	"time"

	"ai-config-server/config"

	"github.com/gin-gonic/gin"
)

// McpCatalogEntry는 프런트엔드 "MCP 서버 찾아보기" 목록의 한 항목이다.
// 선택 시 그대로 mcp_adapter.py가 기대하는 서버 설정으로 변환할 수 있도록
// transport/command/args/url 등을 포함한다.
type McpCatalogEntry struct {
	Name        string            `json:"name"`
	DisplayName string            `json:"display_name"`
	Description string            `json:"description"`
	Category    string            `json:"category"`
	Transport   string            `json:"transport"` // "stdio" | "sse" | "streamable_http"
	Command     string            `json:"command,omitempty"`
	Args        []string          `json:"args,omitempty"`
	Env         map[string]string `json:"env,omitempty"`      // 채워야 할 env 키(값은 빈 문자열)
	URL         string            `json:"url,omitempty"`      // sse 전송용
	Homepage    string            `json:"homepage,omitempty"` // 문서/저장소 링크
	Source      string            `json:"source"`             // "builtin" | "registry"
}

// mcpCatalogResponse는 카탈로그 조회 응답 래퍼. source로 실제 사용된 소스를 알린다.
type mcpCatalogResponse struct {
	Source  string            `json:"source"` // "builtin" | "registry"
	Servers []McpCatalogEntry `json:"servers"`
}

// ListMcpCatalog은 MCP 서버 카탈로그를 반환하는 핸들러를 생성한다.
// 동작:
//   - config의 MCP.RegistryURL이 설정돼 있으면 공식 레지스트리를 먼저 조회한다.
//   - 조회 실패(네트워크/파싱) 또는 결과가 비어 있으면 내장 카탈로그로 폴백한다.
//   - 쿼리 파라미터 q로 name/description/category를 대소문자 무시 필터링한다.
func ListMcpCatalog(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		q := strings.TrimSpace(c.Query("q"))

		source := "builtin"
		var servers []McpCatalogEntry

		if cfg != nil && strings.TrimSpace(cfg.MCP.RegistryURL) != "" {
			ctx, cancel := context.WithTimeout(c.Request.Context(), 6*time.Second)
			defer cancel()
			if fetched, err := fetchFromRegistry(ctx, cfg.MCP.RegistryURL, q); err == nil && len(fetched) > 0 {
				servers = fetched
				source = "registry"
			}
		}

		if servers == nil {
			servers = filterCatalog(builtinMcpCatalog(), q)
		}

		c.JSON(http.StatusOK, mcpCatalogResponse{Source: source, Servers: servers})
	}
}

// filterCatalog는 q로 name/display_name/description/category를 부분 일치 필터링한다.
func filterCatalog(entries []McpCatalogEntry, q string) []McpCatalogEntry {
	if q == "" {
		return entries
	}
	lower := strings.ToLower(q)
	out := make([]McpCatalogEntry, 0, len(entries))
	for _, e := range entries {
		hay := strings.ToLower(e.Name + " " + e.DisplayName + " " + e.Description + " " + e.Category)
		if strings.Contains(hay, lower) {
			out = append(out, e)
		}
	}
	return out
}

// ---- 공식 MCP 레지스트리 조회 (best-effort) ----
//
// 레지스트리 스키마는 계속 진화 중이므로 방어적으로 파싱한다. 매핑에 실패한
// 항목은 건너뛰고, 하나도 못 만들면 상위에서 내장 카탈로그로 폴백한다.

type registryListResponse struct {
	Servers []registryServer `json:"servers"`
}

type registryServer struct {
	Name        string            `json:"name"`
	Description string            `json:"description"`
	Repository  *registryRepo     `json:"repository,omitempty"`
	Packages    []registryPackage `json:"packages,omitempty"`
	Remotes     []registryRemote  `json:"remotes,omitempty"`
}

type registryRepo struct {
	URL string `json:"url"`
}

type registryPackage struct {
	RegistryType         string           `json:"registry_type"` // npm | pypi | oci ...
	Identifier           string           `json:"identifier"`
	RuntimeHint          string           `json:"runtime_hint"` // npx | uvx ...
	RuntimeArguments     []registryArg    `json:"runtime_arguments"`
	PackageArguments     []registryArg    `json:"package_arguments"`
	EnvironmentVariables []registryEnvVar `json:"environment_variables"`
}

type registryArg struct {
	Type  string `json:"type"` // positional | named
	Value string `json:"value"`
	Name  string `json:"name"`
}

type registryEnvVar struct {
	Name string `json:"name"`
}

type registryRemote struct {
	Type string `json:"type"` // sse | streamable-http | streamable_http
	URL  string `json:"url"`
}

func fetchFromRegistry(ctx context.Context, baseURL, q string) ([]McpCatalogEntry, error) {
	endpoint := strings.TrimRight(baseURL, "/") + "/v0/servers"
	u, err := url.Parse(endpoint)
	if err != nil {
		return nil, err
	}
	query := u.Query()
	query.Set("limit", "50")
	if q != "" {
		query.Set("search", q)
	}
	u.RawQuery = query.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, &registryError{status: resp.StatusCode}
	}

	var parsed registryListResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, err
	}

	out := make([]McpCatalogEntry, 0, len(parsed.Servers))
	for _, s := range parsed.Servers {
		if entry, ok := registryServerToEntry(s); ok {
			out = append(out, entry)
		}
	}
	return out, nil
}

type registryError struct{ status int }

func (e *registryError) Error() string { return "registry returned non-200 status" }

// registryServerToEntry는 레지스트리 서버 항목을 카탈로그 엔트리로 변환한다.
// remotes가 있으면 해당 원격 transport를 유지하고, packages(npm/pypi)가 있으면
// stdio로 매핑한다. 런타임(mcp_adapter.py)이 사용하는 canonical 값은
// streamable_http이며, 레지스트리의 하이픈 표기도 여기서 정규화한다.
func registryServerToEntry(s registryServer) (McpCatalogEntry, bool) {
	entry := McpCatalogEntry{
		Name:        shortName(s.Name),
		DisplayName: shortName(s.Name),
		Description: s.Description,
		Category:    "registry",
		Source:      "registry",
	}
	if s.Repository != nil {
		entry.Homepage = s.Repository.URL
	}

	// 원격(sse/streamable HTTP) 우선
	for _, r := range s.Remotes {
		if r.URL == "" {
			continue
		}
		transport := strings.ToLower(strings.TrimSpace(r.Type))
		switch transport {
		case "streamable-http", "streamable_http", "http":
			entry.Transport = "streamable_http"
		case "sse":
			entry.Transport = "sse"
		default:
			continue
		}
		entry.URL = r.URL
		return entry, true
	}

	// 패키지 기반 stdio
	for _, p := range s.Packages {
		cmd, args := packageToCommand(p)
		if cmd == "" {
			continue
		}
		entry.Transport = "stdio"
		entry.Command = cmd
		entry.Args = args
		if env := envHints(p.EnvironmentVariables); len(env) > 0 {
			entry.Env = env
		}
		return entry, true
	}

	return McpCatalogEntry{}, false
}

func packageToCommand(p registryPackage) (string, []string) {
	cmd := p.RuntimeHint
	var args []string
	switch strings.ToLower(p.RegistryType) {
	case "npm":
		if cmd == "" {
			cmd = "npx"
		}
		args = append(args, "-y", p.Identifier)
	case "pypi":
		if cmd == "" {
			cmd = "uvx"
		}
		args = append(args, p.Identifier)
	default:
		if cmd == "" {
			return "", nil // 지원하지 않는 런타임
		}
		if p.Identifier != "" {
			args = append(args, p.Identifier)
		}
	}
	// positional 패키지 인자만 반영(값이 있는 것만)
	for _, a := range p.PackageArguments {
		if a.Type == "positional" && a.Value != "" {
			args = append(args, a.Value)
		}
	}
	return cmd, args
}

func envHints(vars []registryEnvVar) map[string]string {
	if len(vars) == 0 {
		return nil
	}
	m := make(map[string]string, len(vars))
	for _, v := range vars {
		if v.Name != "" {
			m[v.Name] = ""
		}
	}
	return m
}

// shortName은 "io.github.owner/name" 형태의 정규화된 이름에서 마지막 세그먼트를 취한다.
func shortName(name string) string {
	if name == "" {
		return name
	}
	if idx := strings.LastIndexAny(name, "/"); idx >= 0 && idx < len(name)-1 {
		return name[idx+1:]
	}
	return name
}

// ---- 내장 큐레이티드 카탈로그 ----
//
// 외부 네트워크 없이도 동작하는 폴백. 잘 알려진 MCP 서버들의 실행 형태를 담는다.
// args의 <...> 자리표시자는 사용자가 UI에서 실제 경로/값으로 바꿔야 한다.
func builtinMcpCatalog() []McpCatalogEntry {
	return []McpCatalogEntry{
		{
			Name: "filesystem", DisplayName: "Filesystem", Category: "reference",
			Description: "로컬 파일시스템 읽기/쓰기 접근",
			Transport:   "stdio", Command: "npx",
			Args:     []string{"-y", "@modelcontextprotocol/server-filesystem", "<허용_디렉토리_경로>"},
			Homepage: "https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem",
			Source:   "builtin",
		},
		{
			Name: "git", DisplayName: "Git", Category: "dev",
			Description: "Git 저장소 조회/조작(로그, diff, 커밋 등)",
			Transport:   "stdio", Command: "uvx",
			Args:     []string{"mcp-server-git", "--repository", "<저장소_경로>"},
			Homepage: "https://github.com/modelcontextprotocol/servers/tree/main/src/git",
			Source:   "builtin",
		},
		{
			Name: "github", DisplayName: "GitHub", Category: "dev",
			Description: "GitHub 이슈/PR/리포지토리 API 연동",
			Transport:   "stdio", Command: "npx",
			Args:     []string{"-y", "@modelcontextprotocol/server-github"},
			Env:      map[string]string{"GITHUB_PERSONAL_ACCESS_TOKEN": ""},
			Homepage: "https://github.com/modelcontextprotocol/servers/tree/main/src/github",
			Source:   "builtin",
		},
		{
			Name: "fetch", DisplayName: "Fetch", Category: "web",
			Description: "URL을 가져와 콘텐츠를 마크다운으로 변환",
			Transport:   "stdio", Command: "uvx",
			Args:     []string{"mcp-server-fetch"},
			Homepage: "https://github.com/modelcontextprotocol/servers/tree/main/src/fetch",
			Source:   "builtin",
		},
		{
			Name: "memory", DisplayName: "Memory", Category: "reference",
			Description: "지식 그래프 기반 영속 메모리",
			Transport:   "stdio", Command: "npx",
			Args:     []string{"-y", "@modelcontextprotocol/server-memory"},
			Homepage: "https://github.com/modelcontextprotocol/servers/tree/main/src/memory",
			Source:   "builtin",
		},
		{
			Name: "sqlite", DisplayName: "SQLite", Category: "data",
			Description: "SQLite 데이터베이스 조회/분석",
			Transport:   "stdio", Command: "uvx",
			Args:     []string{"mcp-server-sqlite", "--db-path", "<DB_파일_경로>"},
			Homepage: "https://github.com/modelcontextprotocol/servers/tree/main/src/sqlite",
			Source:   "builtin",
		},
		{
			Name: "time", DisplayName: "Time", Category: "reference",
			Description: "시간/시간대 변환 유틸리티",
			Transport:   "stdio", Command: "uvx",
			Args:     []string{"mcp-server-time"},
			Homepage: "https://github.com/modelcontextprotocol/servers/tree/main/src/time",
			Source:   "builtin",
		},
		{
			Name: "postgres", DisplayName: "PostgreSQL", Category: "data",
			Description: "PostgreSQL 읽기 전용 조회",
			Transport:   "stdio", Command: "npx",
			Args:     []string{"-y", "@modelcontextprotocol/server-postgres", "<연결_문자열>"},
			Homepage: "https://github.com/modelcontextprotocol/servers/tree/main/src/postgres",
			Source:   "builtin",
		},
		{
			Name: "brave-search", DisplayName: "Brave Search", Category: "web",
			Description: "Brave 검색 API를 통한 웹 검색",
			Transport:   "stdio", Command: "npx",
			Args:     []string{"-y", "@modelcontextprotocol/server-brave-search"},
			Env:      map[string]string{"BRAVE_API_KEY": ""},
			Homepage: "https://github.com/modelcontextprotocol/servers/tree/main/src/brave-search",
			Source:   "builtin",
		},
		{
			Name: "slack", DisplayName: "Slack", Category: "productivity",
			Description: "Slack 채널/메시지 연동",
			Transport:   "stdio", Command: "npx",
			Args:     []string{"-y", "@modelcontextprotocol/server-slack"},
			Env:      map[string]string{"SLACK_BOT_TOKEN": "", "SLACK_TEAM_ID": ""},
			Homepage: "https://github.com/modelcontextprotocol/servers/tree/main/src/slack",
			Source:   "builtin",
		},
		{
			Name: "puppeteer", DisplayName: "Puppeteer", Category: "web",
			Description: "헤드리스 브라우저 자동화/스크래핑",
			Transport:   "stdio", Command: "npx",
			Args:     []string{"-y", "@modelcontextprotocol/server-puppeteer"},
			Homepage: "https://github.com/modelcontextprotocol/servers/tree/main/src/puppeteer",
			Source:   "builtin",
		},
		{
			Name: "sequential-thinking", DisplayName: "Sequential Thinking", Category: "reference",
			Description: "단계적 사고(reasoning) 보조 도구",
			Transport:   "stdio", Command: "npx",
			Args:     []string{"-y", "@modelcontextprotocol/server-sequentialthinking"},
			Homepage: "https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking",
			Source:   "builtin",
		},
	}
}
