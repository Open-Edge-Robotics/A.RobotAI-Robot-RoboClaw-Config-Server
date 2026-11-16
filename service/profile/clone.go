package profile

import (
	"context"
	"fmt"

	"gorm.io/gorm"
)

// CloneName 은 원본 이름에 _copy 접미사를 붙이고, 동일 이름이 존재하면
// _copy_2, _copy_3 형태로 번호를 증가시켜 고유 이름을 생성한다.
// model 인자는 조회 대상 GORM 모델을 지정한다 (RoboClawConfig, TestScenario 등).
func CloneName(ctx context.Context, db *gorm.DB, model any, originalName string) string {
	base := originalName + "_copy"
	var count int64
	db.WithContext(ctx).Model(model).Where("name = ?", base).Count(&count)
	if count == 0 {
		return base
	}

	for i := 2; ; i++ {
		candidate := fmt.Sprintf("%s_%d", base, i)
		db.WithContext(ctx).Model(model).Where("name = ?", candidate).Count(&count)
		if count == 0 {
			return candidate
		}
	}
}
