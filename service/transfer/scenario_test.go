package transfer

import (
	"encoding/json"
	"reflect"
	"testing"

	"ai-config-server/database/models"
)

// TestScenarioFromModelPreservesFieldsAndTestCases 는 시나리오와 케이스 변환을 확인한다.
func TestScenarioFromModelPreservesFieldsAndTestCases(t *testing.T) {
	scenario := &models.TestScenario{
		Name:        "pick-and-place",
		Description: "설명",
		RobotName:   "butler",
		Environment: "office",
		IsActive:    true,
		TestCases: models.TestCaseList{
			{
				ID:        "step-1",
				Name:      "이동",
				Step:      "move",
				Type:      "action",
				TimeoutMs: 5000,
				Enabled:   true,
				Params:    map[string]any{"target": "kitchen"},
			},
			{
				ID:      "step-2",
				Name:    "정지",
				Step:    "stop",
				Type:    "action",
				Enabled: false,
			},
		},
	}

	tr := ScenarioFromModel(scenario)
	if tr.Name != scenario.Name || tr.Description != scenario.Description {
		t.Error("시나리오 메타데이터가 유지되어야 함")
	}
	if tr.RobotName != scenario.RobotName || tr.Environment != scenario.Environment || !tr.IsActive {
		t.Error("시나리오 식별/활성 상태가 유지되어야 함")
	}
	if len(tr.TestCases) != 2 {
		t.Fatalf("테스트 케이스 수: got %d, want 2", len(tr.TestCases))
	}
	first := tr.TestCases[0]
	if first.ID != "step-1" || first.Name != "이동" || first.Step != "move" || first.Type != "action" {
		t.Error("테스트 케이스 문자열 필드가 유지되어야 함")
	}
	if first.TimeoutMs != 5000 || !first.Enabled {
		t.Error("테스트 케이스 수치/활성 필드가 유지되어야 함")
	}
	if first.Params["target"] != "kitchen" {
		t.Error("테스트 케이스 params 가 유지되어야 함")
	}
	if tr.TestCases[1].Enabled {
		t.Error("비활성 테스트 케이스의 false 가 유지되어야 함")
	}
}

// TestScenarioTransferJSONRoundTrip 는 JSON 왕복 후 값이 유지되는지 확인한다.
func TestScenarioTransferJSONRoundTrip(t *testing.T) {
	scenario := &models.TestScenario{
		Name:        "nav",
		Description: "설명",
		RobotName:   "butler",
		Environment: "office",
		IsActive:    false,
		TestCases: models.TestCaseList{
			{
				ID:        "c1",
				Name:      "확인",
				Step:      "check",
				Type:      "assert",
				TimeoutMs: 1500,
				Enabled:   true,
				Params:    map[string]any{"flag": true, "label": "ok"},
			},
		},
	}

	data, err := json.Marshal(ScenarioFromModel(scenario))
	if err != nil {
		t.Fatal(err)
	}
	var decoded ScenarioTransfer
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatal(err)
	}
	restored := decoded.ToModel()
	if !reflect.DeepEqual(restored.Name, scenario.Name) || restored.IsActive != scenario.IsActive {
		t.Error("시나리오 필드가 왕복 후에도 유지되어야 함")
	}
	if len(restored.TestCases) != 1 {
		t.Fatalf("테스트 케이스 수: got %d, want 1", len(restored.TestCases))
	}
	// JSON 숫자는 float64 로 복원되므로 params 는 문자열/불리언만 비교한다.
	params := restored.TestCases[0].Params
	if params["label"] != "ok" || params["flag"] != true {
		t.Errorf("params 가 왕복 후에도 유지되어야 함: %#v", params)
	}
	if restored.TestCases[0].TimeoutMs != 1500 {
		t.Error("timeout_ms 가 왕복 후에도 유지되어야 함")
	}
}

// TestScenarioToModelWithoutTestCases 는 케이스가 없을 때 빈 목록을 만드는지 확인한다.
func TestScenarioToModelWithoutTestCases(t *testing.T) {
	model := ScenarioTransfer{Name: "empty"}.ToModel()
	if model.TestCases == nil {
		t.Fatal("빈 테스트 케이스 목록은 nil 이 아니어야 함")
	}
	if len(model.TestCases) != 0 {
		t.Errorf("테스트 케이스 수: got %d, want 0", len(model.TestCases))
	}
	if model.Name != "empty" {
		t.Error("시나리오 이름이 유지되어야 함")
	}
}
