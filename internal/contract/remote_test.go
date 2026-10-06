package contract

import "testing"

func TestReleaseAssetURLMustUseHTTPS(t *testing.T) {
	if err := downloadFile("http://example.com/contract.json", t.TempDir()+"/contract.json"); err == nil {
		t.Fatal("expected HTTP release asset URL to be rejected")
	}
}
