import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

class ConfigLearningSection extends StatelessWidget {
  final bool isEditing;
  final bool enableSkillLearning;
  final ValueChanged<bool> onEnableSkillLearningChanged;
  final TextEditingController skillLearningSuccessSampleRateCtrl;
  final TextEditingController skillLearningReflectIntervalSecCtrl;

  const ConfigLearningSection({
    super.key,
    required this.isEditing,
    required this.enableSkillLearning,
    required this.onEnableSkillLearningChanged,
    required this.skillLearningSuccessSampleRateCtrl,
    required this.skillLearningReflectIntervalSecCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('8. 스킬 자가학습 설정 (RAG)'),
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              value: enableSkillLearning,
              onChanged: isEditing ? onEnableSkillLearningChanged : null,
            ),
            const SizedBox(width: 8),
            Text('자가학습 활성화 (RC_ENABLE_SKILL_LEARNING)'.tr),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: skillLearningSuccessSampleRateCtrl,
                enabled: isEditing && enableSkillLearning,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      '성공 경험 샘플링 비율 (RC_SKILL_LEARNING_SUCCESS_SAMPLE_RATE)'.tr,
                  hintText: '예: 0.1 (10%)'.tr,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: skillLearningReflectIntervalSecCtrl,
                enabled: isEditing && enableSkillLearning,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      '자가학습 교훈 추출 자동 주기(초) (RC_SKILL_LEARNING_REFLECT_INTERVAL_SEC)'
                          .tr,
                  hintText: '예: 1800 (초)'.tr,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
