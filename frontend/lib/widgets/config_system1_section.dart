import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

/// System 1 Fast Router settings exposed by the shared runtime contract.
///
/// SYSTEM1_ROUTER 만 필수이고 나머지 필드는 선택 사항이므로,
/// 선택 필드 라벨에는 `선택`과 contract 기본값을 함께 표시한다.
class ConfigSystem1Section extends StatelessWidget {
  final bool isEditing;
  final String router;
  final ValueChanged<String?> onRouterChanged;
  final bool shadow;
  final ValueChanged<bool> onShadowChanged;
  final TextEditingController shadowLogCtrl;
  final String scope;
  final ValueChanged<String?> onScopeChanged;
  final TextEditingController endpointCtrl;
  final TextEditingController providerCtrl;
  final TextEditingController timeoutMsCtrl;
  final TextEditingController confThresholdsJsonCtrl;
  final TextEditingController skillsCtrl;
  final TextEditingController maxOptionsCtrl;
  final TextEditingController apiKeyCtrl;

  const ConfigSystem1Section({
    super.key,
    required this.isEditing,
    required this.router,
    required this.onRouterChanged,
    required this.shadow,
    required this.onShadowChanged,
    required this.shadowLogCtrl,
    required this.scope,
    required this.onScopeChanged,
    required this.endpointCtrl,
    required this.providerCtrl,
    required this.timeoutMsCtrl,
    required this.confThresholdsJsonCtrl,
    required this.skillsCtrl,
    required this.maxOptionsCtrl,
    required this.apiKeyCtrl,
  });

  static const _routers = ['rule', 'laya'];
  static const _scopes = ['readonly', 'navigation'];

  @override
  Widget build(BuildContext context) {
    final selectedRouter = _routers.contains(router) ? router : 'rule';
    final selectedScope = _scopes.contains(scope) ? scope : 'readonly';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('System 1 Fast Router'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: selectedRouter,
          decoration: InputDecoration(
            labelText: 'System 1 router (SYSTEM1_ROUTER) *'.tr,
          ),
          items: _routers
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: isEditing ? onRouterChanged : null,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Shadow mode (SYSTEM1_SHADOW, 선택, 기본: false)'.tr),
          value: shadow,
          onChanged: isEditing ? onShadowChanged : null,
        ),
        TextFormField(
          controller: shadowLogCtrl,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: 'Shadow log path (SYSTEM1_SHADOW_LOG, 선택, 기본: 없음)'.tr,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: selectedScope,
          decoration: InputDecoration(
            labelText: 'System 1 scope (SYSTEM1_SCOPE, 선택, 기본: readonly)'.tr,
          ),
          items: _scopes
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: isEditing ? onScopeChanged : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: endpointCtrl,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: 'System 1 endpoint (SYSTEM1_ENDPOINT, 선택, 기본: 없음)'.tr,
            hintText: 'http://localhost:8000',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: providerCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText:
                      'System 1 provider (SYSTEM1_PROVIDER, 선택, 기본: laya)'.tr,
                  hintText: 'laya',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: timeoutMsCtrl,
                enabled: isEditing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Timeout ms (SYSTEM1_TIMEOUT_MS, 선택, 기본: 300)'.tr,
                  hintText: '300',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: confThresholdsJsonCtrl,
          enabled: isEditing,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText:
                'Confidence thresholds JSON (SYSTEM1_CONF_THRESHOLDS_JSON, 선택, 기본: intent별 기본 임계치)'
                    .tr,
            helperText: 'Intent별 confidence threshold를 JSON 객체로 지정합니다.'.tr,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: skillsCtrl,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: 'Candidate skills (SYSTEM1_SKILLS, 선택, 기본: 자동 선택)'.tr,
            helperText: '비워두면 조건에 맞는 읽기 전용 스킬을 자동 선택합니다.'.tr,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: maxOptionsCtrl,
          enabled: isEditing,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Max options (SYSTEM1_MAX_OPTIONS, 선택, 기본: 12)'.tr,
            hintText: '12',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: apiKeyCtrl,
          enabled: isEditing,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'System 1 API Key (SYSTEM1_API_KEY, 선택, 기본: 없음)'.tr,
            helperText: 'Hosted provider가 인증을 요구할 때만 지정합니다.'.tr,
          ),
        ),
      ],
    );
  }
}
