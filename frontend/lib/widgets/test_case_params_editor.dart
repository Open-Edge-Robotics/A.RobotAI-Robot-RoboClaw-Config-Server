import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/scenario_model.dart';
import '../utils/localization.dart';

class TestCaseParamsEditor extends StatelessWidget {
  final TestCase testCase;
  final bool isEditing;
  final ValueChanged<TestCase> onChanged;

  const TestCaseParamsEditor({
    super.key,
    required this.testCase,
    required this.isEditing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (testCase.type) {
      case 'navigation':
        return _NavigationParamsEditor(
          testCase: testCase,
          isEditing: isEditing,
          onChanged: onChanged,
        );
      case 'persona':
        return _PromptParamsEditor(
          testCase: testCase,
          isEditing: isEditing,
          onChanged: onChanged,
          label: 'LLM 검증 프롬프트 (prompt)',
        );
      case 'custom':
        return _CustomParamsEditor(
          testCase: testCase,
          isEditing: isEditing,
          onChanged: onChanged,
        );
      default:
        return _RawJsonParamsEditor(
          testCase: testCase,
          isEditing: isEditing,
          onChanged: onChanged,
        );
    }
  }
}

class _NavigationParamsEditor extends StatelessWidget {
  final TestCase testCase;
  final bool isEditing;
  final ValueChanged<TestCase> onChanged;

  const _NavigationParamsEditor({
    required this.testCase,
    required this.isEditing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final mode = testCase.params['mode']?.toString() ?? 'guardrail';
    final speed = testCase.params['speed']?.toString() ?? '0.05';
    final command = testCase.params['command']?.toString() ?? '';

    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: mode == 'guardrail' || mode == 'motion'
              ? mode
              : 'guardrail',
          decoration: InputDecoration(
            labelText: '주행 모드 (mode)'.tr,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          dropdownColor: const Color(0xFF2A2A2A),
          items: [
            DropdownMenuItem(
              value: 'guardrail',
              child: Text('guardrail (가드레일 속도 제한)'.tr),
            ),
            DropdownMenuItem(
              value: 'motion',
              child: Text('motion (자연어 주행 지시)'.tr),
            ),
          ],
          onChanged: isEditing
              ? (val) {
                  if (val != null) {
                    _updateParam('mode', val);
                  }
                }
              : null,
        ),
        if (mode == 'guardrail') ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: speed,
            enabled: isEditing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '제한 속도 (speed - m/s)'.tr,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) =>
                _updateParam('speed', double.tryParse(val) ?? 0.05),
          ),
        ],
        if (mode == 'motion') ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: command,
            enabled: isEditing,
            decoration: InputDecoration(
              labelText: '주행 지시 프롬프트 (command)'.tr,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) => _updateParam('command', val),
          ),
        ],
      ],
    );
  }

  void _updateParam(String key, Object value) {
    final updatedParams = Map<String, dynamic>.from(testCase.params)
      ..[key] = value;
    onChanged(testCase..params = updatedParams);
  }
}

class _PromptParamsEditor extends StatelessWidget {
  final TestCase testCase;
  final bool isEditing;
  final ValueChanged<TestCase> onChanged;
  final String label;

  const _PromptParamsEditor({
    required this.testCase,
    required this.isEditing,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final prompt = testCase.params['prompt']?.toString() ?? '';
    return TextFormField(
      initialValue: prompt,
      enabled: isEditing,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: label.tr,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (val) {
        final updatedParams = Map<String, dynamic>.from(testCase.params)
          ..['prompt'] = val;
        onChanged(testCase..params = updatedParams);
      },
    );
  }
}

class _CustomParamsEditor extends StatelessWidget {
  final TestCase testCase;
  final bool isEditing;
  final ValueChanged<TestCase> onChanged;

  const _CustomParamsEditor({
    required this.testCase,
    required this.isEditing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final expectSuccess = testCase.params['expect_success'] is bool
        ? testCase.params['expect_success'] as bool
        : true;
    final expectedKeywords = _stringListParam('expected_keywords');
    final failKeywords = _stringListParam('fail_keywords');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PromptParamsEditor(
          testCase: testCase,
          isEditing: isEditing,
          onChanged: onChanged,
          label: '프롬프트 입력 (prompt) *',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '성공 기대 여부 (expect_success): '.tr,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey
                    : const Color(0xFF334155),
              ),
            ),
            Switch(
              value: expectSuccess,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: isEditing
                  ? (val) => _updateParam('expect_success', val)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _KeywordField(
          label: '포함될 키워드 목록 (expected_keywords - 쉼표로 구분)'.tr,
          initialKeywords: expectedKeywords,
          enabled: isEditing,
          onChanged: (keywords) => _updateParam('expected_keywords', keywords),
        ),
        const SizedBox(height: 12),
        _KeywordField(
          label: '포함되지 않아야 할 키워드 목록 (fail_keywords - 쉼표로 구분)'.tr,
          initialKeywords: failKeywords,
          enabled: isEditing,
          onChanged: (keywords) => _updateParam('fail_keywords', keywords),
        ),
      ],
    );
  }

  List<String> _stringListParam(String key) {
    final value = testCase.params[key];
    return value is List ? List<String>.from(value) : <String>[];
  }

  void _updateParam(String key, Object value) {
    final updatedParams = Map<String, dynamic>.from(testCase.params)
      ..[key] = value;
    onChanged(testCase..params = updatedParams);
  }
}

class _KeywordField extends StatelessWidget {
  final String label;
  final List<String> initialKeywords;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;

  const _KeywordField({
    required this.label,
    required this.initialKeywords,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialKeywords.join(', '),
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        hintText: '키워드1, 키워드2'.tr,
      ),
      onChanged: (val) => onChanged(
        val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      ),
    );
  }
}

class _RawJsonParamsEditor extends StatelessWidget {
  final TestCase testCase;
  final bool isEditing;
  final ValueChanged<TestCase> onChanged;

  const _RawJsonParamsEditor({
    required this.testCase,
    required this.isEditing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rawJson = testCase.params.isNotEmpty
        ? const JsonEncoder().convert(testCase.params)
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이 테스트 유형은 기본적으로 부가 파라미터가 필요하지 않습니다.\n커스텀 매개변수를 추가하려면 아래에 JSON 객체 형식을 입력해 주세요.'
              .tr,
          style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: rawJson,
          enabled: isEditing,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            labelText: '커스텀 매개변수 JSON (params)'.tr,
            border: const OutlineInputBorder(),
            isDense: true,
            hintText: '{"key": "value"}',
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) return null;
            try {
              final decoded = jsonDecode(val);
              if (decoded is! Map) return 'JSON 객체(Map) 형식이어야 합니다.'.tr;
            } catch (e) {
              return 'JSON 문법 오류'.tr;
            }
            return null;
          },
          onChanged: (val) {
            if (val.trim().isEmpty) {
              onChanged(testCase..params = {});
              return;
            }
            try {
              final decoded = jsonDecode(val);
              if (decoded is Map<String, dynamic>) {
                onChanged(testCase..params = decoded);
              }
            } catch (_) {
              // 타이핑 중 일시적인 JSON 문법 오류는 무시하고 저장하지 않음
            }
          },
        ),
      ],
    );
  }
}
