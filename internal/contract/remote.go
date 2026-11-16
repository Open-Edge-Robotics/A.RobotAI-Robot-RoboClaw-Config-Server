package contract

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// remoteRequestTimeout 은 release 메타데이터/에셋 요청의 상한이다.
// 응답이 없는 네트워크에서 contract 명령이 무한정 멈추지 않도록 한다.
const remoteRequestTimeout = 30 * time.Second

type releaseLink struct {
	Name string `json:"name"`
	URL  string `json:"url"`
}

type releaseResponse struct {
	Assets struct {
		Links []releaseLink `json:"links"`
	} `json:"assets"`
}

// remoteClient 는 release 조회용 HTTP 클라이언트다. 테스트에서 짧은 timeout 을
// 주입할 수 있도록 호출마다 새로 만든다(연결 풀 공유가 필요한 핫 패스가 아니다).
func remoteClient() *http.Client {
	return &http.Client{Timeout: remoteRequestTimeout}
}

// UpdateContractFromGitLab downloads a public GitLab Release bundle and reuses
// the same checksum/lock installation path as local bundle updates.
func UpdateContractFromGitLab(project, version, targetDir string) (string, error) {
	if project == "" || version == "" {
		return "", fmt.Errorf("contract project and version are required")
	}
	projectID := url.PathEscape(project)
	apiURL := fmt.Sprintf("https://gitlab.com/api/v4/projects/%s/releases/%s", projectID, url.PathEscape(version))
	client := remoteClient()
	release, err := fetchReleaseWith(client, apiURL)
	if err != nil {
		return "", err
	}
	links := make(map[string]string, len(release.Assets.Links))
	for _, link := range release.Assets.Links {
		links[link.Name] = link.URL
	}
	for _, name := range []string{"runtime-contract.json", "runtime-config.schema.json", "contract-manifest.json"} {
		if links[name] == "" {
			return "", fmt.Errorf("release %s is missing asset %s", version, name)
		}
	}

	tempDir, err := os.MkdirTemp("", "rcf-contract-release-")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(tempDir)
	for _, name := range []string{"runtime-contract.json", "runtime-config.schema.json", "contract-manifest.json"} {
		if err := downloadFileWith(client, links[name], filepath.Join(tempDir, name)); err != nil {
			return "", err
		}
	}
	return UpdateContract(tempDir, targetDir)
}

func fetchRelease(apiURL string) (releaseResponse, error) {
	return fetchReleaseWith(remoteClient(), apiURL)
}

func fetchReleaseWith(client *http.Client, apiURL string) (releaseResponse, error) {
	resp, err := client.Get(apiURL)
	if err != nil {
		return releaseResponse{}, fmt.Errorf("failed to fetch GitLab release: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return releaseResponse{}, fmt.Errorf("GitLab release request failed: HTTP %d", resp.StatusCode)
	}
	var release releaseResponse
	if err := json.NewDecoder(resp.Body).Decode(&release); err != nil {
		return releaseResponse{}, fmt.Errorf("failed to parse GitLab release: %w", err)
	}
	return release, nil
}

func downloadFile(rawURL, target string) error {
	return downloadFileWith(remoteClient(), rawURL, target)
}

func downloadFileWith(client *http.Client, rawURL, target string) error {
	parsed, err := url.Parse(rawURL)
	if err != nil || !strings.EqualFold(parsed.Scheme, "https") {
		return fmt.Errorf("release asset URL must use HTTPS: %s", rawURL)
	}
	resp, err := client.Get(parsed.String())
	if err != nil {
		return fmt.Errorf("failed to download release asset: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("release asset request failed: HTTP %d", resp.StatusCode)
	}
	file, err := os.Create(target)
	if err != nil {
		return err
	}
	defer file.Close()
	if _, err := io.Copy(file, resp.Body); err != nil {
		return fmt.Errorf("failed to write release asset: %w", err)
	}
	return nil
}
