import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

class ConfigLangsmithSection extends StatelessWidget {
  final bool isEditing;
  final bool langsmithTracing;
  final ValueChanged<bool> onLangsmithTracingChanged;
  final TextEditingController langsmithApiKeyCtrl;
  final TextEditingController langsmithProjectCtrl;
  final TextEditingController langsmithEndpointCtrl;
  final TextEditingController langsmithWorkspaceIdCtrl;

  const ConfigLangsmithSection({
    super.key,
    required this.isEditing,
    required this.langsmithTracing,
    required this.onLangsmithTracingChanged,
    required this.langsmithApiKeyCtrl,
    required this.langsmithProjectCtrl,
    required this.langsmithEndpointCtrl,
    required this.langsmithWorkspaceIdCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('LangSmith 트레이싱 / 모니터링'),
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              value: langsmithTracing,
              onChanged: isEditing ? onLangsmithTracingChanged : null,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('LangSmith 트레이싱 활성화 (LANGSMITH_TRACING)'.tr)),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: langsmithApiKeyCtrl,
          enabled: isEditing,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'LangSmith API Key (LANGSMITH_API_KEY)'.tr,
            hintText: 'lsv2_pt_...'.tr,
            helperText: '트레이싱 활성화 시 필수. 미설정 시 트레이스 업로드 안 됨'.tr,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: langsmithProjectCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '프로젝트 이름 (LANGSMITH_PROJECT)'.tr,
                  hintText: 'former-0045-claw',
                  helperText: '선택 — 미설정 시 "default"'.tr,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: langsmithWorkspaceIdCtrl,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: 'Workspace ID (LANGSMITH_WORKSPACE_ID)'.tr,
            hintText: 'workspace-id',
            helperText: '선택 — API Key가 여러 workspace에 접근할 때 지정합니다'.tr,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: langsmithEndpointCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '엔드포인트 (LANGSMITH_ENDPOINT)'.tr,
                  hintText: 'https://api.smith.langchain.com',
                  helperText: '선택 — 자체 호스팅/프록시 엔드포인트'.tr,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
