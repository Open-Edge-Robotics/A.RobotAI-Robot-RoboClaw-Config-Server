import 'package:flutter/material.dart';

import '../models/scenario_model.dart';
import '../utils/scenario_editor_utils.dart';
import '../utils/localization.dart';
import 'test_case_list_editor.dart';

class ScenarioDetailPanel extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController robotController;
  final TextEditingController environmentController;
  final TextEditingController descriptionController;
  final TextEditingController scenarioCasesController;
  final List<TestCase> editingTestCases;
  final TestScenario? selectedScenario;
  final bool isEditing;
  final bool isCreatingNewScenario;
  final bool isJsonMode;
  final VoidCallback onBack;
  final VoidCallback onStartEditing;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onSelectGuiEditor;
  final VoidCallback onSelectJsonEditor;
  final ValueChanged<List<TestCase>> onTestCasesChanged;
  final ValueChanged<String> onAddTemplate;

  const ScenarioDetailPanel({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.robotController,
    required this.environmentController,
    required this.descriptionController,
    required this.scenarioCasesController,
    required this.editingTestCases,
    required this.selectedScenario,
    required this.isEditing,
    required this.isCreatingNewScenario,
    required this.isJsonMode,
    required this.onBack,
    required this.onStartEditing,
    required this.onSave,
    required this.onCancel,
    required this.onSelectGuiEditor,
    required this.onSelectJsonEditor,
    required this.onTestCasesChanged,
    required this.onAddTemplate,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedScenario == null && !isCreatingNewScenario) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_play,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey
                  : const Color(0xFF334155),
            ),
            const SizedBox(height: 16),
            Text(
              '조회할 테스트 시나리오를 선택하거나 추가 버튼을 누르세요.'.tr,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey
                    : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      );
    }

    final titleText = isCreatingNewScenario
        ? '신규 테스트 시나리오 추가'.tr
        : '${selectedScenario?.name} ${"시나리오 상세".tr}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF161616)
            : const Color(0xFFFFFFFF),
        elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 1,
        title: Text(
          titleText,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF0F172A),
          ),
        ),
        leading: MediaQuery.of(context).size.width <= 900
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF0F172A),
                ),
                onPressed: onBack,
              )
            : null,
        actions: [
          if (!isEditing)
            ElevatedButton.icon(
              onPressed: onStartEditing,
              icon: const Icon(Icons.edit, size: 16),
              label: Text(
                '편집'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          else ...[
            ElevatedButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save, size: 16),
              label: Text(
                '저장'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : const Color(0xFF334155),
              ),
              child: Text('취소'.tr),
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScenarioSectionHeader(title: '1. 시나리오 정보'.tr),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: nameController,
                      enabled: isEditing,
                      decoration: InputDecoration(labelText: '시나리오 이름 *'.tr),
                      validator: (value) =>
                          value == null || value.isEmpty ? '필수 입력입니다'.tr : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: robotController,
                      enabled: isEditing,
                      decoration: InputDecoration(
                        labelText: '로봇 식별자 (robot_name) *'.tr,
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? '필수 입력입니다'.tr : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: environmentController,
                      enabled: isEditing,
                      decoration: InputDecoration(
                        labelText: '구동 환경 (environment) *'.tr,
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? '필수 입력입니다'.tr : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                enabled: isEditing,
                decoration: InputDecoration(labelText: '시나리오 설명'.tr),
                maxLines: 2,
              ),
              const SizedBox(height: 28),
              _ScenarioSectionHeader(title: '2. 테스트 케이스 목록 정의'.tr),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: Text('GUI 폼 에디터 (권장)'.tr),
                    selected: !isJsonMode,
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: !isJsonMode
                          ? Theme.of(context).colorScheme.primary
                          : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : const Color(0xFF334155)),
                      fontWeight: !isJsonMode
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        onSelectGuiEditor();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('JSON 텍스트 에디터'.tr),
                    selected: isJsonMode,
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isJsonMode
                          ? Theme.of(context).colorScheme.primary
                          : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : const Color(0xFF334155)),
                      fontWeight: isJsonMode
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        onSelectJsonEditor();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!isJsonMode)
                TestCaseListEditor(
                  testCases: editingTestCases,
                  isEditing: isEditing,
                  onChanged: onTestCasesChanged,
                )
              else
                _ScenarioJsonEditor(
                  controller: scenarioCasesController,
                  isEditing: isEditing,
                  onAddTemplate: onAddTemplate,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScenarioJsonEditor extends StatelessWidget {
  final TextEditingController controller;
  final bool isEditing;
  final ValueChanged<String> onAddTemplate;

  const _ScenarioJsonEditor({
    required this.controller,
    required this.isEditing,
    required this.onAddTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpansionTile(
          title: Text(
            '💡 지원되는 테스트 유형 (Type) 및 매개변수 가이드'.tr,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          backgroundColor: Theme.of(context).cardTheme.color,
          collapsedBackgroundColor: Theme.of(context).cardTheme.color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          children: scenarioTestTypeGuideDescriptions.entries
              .map(
                (entry) => _ScenarioTypeGuideItem(
                  type: entry.key,
                  description: entry.value,
                  onTap: () => onAddTemplate(entry.key),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: controller,
          enabled: isEditing,
          maxLines: 30,
          style: TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: const ['NotoSansKR'],
            fontSize: 15,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText:
                '[\n  {\n    "id": "tc_ping",\n    "name": "gRPC Ping 연결성",\n    "step": "Step 1",\n    "type": "ping",\n    "timeout_ms": 3000,\n    "enabled": true\n  }\n]',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFF1F5F9),
            filled: true,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '테스트 케이스 JSON을 입력해 주세요.'.tr;
            }

            try {
              parseScenarioTestCasesJson(value);
            } catch (error) {
              return 'JSON 파싱 에러: '.tr + error.toString();
            }

            return null;
          },
        ),
      ],
    );
  }
}

class _ScenarioSectionHeader extends StatelessWidget {
  final String title;

  const _ScenarioSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: Theme.of(context).dividerColor, height: 1),
      ],
    );
  }
}

class _ScenarioTypeGuideItem extends StatelessWidget {
  final String type;
  final String description;
  final VoidCallback onTap;

  const _ScenarioTypeGuideItem({
    required this.type,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${'클릭하여 에디터 아래에 템플릿 추가'.tr} [$type]',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['NotoSansKR'],
                    fontSize: 13.5,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  description.tr,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey
                        : const Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.add_circle_outline,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
