import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

class ConfigRagSection extends StatelessWidget {
  final bool isEditing;
  final bool enableRag;
  final ValueChanged<bool> onEnableRagChanged;
  final TextEditingController embeddingModelCtrl;
  final TextEditingController embeddingProviderCtrl;
  final TextEditingController embeddingBaseUrlCtrl;
  final TextEditingController embeddingApiKeyCtrl;
  final TextEditingController vectorBackendCtrl;
  final TextEditingController qdrantUrlCtrl;
  final TextEditingController qdrantCollCtrl;
  final TextEditingController qdrantApiKeyCtrl;
  final TextEditingController qdrantTimeoutSecCtrl;
  final TextEditingController ragTopKCtrl;
  final TextEditingController ragScoreThresholdCtrl;
  final bool ragLocalMirror;
  final ValueChanged<bool> onRagLocalMirrorChanged;
  final TextEditingController memoryDirCtrl;

  const ConfigRagSection({
    super.key,
    required this.isEditing,
    required this.enableRag,
    required this.onEnableRagChanged,
    required this.embeddingModelCtrl,
    required this.embeddingProviderCtrl,
    required this.embeddingBaseUrlCtrl,
    required this.embeddingApiKeyCtrl,
    required this.vectorBackendCtrl,
    required this.qdrantUrlCtrl,
    required this.qdrantCollCtrl,
    required this.qdrantApiKeyCtrl,
    required this.qdrantTimeoutSecCtrl,
    required this.ragTopKCtrl,
    required this.ragScoreThresholdCtrl,
    required this.ragLocalMirror,
    required this.onRagLocalMirrorChanged,
    required this.memoryDirCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('3. RAG 및 벡터 DB 설정'),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text('RAG (Retrieval-Augmented Generation) 활성화'.tr),
          value: enableRag,
          onChanged: isEditing ? onEnableRagChanged : null,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: Theme.of(context).colorScheme.primary,
        ),
        if (enableRag) ...[
          const SizedBox(height: 12),
          _FieldRow(
            children: [
              _TextField(
                controller: embeddingProviderCtrl,
                enabled: isEditing,
                label: '임베딩 Provider (예: openai, azure, ollama)',
              ),
              _TextField(
                controller: embeddingModelCtrl,
                enabled: isEditing,
                label: '임베딩 모델명',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldRow(
            children: [
              _TextField(
                controller: embeddingBaseUrlCtrl,
                enabled: isEditing,
                label: '임베딩 Base URL (선택사항)',
              ),
              _TextField(
                controller: embeddingApiKeyCtrl,
                enabled: isEditing,
                label: '임베딩 API Key (선택사항)',
                obscureText: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldRow(
            children: [
              _TextField(
                controller: vectorBackendCtrl,
                enabled: isEditing,
                label: '벡터 DB 백엔드 (예: qdrant)',
              ),
              const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 16),
          _FieldRow(
            children: [
              _TextField(
                controller: qdrantUrlCtrl,
                enabled: isEditing,
                label: 'Qdrant URL',
              ),
              _TextField(
                controller: qdrantCollCtrl,
                enabled: isEditing,
                label: 'Qdrant Collection 이름',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldRow(
            children: [
              _TextField(
                controller: qdrantApiKeyCtrl,
                enabled: isEditing,
                label: 'Qdrant API Key (선택사항)',
                obscureText: true,
              ),
              _TextField(
                controller: qdrantTimeoutSecCtrl,
                enabled: isEditing,
                label: 'Qdrant 타임아웃 (초, 기본: 5.0)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldRow(
            children: [
              _TextField(
                controller: ragTopKCtrl,
                enabled: isEditing,
                label: 'RAG Top-K (기본: 2)',
                keyboardType: TextInputType.number,
              ),
              _TextField(
                controller: ragScoreThresholdCtrl,
                enabled: isEditing,
                label: 'RAG Score 임계값 (0.0~1.0, 기본: 0.7)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text('RAG 로컬 미러 (원격 다운 대비 로컬 동시 저장)'.tr),
            value: ragLocalMirror,
            onChanged: isEditing ? onRagLocalMirrorChanged : null,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: memoryDirCtrl,
            enabled: isEditing,
            decoration: InputDecoration(
              labelText: '메모리/로컬 미러 저장 디렉토리 (RC_MEMORY_DIR)'.tr,
              hintText: '/path/to/memory',
            ),
          ),
        ],
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
  final bool obscureText;
  final TextInputType? keyboardType;

  const _TextField({
    required this.controller,
    required this.enabled,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label.tr),
    );
  }
}
