package service

import (
	"strings"

	"ai-config-server/database/models"
)

const (
	defaultButlerScriptsDir = "/home/seoyc/Workspace/ros/butler/products/prd_butler_v01_magok_w02/script"
	defaultButlerSourceDir  = "/home/udr/workspace/butler_v01_config/cloi2_ws"
)

// ApplyButlerPathDefaults 는 butler 로봇 설정의 비어 있는 기본 경로를 채운다.
func ApplyButlerPathDefaults(cfg *models.RoboClawConfig) {
	if !strings.EqualFold(cfg.RobotName, "butler") {
		return
	}
	if cfg.ButlerScriptsDir == "" {
		cfg.ButlerScriptsDir = defaultButlerScriptsDir
	}
	if cfg.ButlerSourceDir == "" {
		cfg.ButlerSourceDir = defaultButlerSourceDir
	}
}
