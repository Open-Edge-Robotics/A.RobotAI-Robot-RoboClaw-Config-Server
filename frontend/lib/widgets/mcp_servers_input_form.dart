import 'package:flutter/material.dart';
import '../models/mcp_server_config.dart';
import '../utils/localization.dart';
import 'mcp_catalog_dialog.dart';

class McpServersInputForm extends StatefulWidget {
  final TextEditingController controller;
  final bool isEditing;

  const McpServersInputForm({
    super.key,
    required this.controller,
    required this.isEditing,
  });

  @override
  State<McpServersInputForm> createState() => _McpServersInputFormState();
}

class _McpServersInputFormState extends State<McpServersInputForm> {
  List<McpServerConfig> _servers = [];
  bool _isUpdatingFromInternal = false;
  int _rebuildCounter = 0;

  @override
  void initState() {
    super.initState();
    _parseFromController();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant McpServersInputForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _parseFromController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (_isUpdatingFromInternal) return;
    setState(() {
      _parseFromController();
    });
  }

  void _parseFromController() {
    _servers = McpServerConfig.parseServersJson(widget.controller.text);
    _rebuildCounter++;
  }

  void _updateController() {
    _isUpdatingFromInternal = true;
    widget.controller.text = McpServerConfig.serializeServersJson(_servers);
    _isUpdatingFromInternal = false;
  }

  void _addServer() {
    setState(() {
      _servers.add(McpServerConfig(name: 'mcp_server_${_servers.length + 1}'));
      _updateController();
    });
  }

  void _removeServer(int index) {
    setState(() {
      _servers.removeAt(index);
      _updateController();
    });
  }

  // 기존 서버 이름과 겹치지 않는 고유 이름을 만든다 (base, base_2, base_3 ...).
  String _uniqueName(String base) {
    final safeBase = base.isEmpty ? 'mcp_server' : base;
    final existing = _servers.map((s) => s.name).toSet();
    if (!existing.contains(safeBase)) return safeBase;
    var i = 2;
    while (existing.contains('${safeBase}_$i')) {
      i++;
    }
    return '${safeBase}_$i';
  }

  // 카탈로그에서 MCP 서버를 검색·선택해 목록에 추가한다.
  Future<void> _browseCatalog() async {
    final entry = await showMcpCatalogDialog(context);
    if (entry == null || !mounted) return;
    setState(() {
      _servers.add(entry.toServerConfig(nameOverride: _uniqueName(entry.name)));
      _updateController();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 서버 구조는 그대로 내려오고 자격 증명(env/headers) 값만 마스킹된다.
    final maskedNotice = McpServerConfig.containsMaskedSecrets(
      widget.controller.text,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MCP 서버 목록'.tr,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        if (maskedNotice)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '보안을 위해 MCP 자격 증명(env/headers) 값은 마스킹되어 있습니다. 마스킹된 값을 그대로 두고 저장하면 기존 값이 유지됩니다.'
                  .tr,
              style: TextStyle(color: Colors.amber.shade200, fontSize: 12),
            ),
          ),
        if (_servers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Center(
              child: Text(
                '등록된 MCP 서버가 없습니다.'.tr,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _servers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final server = _servers[index];
              return _buildServerCard(index, server);
            },
          ),
        const SizedBox(height: 12),
        if (widget.isEditing)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addServer,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('MCP 서버 추가'.tr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _browseCatalog,
                  icon: const Icon(Icons.travel_explore, size: 18),
                  label: Text('MCP 서버 찾아보기'.tr),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildServerCard(int index, McpServerConfig server) {
    return Container(
      key: ValueKey('mcp_server_${_rebuildCounter}_$index'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withAlpha(5)
            : Colors.black.withAlpha(5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${'MCP 서버 #'.tr}${index + 1}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (widget.isEditing)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () => _removeServer(index),
                  tooltip: '삭제'.tr,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: server.name,
                  enabled: widget.isEditing,
                  decoration: InputDecoration(
                    labelText: '서버 이름'.tr,
                    hintText: '예: filesystem'.tr,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    server.name = val;
                    _updateController();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: server.transport,
                  decoration: const InputDecoration(
                    labelText: 'Transport',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'stdio', child: Text('stdio')),
                    DropdownMenuItem(value: 'sse', child: Text('sse')),
                    DropdownMenuItem(
                      value: 'streamable_http',
                      child: Text('streamable_http'),
                    ),
                  ],
                  onChanged: widget.isEditing
                      ? (val) {
                          setState(() {
                            server.transport = val ?? 'stdio';
                            _updateController();
                          });
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (server.transport == 'sse' ||
              server.transport == 'streamable_http')
            _buildHttpFields(server)
          else
            _buildStdioFields(server),
        ],
      ),
    );
  }

  Widget _buildStdioFields(McpServerConfig server) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: server.command,
                enabled: widget.isEditing,
                decoration: InputDecoration(
                  labelText: '실행 명령어 (command)'.tr,
                  hintText: '예: npx'.tr,
                  isDense: true,
                ),
                onChanged: (val) {
                  server.command = val;
                  _updateController();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: server.args.join(', '),
                enabled: widget.isEditing,
                decoration: InputDecoration(
                  labelText: '인자 (args, 쉼표로 구분)'.tr,
                  hintText: '예: -y, @modelcontextprotocol/server-filesystem'.tr,
                  isDense: true,
                ),
                onChanged: (val) {
                  server.args = val
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();
                  _updateController();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: server.cwd,
          enabled: widget.isEditing,
          decoration: InputDecoration(
            labelText: '작업 디렉토리 (cwd, 선택)'.tr,
            isDense: true,
          ),
          onChanged: (val) {
            server.cwd = val;
            _updateController();
          },
        ),
        const SizedBox(height: 12),
        _KeyValueListEditor(
          label: '환경 변수 (env)'.tr,
          entries: server.env,
          enabled: widget.isEditing,
          onChanged: (updated) {
            server.env = updated;
            _updateController();
          },
        ),
      ],
    );
  }

  Widget _buildHttpFields(McpServerConfig server) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: server.url,
          enabled: widget.isEditing,
          decoration: InputDecoration(
            labelText: 'URL',
            hintText: server.transport == 'streamable_http'
                ? '예: https://example.com/mcp'.tr
                : '예: https://example.com/mcp/sse'.tr,
            isDense: true,
          ),
          onChanged: (val) {
            server.url = val;
            _updateController();
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: server.connectTimeoutSec.toString(),
                enabled: widget.isEditing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'connect_timeout_sec',
                  isDense: true,
                ),
                onChanged: (val) {
                  server.connectTimeoutSec = double.tryParse(val) ?? 5.0;
                  _updateController();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: server.readTimeoutSec.toString(),
                enabled: widget.isEditing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'read_timeout_sec',
                  isDense: true,
                ),
                onChanged: (val) {
                  server.readTimeoutSec = double.tryParse(val) ?? 300.0;
                  _updateController();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _KeyValueListEditor(
          label: '헤더 (headers)'.tr,
          entries: server.headers,
          enabled: widget.isEditing,
          onChanged: (updated) {
            server.headers = updated;
            _updateController();
          },
        ),
      ],
    );
  }
}

/// `Map<String, String>`을 key/value 행 목록으로 편집하는 최소 구현 위젯.
class _KeyValueListEditor extends StatefulWidget {
  final String label;
  final Map<String, String> entries;
  final bool enabled;
  final ValueChanged<Map<String, String>> onChanged;

  const _KeyValueListEditor({
    required this.label,
    required this.entries,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_KeyValueListEditor> createState() => _KeyValueListEditorState();
}

class _KeyValueListEditorState extends State<_KeyValueListEditor> {
  late List<MapEntry<String, String>> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.entries.entries.toList();
  }

  @override
  void didUpdateWidget(covariant _KeyValueListEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entries, widget.entries)) {
      _rows = widget.entries.entries.toList();
    }
  }

  void _emit() {
    final map = <String, String>{};
    for (final row in _rows) {
      if (row.key.isNotEmpty) map[row.key] = row.value;
    }
    widget.onChanged(map);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 6),
        for (int i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _rows[i].key,
                    enabled: widget.enabled,
                    decoration: const InputDecoration(
                      labelText: 'key',
                      isDense: true,
                    ),
                    onChanged: (val) {
                      _rows[i] = MapEntry(val, _rows[i].value);
                      _emit();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: _rows[i].value,
                    enabled: widget.enabled,
                    decoration: const InputDecoration(
                      labelText: 'value',
                      isDense: true,
                    ),
                    onChanged: (val) {
                      _rows[i] = MapEntry(_rows[i].key, val);
                      _emit();
                    },
                  ),
                ),
                if (widget.enabled)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _rows.removeAt(i);
                        _emit();
                      });
                    },
                  ),
              ],
            ),
          ),
        if (widget.enabled)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _rows.add(const MapEntry('', ''));
              });
            },
            icon: const Icon(Icons.add, size: 16),
            label: Text('추가'.tr, style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}
