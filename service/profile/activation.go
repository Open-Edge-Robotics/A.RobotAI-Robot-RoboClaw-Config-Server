package profile

import (
	"gorm.io/gorm"

	"ai-config-server/database/models"
)

// DeactivateOthers 는 같은 로봇/환경의 다른 활성 레코드를 모두 비활성화한다.
// 활성 배타성 규칙은 이 함수 한 곳에만 있다. exceptID 가 0 이면 제외 대상이 없다.
func DeactivateOthers(tx *gorm.DB, model any, robotName, environment string, exceptID uint) error {
	query := tx.Model(model).Where("robot_name = ? AND environment = ?", robotName, environment)
	if exceptID != 0 {
		query = query.Where("id <> ?", exceptID)
	}
	return query.Update("is_active", false).Error
}

// CreateConfigInTx 는 활성 배타성을 지키며 설정을 생성한다.
func CreateConfigInTx(tx *gorm.DB, cfg *models.RoboClawConfig) error {
	if cfg.IsActive {
		if err := DeactivateOthers(tx, &models.RoboClawConfig{}, cfg.RobotName, cfg.Environment, 0); err != nil {
			return err
		}
	}
	return tx.Create(cfg).Error
}

// UpdateConfigInTx 는 활성 배타성을 지키며 설정을 저장한다.
func UpdateConfigInTx(tx *gorm.DB, cfg *models.RoboClawConfig) error {
	if cfg.IsActive {
		if err := DeactivateOthers(tx, &models.RoboClawConfig{}, cfg.RobotName, cfg.Environment, cfg.ID); err != nil {
			return err
		}
	}
	return tx.Save(cfg).Error
}

// ActivateConfigInTx 는 설정을 활성화하고 같은 로봇/환경의 다른 설정을 비활성화한다.
func ActivateConfigInTx(tx *gorm.DB, cfg *models.RoboClawConfig) error {
	if err := DeactivateOthers(tx, &models.RoboClawConfig{}, cfg.RobotName, cfg.Environment, 0); err != nil {
		return err
	}
	return tx.Model(cfg).Update("is_active", true).Error
}

// CreateScenarioInTx 는 활성 배타성을 지키며 테스트 시나리오를 생성한다.
func CreateScenarioInTx(tx *gorm.DB, scenario *models.TestScenario) error {
	if scenario.IsActive {
		if err := DeactivateOthers(tx, &models.TestScenario{}, scenario.RobotName, scenario.Environment, 0); err != nil {
			return err
		}
	}
	return tx.Create(scenario).Error
}

// UpdateScenarioInTx 는 활성 배타성을 지키며 테스트 시나리오를 저장한다.
func UpdateScenarioInTx(tx *gorm.DB, scenario *models.TestScenario) error {
	if scenario.IsActive {
		if err := DeactivateOthers(tx, &models.TestScenario{}, scenario.RobotName, scenario.Environment, scenario.ID); err != nil {
			return err
		}
	}
	return tx.Save(scenario).Error
}

// ActivateScenarioInTx 는 시나리오를 활성화하고 같은 로봇/환경의 다른 시나리오를 비활성화한다.
func ActivateScenarioInTx(tx *gorm.DB, scenario *models.TestScenario) error {
	if err := DeactivateOthers(tx, &models.TestScenario{}, scenario.RobotName, scenario.Environment, 0); err != nil {
		return err
	}
	return tx.Model(scenario).Update("is_active", true).Error
}
