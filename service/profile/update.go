package profile

import (
	"encoding/json"
	"errors"

	"ai-config-server/database/models"
	"ai-config-server/service"
)

// Merge 단계 오류. handler 는 이 값으로 HTTP 상태 코드와 응답 문구를 고른다.
var (
	// ErrMergeBase 는 기존 레코드를 병합 map 으로 만드는 단계의 실패다(500).
	ErrMergeBase = errors.New("기존 설정 병합 실패")
	// ErrMergePatch 는 병합 map 을 다시 직렬화하는 단계의 실패다(500).
	ErrMergePatch = errors.New("수정 요청 병합 실패")
	// ErrPatchFieldType 은 요청 필드 형식이 모델과 맞지 않는 경우다(400).
	ErrPatchFieldType = errors.New("수정 요청 필드 형식 오류")
)

// MergeError 는 실패 단계를 errors.Is 로 구분하면서 원인 오류 문구를 그대로 노출한다.
// handler 로그와 400 응답 details 문구를 이전과 동일하게 유지하기 위한 것이다.
type MergeError struct {
	stage error
	err   error
}

func (e *MergeError) Error() string        { return e.err.Error() }
func (e *MergeError) Unwrap() error        { return e.err }
func (e *MergeError) Is(target error) bool { return target == e.stage }

// protectedPatchKeys 는 일반 수정 payload 가 변경할 수 없는 키다.
// ID/타임스탬프는 영속성 메타데이터이고, is_active 는 전용 activate API 소유다.
var protectedPatchKeys = []string{
	"ID", "id",
	"CreatedAt", "created_at",
	"UpdatedAt", "updated_at",
	"DeletedAt", "deleted_at",
	"is_active",
}

// Merge 는 PUT 수정 요청을 기존 레코드와 병합한다.
//
// 전체 모델에 직접 바인딩하면 새 필드를 모르는 구형 클라이언트의 PUT 요청이 해당
// 필드를 zero value 로 초기화하므로, 기존 레코드를 map 으로 펼친 뒤 요청 필드만
// 덮어쓴다. 마스킹된 자격 증명은 기존 저장 값으로 복원한다.
func Merge(current models.RoboClawConfig, patch map[string]json.RawMessage, id uint) (models.RoboClawConfig, error) {
	existingJSON, err := json.Marshal(current)
	if err != nil {
		return models.RoboClawConfig{}, &MergeError{stage: ErrMergeBase, err: err}
	}
	merged := make(map[string]json.RawMessage)
	if err := json.Unmarshal(existingJSON, &merged); err != nil {
		return models.RoboClawConfig{}, &MergeError{stage: ErrMergeBase, err: err}
	}

	for key, value := range patch {
		merged[key] = value
	}
	for _, key := range protectedPatchKeys {
		delete(merged, key)
	}

	mergedJSON, err := json.Marshal(merged)
	if err != nil {
		return models.RoboClawConfig{}, &MergeError{stage: ErrMergePatch, err: err}
	}

	var req models.RoboClawConfig
	if err := json.Unmarshal(mergedJSON, &req); err != nil {
		return models.RoboClawConfig{}, &MergeError{stage: ErrPatchFieldType, err: err}
	}

	// MCP 서버 목록과 자격 증명 필드는 마스킹 값을 기존 저장 값으로 되돌린다.
	// JSON 포맷 검증 전에 복원해야 한다(validateJSONFields 가 MCP 목록도 검사한다).
	restoreSecrets(&req, &current)

	// PUT 은 프로필 내용을 수정하는 API 다. 프론트엔드가 is_active 를 생략하거나
	// 오래된 클라이언트가 false 를 보내도 활성 프로필이 편집으로 비활성화되지 않도록
	// 기존 값을 보존하고, 영속성 메타데이터와 ID 도 고정한다.
	req.IsActive = current.IsActive
	req.CreatedAt = current.CreatedAt
	req.UpdatedAt = current.UpdatedAt
	req.DeletedAt = current.DeletedAt
	req.ID = id
	service.ApplyButlerPathDefaults(&req)
	return req, nil
}
