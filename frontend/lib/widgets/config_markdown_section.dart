import 'package:flutter/material.dart';

import 'config_section_header.dart';
import 'markdown_editor.dart';

class ConfigMarkdownSection extends StatelessWidget {
  final bool isEditing;
  final TextEditingController soulCtrl;
  final TextEditingController skillsCtrl;
  final TextEditingController troubleCtrl;
  final TextEditingController limitsCtrl;

  const ConfigMarkdownSection({
    super.key,
    required this.isEditing,
    required this.soulCtrl,
    required this.skillsCtrl,
    required this.troubleCtrl,
    required this.limitsCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('9. 에이전트 마크다운 & 한계 스펙 정의'),
        const SizedBox(height: 12),
        MarkdownEditorArea(
          isEditing: isEditing,
          soulCtrl: soulCtrl,
          skillsCtrl: skillsCtrl,
          troubleCtrl: troubleCtrl,
          limitsCtrl: limitsCtrl,
        ),
      ],
    );
  }
}
