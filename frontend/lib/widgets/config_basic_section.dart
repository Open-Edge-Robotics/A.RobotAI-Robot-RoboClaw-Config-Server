import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

class ConfigBasicSection extends StatelessWidget {
  final bool isEditing;
  final TextEditingController nameCtrl;
  final TextEditingController robotCtrl;
  final TextEditingController envCtrl;
  final TextEditingController descCtrl;
  final TextEditingController rosDomainCtrl;
  final TextEditingController agentIdCtrl;
  final bool debug;
  final ValueChanged<bool> onDebugChanged;

  const ConfigBasicSection({
    super.key,
    required this.isEditing,
    required this.nameCtrl,
    required this.robotCtrl,
    required this.envCtrl,
    required this.descCtrl,
    required this.rosDomainCtrl,
    required this.agentIdCtrl,
    required this.debug,
    required this.onDebugChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('1. 기본 정보'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: nameCtrl,
                enabled: isEditing,
                decoration: InputDecoration(labelText: '설정 프로필 이름 *'.tr),
                validator: (val) =>
                    val == null || val.isEmpty ? '필수 입력입니다'.tr : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: robotCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '로봇 식별자 (robot_name) *'.tr,
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? '필수 입력입니다'.tr : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: envCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '구동 환경 (environment) *'.tr,
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? '필수 입력입니다'.tr : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: descCtrl,
          enabled: isEditing,
          decoration: InputDecoration(labelText: '설정 설명'.tr),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: rosDomainCtrl,
                enabled: isEditing,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'ROS 2 Domain ID (ROS_DOMAIN_ID) *'.tr,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return '필수 입력입니다'.tr;
                  final parsed = int.tryParse(val);
                  if (parsed == null || parsed < 0 || parsed > 232) {
                    return '0 ~ 232 사이의 정수만 허용됩니다'.tr;
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: agentIdCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '에이전트 ID (agent_id)'.tr,
                  hintText: '예: Former0047'.tr,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CheckboxListTile(
                title: Text(
                  'ROS 2 Debug 로깅 활성화'.tr,
                  style: const TextStyle(fontSize: 14),
                ),
                value: debug,
                onChanged: isEditing ? (val) => onDebugChanged(val!) : null,
                fillColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.primary,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 16),
            const Spacer(),
          ],
        ),
      ],
    );
  }
}
