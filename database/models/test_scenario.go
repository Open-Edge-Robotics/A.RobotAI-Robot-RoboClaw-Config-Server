package models

import (
	"database/sql/driver"
	"encoding/json"
	"errors"

	"gorm.io/gorm"
)

// TestCase 개별 테스트 케이스 상세 구조체
type TestCase struct {
	ID        string         `json:"id"`
	Name      string         `json:"name"`
	Step      string         `json:"step"`
	Type      string         `json:"type"` // "ping", "robot_info", "battery", "camera", "map" 등
	TimeoutMs int            `json:"timeout_ms"`
	Enabled   bool           `json:"enabled"`
	Params    map[string]any `json:"params,omitempty"`
}

// TestCaseList GORM에서 슬라이스 데이터를 SQLite TEXT 컬럼에 저장하기 위한 custom type
type TestCaseList []TestCase

// Scan DB에서 데이터를 읽어올 때 호출됨 (JSON -> Struct)
func (t *TestCaseList) Scan(value interface{}) error {
	if value == nil {
		*t = TestCaseList{}
		return nil
	}
	bytes, ok := value.([]byte)
	if !ok {
		// SQLite Driver는 string으로 반환할 수도 있으므로 string 체크
		strVal, okStr := value.(string)
		if !okStr {
			return errors.New("failed to unmarshal JSON value: invalid type")
		}
		bytes = []byte(strVal)
	}
	return json.Unmarshal(bytes, t)
}

// Value DB에 데이터를 쓸 때 호출됨 (Struct -> JSON)
func (t TestCaseList) Value() (driver.Value, error) {
	if len(t) == 0 {
		return "[]", nil
	}
	bytes, err := json.Marshal(t)
	if err != nil {
		return nil, err
	}
	return string(bytes), nil
}

// TestScenario 로봇/환경별 테스트 시나리오 구조체
type TestScenario struct {
	gorm.Model
	Name        string       `gorm:"not null" json:"name"`
	Description string       `json:"description"`
	RobotName   string       `gorm:"index;not null" json:"robot_name"`
	Environment string       `gorm:"index;not null" json:"environment"`
	IsActive    bool         `gorm:"default:false" json:"is_active"`
	TestCases   TestCaseList `gorm:"type:text" json:"test_cases"`
}
