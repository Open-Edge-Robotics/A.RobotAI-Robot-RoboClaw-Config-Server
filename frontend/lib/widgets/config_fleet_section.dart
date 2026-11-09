import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

/// Maestro FleetControl outbound connector 설정 섹션 (contract v2.2.0).
class ConfigFleetSection extends StatelessWidget {
  final bool isEditing;
  final bool maestroEnabled;
  final ValueChanged<bool> onMaestroEnabledChanged;
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
    required this.maestroEnabled,
    required this.onMaestroEnabledChanged,
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
    // 스위치를 끄면 나머지 값은 보존한 채 입력만 잠근다.
    final fieldEnabled = isEditing && maestroEnabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('Maestro FleetControl 연동'),
        const SizedBox(height: 12),
        SwitchListTile(
          key: const ValueKey('maestro_enabled_switch'),
          contentPadding: EdgeInsets.zero,
          title: Text('Maestro 연동 사용 (MAESTRO_ENABLED)'.tr),
          subtitle: Text(
            '끄면 MAESTRO_IP를 지정해도 로봇의 outbound connector를 시작하지 않습니다.'.tr,
          ),
          value: maestroEnabled,
          onChanged: isEditing ? onMaestroEnabledChanged : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: maestroIpCtrl,
                enabled: fieldEnabled,
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
                enabled: fieldEnabled,
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
                enabled: fieldEnabled,
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
                enabled: fieldEnabled,
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
                enabled: fieldEnabled,
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
                enabled: fieldEnabled,
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
                enabled: fieldEnabled,
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
                onChanged: fieldEnabled ? onDisconnectPolicyChanged : null,
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
                enabled: fieldEnabled,
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
                enabled: fieldEnabled,
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
          enabled: fieldEnabled,
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
              onChanged: fieldEnabled ? onControlTlsChanged : null,
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
                enabled: fieldEnabled,
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
                enabled: fieldEnabled,
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
          enabled: fieldEnabled,
          decoration: InputDecoration(
            labelText: '클라이언트 키 (FLEET_CONTROL_CLIENT_KEY)'.tr,
            hintText: '/etc/robo/client.key',
          ),
        ),
      ],
    );
  }
}
