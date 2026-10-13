import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

class ConfigCleanupDemoSection extends StatelessWidget {
  final bool isEditing;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final TextEditingController motionIdsJsonCtrl;
  final bool expressionEnabled;
  final ValueChanged<bool> onExpressionEnabledChanged;

  const ConfigCleanupDemoSection({
    super.key,
    required this.isEditing,
    required this.enabled,
    required this.onEnabledChanged,
    required this.motionIdsJsonCtrl,
    required this.expressionEnabled,
    required this.onExpressionEnabledChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('CLOi 1호 정리 시연 설정'.tr),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const ValueKey('cloid_cleanup_demo_enabled'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('정리 시연 기능 사용'.tr),
          value: enabled,
          onChanged: isEditing
              ? (value) {
                  if (value != null) onEnabledChanged(value);
                }
              : null,
        ),
        const SizedBox(height: 4),
        TextFormField(
          key: const ValueKey('cloid_cleanup_demo_motion_ids_json'),
          controller: motionIdsJsonCtrl,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: '정리 시연 허용 모션 ID (JSON 배열)'.tr,
            hintText: '예: [22,60]'.tr,
            helperText:
                'CLOi 1호 전용입니다. 빈 값은 승인된 기본값 [22,60]을 사용합니다. []는 시연을 끕니다. catalog pre_id가 있는 모션은 실행하지 않습니다.'
                    .tr,
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          key: const ValueKey('cloid_expression_enabled'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('상황별 표현 모션 자동 재생'.tr),
          subtitle: Text(
            'CLOiD가 태스크를 마친 뒤 상황(인사·대화·탐색·실패)에 맞는 등록 모션을 한 번 재생합니다. 주행이 포함된 태스크에서는 재생하지 않습니다. 상체 구동 오류 개체(2호)는 끄세요.'
                .tr,
          ),
          value: expressionEnabled,
          onChanged: isEditing
              ? (value) {
                  if (value != null) onExpressionEnabledChanged(value);
                }
              : null,
        ),
      ],
    );
  }
}
