// frontend/lib/widgets/ollama_guide.dart

import 'package:flutter/material.dart';
import '../utils/localization.dart';

class OllamaGuidePanel extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onApplyTemplate;

  const OllamaGuidePanel({
    super.key,
    required this.isEditing,
    required this.onApplyTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Ollama 옵션 JSON 가이드'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: isEditing ? onApplyTemplate : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  '기본 템플릿 입력'.tr,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _OllamaOptionHelp(
                name: 'num_ctx',
                type: 'int',
                desc: '컨텍스트 윈도우 크기 (기본: 2048)',
              ),
              _OllamaOptionHelp(
                name: 'temperature',
                type: 'float',
                desc: '모델 창의성/무작위성 (기본: 0.8)',
              ),
              _OllamaOptionHelp(
                name: 'num_predict',
                type: 'int',
                desc: '최대 생성 토큰 수 (-1: 무제한)',
              ),
              _OllamaOptionHelp(
                name: 'repeat_penalty',
                type: 'float',
                desc: '반복 토큰 감점 비율 (기본: 1.1)',
              ),
              _OllamaOptionHelp(
                name: 'repeat_last_n',
                type: 'int',
                desc: '반복 방지용 되돌아볼 토큰 수 (기본: 64)',
              ),
              _OllamaOptionHelp(
                name: 'seed',
                type: 'int',
                desc: '출력 고정용 무작위 시드값 (기본: 0)',
              ),
              _OllamaOptionHelp(
                name: 'top_k',
                type: 'int',
                desc: '무의미한 토큰 생성 억제값 (기본: 40)',
              ),
              _OllamaOptionHelp(
                name: 'top_p',
                type: 'float',
                desc: '누적 확률 기반 필터링 비율 (기본: 0.9)',
              ),
              _OllamaOptionHelp(
                name: 'min_p',
                type: 'float',
                desc: '최소 확률 임계치 필터링 (기본: 0.0)',
              ),
              _OllamaOptionHelp(
                name: 'think',
                type: 'bool|str',
                desc:
                    'Qwen3 등 thinking 모델 추론 단계 제어. false=끔(빠름), '
                    'true/low~max=단계. options 와 별개 최상위 파라미터',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OllamaOptionHelp extends StatelessWidget {
  final String name;
  final String type;
  final String desc;

  const _OllamaOptionHelp({
    required this.name,
    required this.type,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280, // 격자 그리드 형태의 정렬을 위해 고정 너비 설정
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '($type)',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey
                      : const Color(0xFF334155),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            desc.tr,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFD0D0D0)
                  : const Color(0xFF334155),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
