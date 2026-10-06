import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

/// Maestro FleetControl outbound connector 설정 섹션 (contract v2.2.0).
class ConfigFleetSection extends StatelessWidget {
  final bool isEditing;
  final TextEditingController maestroIpCtrl;
  final TextEditingController robotPortCtrl;
  final TextEditingController robotIdCtrl;
  final TextEditingController robotSiteIdCtrl;
  final TextEditingController robotMapIdCtrl;
  final TextEditingController robotMapVersionCtrl;
  final TextEditingController robotMapFrameIdCtrl;
  final String disconnectPolicy;
  final ValueChanged<String?> onDisconnectPolicyChanged;
  final TextEditingController heartbeatSecCtrl;
  final TextEditingController commandJournalPathCtrl;
  final TextEditingController skillsGuideFileCtrl;
  final bool controlTls;
  final ValueChanged<bool> onControlTlsChanged;
  final TextEditingController controlCaCertCtrl;
  final TextEditingController controlClientCertCtrl;
  final TextEditingController controlClientKeyCtrl;

  const ConfigFleetSection({
    super.key,
    required this.isEditing,
    required this.maestroIpCtrl,
    required this.robotPortCtrl,
    required this.robotIdCtrl,
    required this.robotSiteIdCtrl,
    required this.robotMapIdCtrl,
    required this.robotMapVersionCtrl,
    required this.robotMapFrameIdCtrl,
    required this.disconnectPolicy,
    required this.onDisconnectPolicyChanged,
    required this.heartbeatSecCtrl,
    required this.commandJournalPathCtrl,
    required this.skillsGuideFileCtrl,
    required this.controlTls,
    required this.onControlTlsChanged,
    required this.controlCaCertCtrl,
    required this.controlClientCertCtrl,
    required this.controlClientKeyCtrl,
  });

  static const _disconnectPolicies = <String>[
    'complete',
    'stop',
    'finish_atomic',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('Maestro FleetControl 연동'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: maestroIpCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: 'Maestro 서버 IP (MAESTRO_IP)'.tr,
                  hintText: '10.0.0.5',
                  helperText: '비워두면 fleet outbound connector 비활성'.tr,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: robotPortCtrl,
                enabled: isEditing,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Maestro 서버 포트 (ROBOT_PORT)'.tr,
                  hintText: '50053',
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
                controller: robotIdCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '로봇 ID (ROBOT_ID)'.tr,
                  hintText: 'butler-01',
                  helperText: 'MAESTRO_IP 설정 시 필수'.tr,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: robotSiteIdCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '사이트 ID (ROBOT_SITE_ID)'.tr,
                  hintText: 'site-a',
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
                controller: robotMapIdCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '맵 ID (ROBOT_MAP_ID)'.tr,
                  hintText: '1f',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: robotMapVersionCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '맵 버전 (ROBOT_MAP_VERSION)'.tr,
                  hintText: 'v3',
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
                controller: robotMapFrameIdCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '맵 TF frame (ROBOT_MAP_FRAME_ID)'.tr,
                  hintText: 'map',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('maestro_disconnect_policy_$disconnectPolicy'),
                initialValue: _disconnectPolicies.contains(disconnectPolicy)
                    ? disconnectPolicy
                    : 'complete',
                decoration: InputDecoration(
                  labelText: '연결 단절 정책 (MAESTRO_DISCONNECT_POLICY)'.tr,
                ),
                items: _disconnectPolicies
                    .map(
                      (policy) =>
                          DropdownMenuItem(value: policy, child: Text(policy)),
                    )
                    .toList(),
                onChanged: isEditing ? onDisconnectPolicyChanged : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: heartbeatSecCtrl,
                enabled: isEditing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: '하트비트 주기(초) (FLEET_HEARTBEAT_SEC)'.tr,
                  hintText: '1.0',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: commandJournalPathCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '명령 저널 경로 (FLEET_COMMAND_JOURNAL_PATH)'.tr,
                  hintText: '/tmp/robo_claw_fleet_commands.sqlite3',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: skillsGuideFileCtrl,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: '스킬 가이드 파일 (RC_SKILLS_GUIDE_FILE)'.tr,
            hintText: '/etc/robo/skills.md',
            helperText: '비워두면 배포 기본 경로(config/SKILLS.md) 사용'.tr,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Switch(
              value: controlTls,
              onChanged: isEditing ? onControlTlsChanged : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('FleetControl mTLS 활성화 (FLEET_CONTROL_TLS)'.tr),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controlCaCertCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: 'CA 인증서 (FLEET_CONTROL_CA_CERT)'.tr,
                  hintText: '/etc/robo/ca.pem',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: controlClientCertCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '클라이언트 인증서 (FLEET_CONTROL_CLIENT_CERT)'.tr,
                  hintText: '/etc/robo/client.pem',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: controlClientKeyCtrl,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: '클라이언트 키 (FLEET_CONTROL_CLIENT_KEY)'.tr,
            hintText: '/etc/robo/client.key',
          ),
        ),
      ],
    );
  }
}
