import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';
import 'mcp_servers_input_form.dart';

class ConfigMcpSection extends StatelessWidget {
  final bool isEditing;
  final bool enableMcp;
  final ValueChanged<bool> onEnableMcpChanged;
  final TextEditingController mcpServersJsonCtrl;

  const ConfigMcpSection({
    super.key,
    required this.isEditing,
    required this.enableMcp,
    required this.onEnableMcpChanged,
    required this.mcpServersJsonCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('10. MCP(Model Context Protocol) 서버 연동'),
        const SizedBox(height: 8),
        Row(
          children: [
            _ToggleTile(
              title: 'MCP 사용',
              value: enableMcp,
              enabled: isEditing,
              onChanged: onEnableMcpChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (enableMcp) ...[
          McpServersInputForm(
            controller: mcpServersJsonCtrl,
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
