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
)

type releaseLink struct {
	Name string `json:"name"`
	URL  string `json:"url"`
}

type releaseResponse struct {
	Assets struct {
		Links []releaseLink `json:"links"`
	} `json:"assets"`
}

// UpdateContractFromGitLab downloads a public GitLab Release bundle and reuses
// the same checksum/lock installation path as local bundle updates.
func UpdateContractFromGitLab(project, version, targetDir string) (string, error) {
	if project == "" || version == "" {
		return "", fmt.Errorf("contract project and version are required")
	}
	projectID := url.PathEscape(project)
	apiURL := fmt.Sprintf("https://gitlab.com/api/v4/projects/%s/releases/%s", projectID, url.PathEscape(version))
	release, err := fetchRelease(apiURL)
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
		if err := downloadFile(links[name], filepath.Join(tempDir, name)); err != nil {
			return "", err
		}
	}
	return UpdateContract(tempDir, targetDir)
}

func fetchRelease(apiURL string) (releaseResponse, error) {
	resp, err := http.Get(apiURL)
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
	parsed, err := url.Parse(rawURL)
	if err != nil || !strings.EqualFold(parsed.Scheme, "https") {
		return fmt.Errorf("release asset URL must use HTTPS: %s", rawURL)
	}
	resp, err := http.Get(parsed.String())
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
