import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

class ConfigPathSection extends StatelessWidget {
  final bool isEditing;
  final TextEditingController agentWorkspaceDirCtrl;
  final TextEditingController butlerScriptsDirCtrl;
  final TextEditingController butlerSourceDirCtrl;
  final TextEditingController configDirCtrl;
  final TextEditingController systemPromptFileCtrl;
  final TextEditingController robotDescriptionFileCtrl;

  const ConfigPathSection({
    super.key,
    required this.isEditing,
    required this.agentWorkspaceDirCtrl,
    required this.butlerScriptsDirCtrl,
    required this.butlerSourceDirCtrl,
    required this.configDirCtrl,
    required this.systemPromptFileCtrl,
    required this.robotDescriptionFileCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('6. 로컬 환경 경로 및 리소스 설정'),
        const SizedBox(height: 12),
        _FieldRow(
          children: [
            _TextField(
              controller: agentWorkspaceDirCtrl,
              enabled: isEditing,
              label: '에이전트 작업 공간 호스트 디렉토리 (RC_AGENT_WORKSPACE_DIR)',
            ),
            _TextField(
              controller: configDirCtrl,
              enabled: isEditing,
              label: '로봇 설정 호스트 디렉토리 (RC_CONFIG_DIR)',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FieldRow(
          children: [
            _TextField(
              controller: butlerScriptsDirCtrl,
              enabled: isEditing,
              label: 'Butler 스크립트 디렉토리 (RC_BUTLER_SCRIPTS_DIR)',
              hint:
                  '/home/seoyc/Workspace/ros/butler/products/prd_butler_v01_magok_w02/script',
            ),
            _TextField(
              controller: butlerSourceDirCtrl,
              enabled: isEditing,
              label: 'Butler 소싱 워크스페이스 (RC_BUTLER_SOURCE_DIR)',
              hint: '/home/udr/workspace/butler_v01_config/cloi2_ws',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FieldRow(
          children: [
            _TextField(
              controller: systemPromptFileCtrl,
              enabled: isEditing,
              label: '시스템 프롬프트 파일 경로 (RC_SYSTEM_PROMPT_FILE)',
            ),
            _TextField(
              controller: robotDescriptionFileCtrl,
              enabled: isEditing,
              label: '로봇 URDF 설명 파일 경로 (RC_ROBOT_DESCRIPTION_FILE)',
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  final List<Widget> children;

  const _FieldRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String? hint;

  const _TextField({
    required this.controller,
    required this.enabled,
    required this.label,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(labelText: label.tr, hintText: hint),
    );
  }
}
