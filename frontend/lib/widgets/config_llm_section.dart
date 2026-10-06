import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';
import 'ollama_guide.dart';

class ConfigLlmSection extends StatelessWidget {
  final bool isEditing;
  final String llmProvider;
  final TextEditingController llmModelCtrl;
  final TextEditingController azureEndpointCtrl;
  final TextEditingController azureApiKeyCtrl;
  final TextEditingController openaiApiKeyCtrl;
  final TextEditingController anthropicApiKeyCtrl;
  final TextEditingController ollamaBaseUrlCtrl;
  final TextEditingController ollamaNumCtxCtrl;
  final TextEditingController ollamaTemperatureCtrl;
  final TextEditingController ollamaRepeatPenaltyCtrl;
  final TextEditingController ollamaRepeatLastNCtrl;
  final TextEditingController ollamaSeedCtrl;
  final TextEditingController ollamaNumPredictCtrl;
  final TextEditingController ollamaTopKCtrl;
  final TextEditingController ollamaTopPCtrl;
  final TextEditingController ollamaMinPCtrl;
  // think: unset|false|true|low|medium|high|max (Ollama API 최상위 파라미터)
  final String ollamaThink;
  final ValueChanged<String?> onOllamaThinkChanged;
  final ValueChanged<String?> onProviderChanged;
  final VoidCallback onApplyOllamaTemplate;

  const ConfigLlmSection({
    super.key,
    required this.isEditing,
    required this.llmProvider,
    required this.llmModelCtrl,
    required this.azureEndpointCtrl,
    required this.azureApiKeyCtrl,
    required this.openaiApiKeyCtrl,
    required this.anthropicApiKeyCtrl,
    required this.ollamaBaseUrlCtrl,
    required this.ollamaNumCtxCtrl,
    required this.ollamaTemperatureCtrl,
    required this.ollamaRepeatPenaltyCtrl,
    required this.ollamaRepeatLastNCtrl,
    required this.ollamaSeedCtrl,
    required this.ollamaNumPredictCtrl,
    required this.ollamaTopKCtrl,
    required this.ollamaTopPCtrl,
    required this.ollamaMinPCtrl,
    required this.ollamaThink,
    required this.onOllamaThinkChanged,
    required this.onProviderChanged,
    required this.onApplyOllamaTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('2. LLM 및 클라우드 API 자격 증명'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('llm_provider_$llmProvider'),
                initialValue: llmProvider,
                decoration: InputDecoration(labelText: 'LLM 제공자 (Provider)'.tr),
                items: ['azure', 'openai', 'anthropic', 'ollama']
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: isEditing ? onProviderChanged : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: llmModelCtrl,
                enabled: isEditing,
                decoration: InputDecoration(labelText: '모델명 (llm_model)'.tr),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (llmProvider == 'azure') ...[
          TextFormField(
            controller: azureEndpointCtrl,
            enabled: isEditing,
            decoration: const InputDecoration(labelText: 'Azure Endpoint URL'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: azureApiKeyCtrl,
            enabled: isEditing,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Azure API Key'),
          ),
        ] else if (llmProvider == 'openai') ...[
          TextFormField(
            controller: openaiApiKeyCtrl,
            enabled: isEditing,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'OpenAI API Key'),
          ),
        ] else if (llmProvider == 'anthropic') ...[
          TextFormField(
            controller: anthropicApiKeyCtrl,
            enabled: isEditing,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Anthropic API Key'),
          ),
        ] else if (llmProvider == 'ollama') ...[
          TextFormField(
            controller: ollamaBaseUrlCtrl,
            enabled: isEditing,
            decoration: InputDecoration(
              labelText: 'Ollama Base URL (예: http://localhost:11434)'.tr,
            ),
          ),
          const SizedBox(height: 16),
          _OllamaOptionsEditor(
            isEditing: isEditing,
            numCtxCtrl: ollamaNumCtxCtrl,
            temperatureCtrl: ollamaTemperatureCtrl,
            repeatPenaltyCtrl: ollamaRepeatPenaltyCtrl,
            repeatLastNCtrl: ollamaRepeatLastNCtrl,
            seedCtrl: ollamaSeedCtrl,
            numPredictCtrl: ollamaNumPredictCtrl,
            topKCtrl: ollamaTopKCtrl,
            topPCtrl: ollamaTopPCtrl,
            minPCtrl: ollamaMinPCtrl,
            thinkValue: ollamaThink,
            onThinkChanged: onOllamaThinkChanged,
          ),
          const SizedBox(height: 8),
          OllamaGuidePanel(
            isEditing: isEditing,
            onApplyTemplate: onApplyOllamaTemplate,
          ),
        ],
      ],
    );
  }
}

class _OllamaOptionsEditor extends StatelessWidget {
  final bool isEditing;
  final TextEditingController numCtxCtrl;
  final TextEditingController temperatureCtrl;
  final TextEditingController repeatPenaltyCtrl;
  final TextEditingController repeatLastNCtrl;
  final TextEditingController seedCtrl;
  final TextEditingController numPredictCtrl;
  final TextEditingController topKCtrl;
  final TextEditingController topPCtrl;
  final TextEditingController minPCtrl;
  final String thinkValue;
  final ValueChanged<String?> onThinkChanged;

  const _OllamaOptionsEditor({
    required this.isEditing,
    required this.numCtxCtrl,
    required this.temperatureCtrl,
    required this.repeatPenaltyCtrl,
    required this.repeatLastNCtrl,
    required this.seedCtrl,
    required this.numPredictCtrl,
    required this.topKCtrl,
    required this.topPCtrl,
    required this.minPCtrl,
    required this.thinkValue,
    required this.onThinkChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          'Ollama Options 상세 설정'.tr,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        tilePadding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                _OptionRow(
                  fields: [
                    _NumberField(
                      controller: numCtxCtrl,
                      label: 'Context 크기 (num_ctx)',
                      enabled: isEditing,
                    ),
                    _NumberField(
                      controller: temperatureCtrl,
                      label: 'Temperature (창의성)',
                      enabled: isEditing,
                      decimal: true,
                    ),
                    _NumberField(
                      controller: repeatPenaltyCtrl,
                      label: 'Repeat Penalty',
                      enabled: isEditing,
                      decimal: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _OptionRow(
                  fields: [
                    _NumberField(
                      controller: repeatLastNCtrl,
                      label: 'Repeat Last N',
                      enabled: isEditing,
                    ),
                    _NumberField(
                      controller: seedCtrl,
                      label: 'Seed (난수 시드)',
                      enabled: isEditing,
                    ),
                    _NumberField(
                      controller: numPredictCtrl,
                      label: 'Max Predict Tokens',
                      enabled: isEditing,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _OptionRow(
                  fields: [
                    _NumberField(
                      controller: topKCtrl,
                      label: 'Top K (필터링)',
                      enabled: isEditing,
                    ),
                    _NumberField(
                      controller: topPCtrl,
                      label: 'Top P (확률 필터링)',
                      enabled: isEditing,
                      decimal: true,
                    ),
                    _NumberField(
                      controller: minPCtrl,
                      label: 'Min P (최소 확률)',
                      enabled: isEditing,
                      decimal: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _OptionRow(
                  fields: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                          'ollama_think_${thinkValue.isEmpty ? 'unset' : thinkValue}',
                        ),
                        initialValue: thinkValue.isEmpty ? 'unset' : thinkValue,
                        decoration: InputDecoration(
                          labelText: 'Think (Qwen3 추론 단계)'.tr,
                          helperText: 'SLM 지연 시 off 권장. 미설정 시 모델 기본값'.tr,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'unset',
                            child: Text('기본값 (미설정)'.tr),
                          ),
                          DropdownMenuItem(
                            value: 'false',
                            child: Text('off (false) — SLM 권장'.tr),
                          ),
                          const DropdownMenuItem(
                            value: 'true',
                            child: Text('on (true)'),
                          ),
                          const DropdownMenuItem(
                            value: 'low',
                            child: Text('low'),
                          ),
                          const DropdownMenuItem(
                            value: 'medium',
                            child: Text('medium'),
                          ),
                          const DropdownMenuItem(
                            value: 'high',
                            child: Text('high'),
                          ),
                          const DropdownMenuItem(
                            value: 'max',
                            child: Text('max'),
                          ),
                        ],
                        onChanged: isEditing ? onThinkChanged : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final List<Widget> fields;

  const _OptionRow({required this.fields});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          Expanded(child: fields[i]),
          if (i != fields.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool decimal;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.enabled,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      decoration: InputDecoration(labelText: label.tr),
    );
  }
}
