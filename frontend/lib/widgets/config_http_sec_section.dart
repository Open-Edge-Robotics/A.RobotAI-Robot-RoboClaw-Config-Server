import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

class ConfigHttpSecSection extends StatelessWidget {
  final bool isEditing;
  final TextEditingController httpHostCtrl;
  final TextEditingController httpPortCtrl;
  final TextEditingController httpReadonlyTokenCtrl;
  final TextEditingController httpControlTokenCtrl;
  final TextEditingController httpAllowedCidrsCtrl;
  final TextEditingController httpRateLimitCtrl;
  final TextEditingController httpAllowedSkillsCtrl;
  final TextEditingController httpBlockedSkillsCtrl;

  const ConfigHttpSecSection({
    super.key,
    required this.isEditing,
    required this.httpHostCtrl,
    required this.httpPortCtrl,
    required this.httpReadonlyTokenCtrl,
    required this.httpControlTokenCtrl,
    required this.httpAllowedCidrsCtrl,
    required this.httpRateLimitCtrl,
    required this.httpAllowedSkillsCtrl,
    required this.httpBlockedSkillsCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('5. HTTP API 보안 설정'),
        const SizedBox(height: 12),
        _FieldRow(
          children: [
            _TextField(
              controller: httpHostCtrl,
              enabled: isEditing,
              label: 'HTTP 바인딩 호스트 (기본: 127.0.0.1)',
            ),
            _TextField(
              controller: httpPortCtrl,
              enabled: isEditing,
              label: 'HTTP 포트 (기본: 8080)',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FieldRow(
          children: [
            _TextField(
              controller: httpReadonlyTokenCtrl,
              enabled: isEditing,
              label: 'Read-only 접근 토큰 (조회용)',
              obscureText: true,
            ),
            _TextField(
              controller: httpControlTokenCtrl,
              enabled: isEditing,
              label: 'Control 제어 토큰 (기동/정지용)',
              obscureText: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FieldRow(
          children: [
            _TextField(
              controller: httpAllowedCidrsCtrl,
              enabled: isEditing,
              label: '허용 IP 대역 CIDR JSON (예: ["127.0.0.1/32"])',
            ),
            _TextField(
              controller: httpRateLimitCtrl,
              enabled: isEditing,
              label: '분당 요청 제한 (Rate Limit)',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FieldRow(
          children: [
            _TextField(
              controller: httpAllowedSkillsCtrl,
              enabled: isEditing,
              label: '허용 스킬 JSON (빈 배열은 전체 허용)',
            ),
            _TextField(
              controller: httpBlockedSkillsCtrl,
              enabled: isEditing,
              label: '차단 스킬 JSON (예: ["emergency_stop"])',
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
