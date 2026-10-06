import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';
import 'grpc_peers_input_form.dart';

class ConfigMessengerSection extends StatelessWidget {
  final bool isEditing;
  final bool enableDiscord;
  final bool enableSlack;
  final bool enableTelegram;
  final bool enableGrpc;
  final bool useGrpc;
  final bool enableGrpcClient;
  final ValueChanged<bool> onDiscordChanged;
  final ValueChanged<bool> onSlackChanged;
  final ValueChanged<bool> onTelegramChanged;
  final ValueChanged<bool> onGrpcChanged;
  final ValueChanged<bool> onUseGrpcChanged;
  final ValueChanged<bool> onGrpcClientChanged;
  final TextEditingController discordTokenCtrl;
  final TextEditingController slackAppTokenCtrl;
  final TextEditingController slackBotTokenCtrl;
  final TextEditingController telegramTokenCtrl;
  final TextEditingController grpcTargetHostCtrl;
  final TextEditingController grpcTargetPortCtrl;
  final TextEditingController grpcTargetPeersJsonCtrl;
  final TextEditingController grpcPeerTokenCtrl;
  final TextEditingController grpcPortCtrl;

  const ConfigMessengerSection({
    super.key,
    required this.isEditing,
    required this.enableDiscord,
    required this.enableSlack,
    required this.enableTelegram,
    required this.enableGrpc,
    required this.useGrpc,
    required this.enableGrpcClient,
    required this.onDiscordChanged,
    required this.onSlackChanged,
    required this.onTelegramChanged,
    required this.onGrpcChanged,
    required this.onUseGrpcChanged,
    required this.onGrpcClientChanged,
    required this.discordTokenCtrl,
    required this.slackAppTokenCtrl,
    required this.slackBotTokenCtrl,
    required this.telegramTokenCtrl,
    required this.grpcTargetHostCtrl,
    required this.grpcTargetPortCtrl,
    required this.grpcTargetPeersJsonCtrl,
    required this.grpcPeerTokenCtrl,
    required this.grpcPortCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('4. 메신저 & 통신 데몬'),
        const SizedBox(height: 8),
        Row(
          children: [
            _ToggleTile(
              title: 'Discord',
              value: enableDiscord,
              enabled: isEditing,
              onChanged: onDiscordChanged,
            ),
            _ToggleTile(
              title: 'Slack',
              value: enableSlack,
              enabled: isEditing,
              onChanged: onSlackChanged,
            ),
            _ToggleTile(
              title: 'Telegram',
              value: enableTelegram,
              enabled: isEditing,
              onChanged: onTelegramChanged,
            ),
            _ToggleTile(
              title: 'gRPC Server',
              value: enableGrpc,
              enabled: isEditing,
              onChanged: onGrpcChanged,
            ),
          ],
        ),
        Row(
          children: [
            _ToggleTile(
              title: 'gRPC Telemetry (RosGrpc)',
              value: useGrpc,
              enabled: isEditing,
              onChanged: onUseGrpcChanged,
            ),
            _ToggleTile(
              title: 'gRPC Client (동료 로봇)',
              value: enableGrpcClient,
              enabled: isEditing,
              onChanged: onGrpcClientChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (enableDiscord) ...[
          _SecretField(
            controller: discordTokenCtrl,
            enabled: isEditing,
            label: 'Discord Bot Token',
          ),
          const SizedBox(height: 16),
        ],
        if (enableSlack) ...[
          Row(
            children: [
              Expanded(
                child: _SecretField(
                  controller: slackAppTokenCtrl,
                  enabled: isEditing,
                  label: 'Slack App Token (xapp-...)',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SecretField(
                  controller: slackBotTokenCtrl,
                  enabled: isEditing,
                  label: 'Slack Bot Token (xoxb-...)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (enableTelegram) ...[
          _SecretField(
            controller: telegramTokenCtrl,
            enabled: isEditing,
            label: 'Telegram Bot Token',
          ),
          const SizedBox(height: 16),
        ],
        if (enableGrpc) ...[
          Row(
            children: [
              Expanded(
                child: _SecretField(
                  controller: grpcPeerTokenCtrl,
                  enabled: isEditing,
                  label: 'gRPC Peer Token (GRPC_PEER_TOKEN — 외부 접속 시 필수)',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: grpcPortCtrl,
                  enabled: isEditing,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'gRPC Server Port (ROBO_CLAW_GRPC_PORT)',
                    helperText: '기본 50052 — 50051은 RosGrpc 텔레메트리 전용',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (enableGrpcClient) ...[
          GrpcPeersInputForm(
            controller: grpcTargetPeersJsonCtrl,
            isEditing: isEditing,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CheckboxListTile(
        title: Text(title.tr, style: const TextStyle(fontSize: 14)),
        value: value,
        onChanged: enabled ? (val) => onChanged(val!) : null,
        fillColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.primary,
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _SecretField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String label;

  const _SecretField({
    required this.controller,
    required this.enabled,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: true,
      decoration: InputDecoration(labelText: label),
    );
  }
}
