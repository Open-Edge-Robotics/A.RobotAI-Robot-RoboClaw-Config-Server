// frontend/lib/widgets/markdown_editor.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/localization.dart';

class MarkdownEditorArea extends StatelessWidget {
  final bool isEditing;
  final TextEditingController soulCtrl;
  final TextEditingController skillsCtrl;
  final TextEditingController troubleCtrl;
  final TextEditingController limitsCtrl;

  const MarkdownEditorArea({
    super.key,
    required this.isEditing,
    required this.soulCtrl,
    required this.skillsCtrl,
    required this.troubleCtrl,
    required this.limitsCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'ROBOT.md (Soul)'),
              Tab(text: 'SKILLS.md (Skills)'),
              Tab(text: 'TROUBLESHOOTING.md'),
              Tab(text: 'ROBOT_LIMITS.json'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor:
                Theme.of(context).brightness == Brightness.dark
                ? Colors.grey
                : const Color(0xFF64748B),
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 400,
            child: TabBarView(
              children: [
                _buildMarkdownEditor(
                  context,
                  soulCtrl,
                  '로봇 개성 및 스타일 정의...',
                  isEditing,
                ),
                _buildMarkdownEditor(
                  context,
                  skillsCtrl,
                  '에이전트 쉘 스크립트 스킬 가이드...',
                  isEditing,
                ),
                _buildMarkdownEditor(
                  context,
                  troubleCtrl,
                  '장애 극복 대응 매뉴얼...',
                  isEditing,
                ),
                _buildMarkdownEditor(
                  context,
                  limitsCtrl,
                  '로봇 가동 제한치 JSON 정의...',
                  isEditing,
                  isJson: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownEditor(
    BuildContext context,
    TextEditingController controller,
    String hint,
    bool enabled, {
    bool isJson = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLines: null,
        minLines: 15,
        keyboardType: TextInputType.multiline,
        style: TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['NotoSansKR'],
          fontSize: 14,
          height: 1.4,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: hint.tr,
          alignLabelWithHint: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A1A)
              : const Color(0xFFF8FAFC),
        ),
        validator: isJson
            ? (val) {
                if (val == null || val.isEmpty) return null;
                try {
                  jsonDecode(val);
                  return null;
                } catch (e) {
                  return '올바르지 않은 JSON 포맷입니다.'.tr;
                }
              }
            : null,
      ),
    );
  }
}
