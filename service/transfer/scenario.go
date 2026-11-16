package transfer

import (
	"ai-config-server/database/models"
)

// ScenarioFromModel은 DB 원본 테스트 시나리오를 전송 DTO로 변환한다.
func ScenarioFromModel(s *models.TestScenario) ScenarioTransfer {
	tc := make([]TestCaseTransfer, 0, len(s.TestCases))
	for _, c := range s.TestCases {
		tc = append(tc, TestCaseTransfer{
			ID:        c.ID,
			Name:      c.Name,
			Step:      c.Step,
			Type:      c.Type,
			TimeoutMs: c.TimeoutMs,
			Enabled:   c.Enabled,
			Params:    c.Params,
		})
	}
	return ScenarioTransfer{
		Name:        s.Name,
		Description: s.Description,
		RobotName:   s.RobotName,
		Environment: s.Environment,
		IsActive:    s.IsActive,
		TestCases:   tc,
	}
}

// ToModel은 전송 DTO를 DB 모델로 변환한다.
func (t ScenarioTransfer) ToModel() models.TestScenario {
	tc := make(models.TestCaseList, 0, len(t.TestCases))
	for _, c := range t.TestCases {
		tc = append(tc, models.TestCase{
			ID:        c.ID,
			Name:      c.Name,
			Step:      c.Step,
			Type:      c.Type,
			TimeoutMs: c.TimeoutMs,
			Enabled:   c.Enabled,
			Params:    c.Params,
		})
	}
	return models.TestScenario{
		Name:        t.Name,
		Description: t.Description,
		RobotName:   t.RobotName,
		Environment: t.Environment,
		IsActive:    t.IsActive,
		TestCases:   tc,
	}
}
