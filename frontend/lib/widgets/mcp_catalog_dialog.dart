import 'dart:async';
import 'package:flutter/material.dart';

import '../models/mcp_catalog_entry.dart';
import '../services/api_service.dart';
import '../utils/localization.dart';

/// MCP 서버를 검색해 목록으로 보여주고, 선택하면 해당 항목을 반환하는 다이얼로그.
///
/// 사용법:
/// ```dart
/// final entry = await showMcpCatalogDialog(context);
/// if (entry != null) { /* entry.toServerConfig() 로 추가 */ }
/// ```
Future<McpCatalogEntry?> showMcpCatalogDialog(BuildContext context) {
  return showDialog<McpCatalogEntry>(
    context: context,
    builder: (_) => const _McpCatalogDialog(),
  );
}

class _McpCatalogDialog extends StatefulWidget {
  const _McpCatalogDialog();

  @override
  State<_McpCatalogDialog> createState() => _McpCatalogDialogState();
}

class _McpCatalogDialogState extends State<_McpCatalogDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<McpCatalogEntry> _entries = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // 입력 디바운스(300ms) 후 서버 재조회
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _fetch);
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ApiService.fetchMcpCatalog(query: _searchCtrl.text);
      if (!mounted) return;
      setState(() {
        _entries = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.travel_explore,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MCP 서버 찾아보기'.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '닫기'.tr,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '이름/설명으로 검색 (예: git, filesystem)'.tr,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              '카탈로그 조회 실패'.tr,
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('다시 시도'.tr),
            ),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          '검색 결과가 없습니다.'.tr,
          style: const TextStyle(color: Colors.white38),
        ),
      );
    }
    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildEntryTile(_entries[index]),
    );
  }

  Widget _buildEntryTile(McpCatalogEntry entry) {
    final subtitle = <String>[
      if (entry.description.isNotEmpty) entry.description,
      if (entry.transport == 'stdio' && entry.command.isNotEmpty)
        '${entry.command} ${entry.args.join(' ')}'.trim()
      else if ((entry.transport == 'sse' ||
              entry.transport == 'streamable_http') &&
          entry.url.isNotEmpty)
        entry.url,
    ].join('\n');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      title: Row(
        children: [
          Flexible(
            child: Text(
              entry.displayName.isNotEmpty ? entry.displayName : entry.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _chip(entry.transport, color: Theme.of(context).colorScheme.primary),
          if (entry.category.isNotEmpty) ...[
            const SizedBox(width: 4),
            _chip(entry.category, color: Colors.blueGrey),
          ],
        ],
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ),
      trailing: FilledButton.icon(
        onPressed: () => Navigator.of(context).pop(entry),
        icon: const Icon(Icons.add, size: 18),
        label: Text('추가'.tr),
      ),
    );
  }

  Widget _chip(String label, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
