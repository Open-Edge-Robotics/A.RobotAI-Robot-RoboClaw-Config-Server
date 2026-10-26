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
  final String stepRouting;
  final ValueChanged<String?> onStepRoutingChanged;
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
    required this.stepRouting,
    required this.onStepRoutingChanged,
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
  static const _stepRoutings = ['off', 'shadow', 'on'];

  /// SYSTEM1_SHADOW_LOG 는 켜기/끄기 값이 아니라 파일 경로다.
  /// 실수로 `true`를 넣으면 로봇이 작업 디렉터리에 `true` 파일을 만든다.
  static String? validateShadowLogPath(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    const booleanish = ['true', 'false', 'on', 'off', 'yes', 'no'];
    if (booleanish.contains(text.toLowerCase())) {
      return '파일 경로를 입력하세요 (켜기/끄기 값이 아닙니다)'.tr;
    }
    if (!text.startsWith('/')) {
      return '절대 경로를 입력하세요 (예: /ws/agent_workspace/system1_shadow.jsonl)'.tr;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedRouter = _routers.contains(router) ? router : 'rule';
    final selectedScope = _scopes.contains(scope) ? scope : 'readonly';
    final selectedStepRouting = _stepRoutings.contains(stepRouting)
        ? stepRouting
        : 'shadow';

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
          subtitle: Text(
            '선택되지 않은 라우터(rule ↔ laya)의 판단도 백그라운드로 실행해 비교 기록합니다. 실행에는 영향이 없습니다. rule 모드에서는 System 1 endpoint가 필요합니다.'
                .tr,
          ),
          value: shadow,
          onChanged: isEditing ? onShadowChanged : null,
        ),
        TextFormField(
          controller: shadowLogCtrl,
          enabled: isEditing && shadow,
          validator: validateShadowLogPath,
          decoration: InputDecoration(
            labelText: 'Shadow log path (SYSTEM1_SHADOW_LOG, 선택, 기본: 없음)'.tr,
            hintText: '/ws/agent_workspace/system1_shadow.jsonl',
            helperText:
                'Shadow mode가 켜져 있을 때 비교 기록을 저장할 파일 경로입니다. 비우면 노드 로그에만 남습니다.'
                    .tr,
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
        DropdownButtonFormField<String>(
          initialValue: selectedStepRouting,
          decoration: InputDecoration(
            labelText: 'Step routing (SYSTEM1_STEP_ROUTING, 선택, 기본: shadow)'.tr,
            helperText:
                '복합 명령을 분해한 하위 단계에도 사전 라우터를 적용합니다. off: 모든 단계 LLM, shadow: 판정만 기록, on: 혼자 완결되는 단계를 직접 처리.'
                    .tr,
          ),
          items: _stepRoutings
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: isEditing ? onStepRoutingChanged : null,
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
