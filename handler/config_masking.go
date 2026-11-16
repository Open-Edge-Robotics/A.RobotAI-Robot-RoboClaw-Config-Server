package handler

import (
	"ai-config-server/database/models"
	"ai-config-server/service/profile"
)

// MaskValue 는 API 응답에서 자격 증명을 대체하는 값이다. 정의는 service/profile 에 있다.
const MaskValue = profile.MaskValue

// maskSensitiveFields 는 외부 API 응답 시 민감한 자격 증명을 마스킹한다.
// 표와 규칙은 service/profile 이 소유한다.
func maskSensitiveFields(cfg *models.RoboClawConfig) {
	profile.Mask(cfg)
}

// maskMcpServersJson 은 MCP 서버 목록에서 자격 증명 값(env/headers)만 마스킹한다.
// 실제 구현은 profile.MaskMCPServersJSON 에 있다.
func maskMcpServersJson(raw string) string {
	return profile.MaskMCPServersJSON(raw)
}

// mergeMaskedMcpServersJson 은 요청에 남아 있는 마스킹 값을 기존 저장 값으로 되돌린다.
// 실제 구현은 profile.MergeMaskedMCPServersJSON 에 있다.
func mergeMaskedMcpServersJson(existing, incoming string) string {
	return profile.MergeMaskedMCPServersJSON(existing, incoming)
}
