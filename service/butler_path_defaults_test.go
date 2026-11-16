package service

import (
	"testing"

	"ai-config-server/database/models"
)

// TestApplyButlerPathDefaults 는 butler 로봇의 빈 경로만 기본값으로 채우는지 검증한다.
func TestApplyButlerPathDefaults(t *testing.T) {
	empty := &models.RoboClawConfig{RobotName: "Butler"}
	ApplyButlerPathDefaults(empty)
	if empty.ButlerScriptsDir != defaultButlerScriptsDir || empty.ButlerSourceDir != defaultButlerSourceDir {
		t.Errorf("expected defaults applied, got %q/%q", empty.ButlerScriptsDir, empty.ButlerSourceDir)
	}

	explicit := &models.RoboClawConfig{
		RobotName:        "butler",
		ButlerScriptsDir: "/custom/scripts",
		ButlerSourceDir:  "/custom/source",
	}
	ApplyButlerPathDefaults(explicit)
	if explicit.ButlerScriptsDir != "/custom/scripts" || explicit.ButlerSourceDir != "/custom/source" {
		t.Errorf("expected explicit values preserved, got %q/%q", explicit.ButlerScriptsDir, explicit.ButlerSourceDir)
	}

	other := &models.RoboClawConfig{RobotName: "former"}
	ApplyButlerPathDefaults(other)
	if other.ButlerScriptsDir != "" || other.ButlerSourceDir != "" {
		t.Errorf("expected non-butler robot untouched, got %q/%q", other.ButlerScriptsDir, other.ButlerSourceDir)
	}
}
