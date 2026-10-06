import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

class ConfigTaskQueueSection extends StatelessWidget {
  final bool isEditing;
  final TextEditingController taskQueueMaxSizeCtrl;
  final bool llmFailFast;
  final ValueChanged<bool> onLlmFailFastChanged;
  final bool strictConfig;
  final ValueChanged<bool> onStrictConfigChanged;
  final bool enableTaskDecomposition;
  final ValueChanged<bool> onEnableTaskDecompositionChanged;
  final TextEditingController taskDecompositionMaxStepsCtrl;
  final TextEditingController taskStepMaxRetriesCtrl;
  final TextEditingController taskDecompositionWaitMarginCapSecCtrl;

  const ConfigTaskQueueSection({
    super.key,
    required this.isEditing,
    required this.taskQueueMaxSizeCtrl,
    required this.llmFailFast,
    required this.onLlmFailFastChanged,
    required this.strictConfig,
    required this.onStrictConfigChanged,
    required this.enableTaskDecomposition,
    required this.onEnableTaskDecompositionChanged,
    required this.taskDecompositionMaxStepsCtrl,
    required this.taskStepMaxRetriesCtrl,
    required this.taskDecompositionWaitMarginCapSecCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('11. 태스크 큐 / 복합 명령 자동 분해 설정'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: taskQueueMaxSizeCtrl,
                enabled: isEditing,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '태스크 큐 최대 대기열 크기 (RC_TASK_QUEUE_MAX_SIZE)'.tr,
                  hintText: '예: 8 (0=큐 비활성화)'.tr,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Switch(
              value: llmFailFast,
              onChanged: isEditing ? onLlmFailFastChanged : null,
            ),
            const SizedBox(width: 8),
            Text('시작 시 LLM 검증 실패 기동 중단 (RC_LLM_FAIL_FAST)'.tr),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              value: strictConfig,
              onChanged: isEditing ? onStrictConfigChanged : null,
            ),
            const SizedBox(width: 8),
            Text('필수 설정 파일 누락 시 기동 중단 (RC_STRICT_CONFIG)'.tr),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Switch(
              value: enableTaskDecomposition,
              onChanged: isEditing ? onEnableTaskDecompositionChanged : null,
            ),
            const SizedBox(width: 8),
            Text('복합 명령 자동 분해 활성화 (RC_ENABLE_TASK_DECOMPOSITION)'.tr),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: taskDecompositionMaxStepsCtrl,
                enabled: isEditing && enableTaskDecomposition,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '분해 최대 단계 수 (RC_TASK_DECOMPOSITION_MAX_STEPS)'.tr,
                  hintText: '예: 6'.tr,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: taskStepMaxRetriesCtrl,
                enabled: isEditing && enableTaskDecomposition,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '단계 실패 재시도 횟수 (RC_TASK_STEP_MAX_RETRIES)'.tr,
                  hintText: '예: 1'.tr,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: taskDecompositionWaitMarginCapSecCtrl,
                enabled: isEditing && enableTaskDecomposition,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      '액션 대기 여유 시간 상한(초) (RC_TASK_DECOMPOSITION_WAIT_MARGIN_CAP_SEC)'
                          .tr,
                  hintText: '예: 1800.0 (30분)'.tr,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
