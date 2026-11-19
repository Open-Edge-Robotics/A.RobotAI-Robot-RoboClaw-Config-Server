import 'package:material_ui/material_ui.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

class ConfigLangfuseSection extends StatelessWidget {
  final bool isEditing;
  final bool langfuseTracing;
  final ValueChanged<bool> onLangfuseTracingChanged;
  final TextEditingController langfusePublicKeyCtrl;
  final TextEditingController langfuseSecretKeyCtrl;
  final TextEditingController langfuseHostCtrl;

  const ConfigLangfuseSection({
    super.key,
    required this.isEditing,
    required this.langfuseTracing,
    required this.onLangfuseTracingChanged,
    required this.langfusePublicKeyCtrl,
    required this.langfuseSecretKeyCtrl,
    required this.langfuseHostCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('Langfuse 트레이싱 / 모니터링'),
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              value: langfuseTracing,
              onChanged: isEditing ? onLangfuseTracingChanged : null,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('Langfuse 트레이싱 활성화 (LANGFUSE_TRACING)'.tr)),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: langfusePublicKeyCtrl,
          enabled: isEditing,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Public Key (LANGFUSE_PUBLIC_KEY)'.tr,
            hintText: 'pk-lf-...',
            helperText: '트레이싱 활성화 시 필수. 미설정 시 트레이스 업로드 안 됨'.tr,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: langfuseSecretKeyCtrl,
          enabled: isEditing,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Secret Key (LANGFUSE_SECRET_KEY)'.tr,
            hintText: 'sk-lf-...',
            helperText: '트레이싱 활성화 시 필수. 미설정 시 트레이스 업로드 안 됨'.tr,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: langfuseHostCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: 'Host (LANGFUSE_HOST)'.tr,
                  hintText: 'http://192.168.50.47:3000',
                  helperText: '선택 — 자체 호스팅 Langfuse 서버 주소'.tr,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
