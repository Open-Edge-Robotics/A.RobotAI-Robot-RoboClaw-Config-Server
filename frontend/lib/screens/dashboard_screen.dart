// frontend/lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import '../api/http_admin_api.dart';
import '../features/backup/backup_controller.dart';
import '../services/api_service.dart';
import '../services/download_helper.dart';
import '../services/file_picker_helper.dart';
import 'config_tab.dart';
import 'scenario_tab.dart';
import '../utils/localization.dart';

class DashboardScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onThemeModeChanged;

  const DashboardScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTabIndex = 0; // 0: Configs, 1: Test Scenarios

  final _configTabKey = GlobalKey<ConfigTabState>();
  final _scenarioTabKey = GlobalKey<ScenarioTabState>();

  final _backupController = BackupController(
    api: HttpAdminApi.instance,
    picker: FilePickerHelper.instance,
    downloader: DownloadHelper.instance,
  );

  @override
  void initState() {
    super.initState();
    ApiService.loadAdminTokenFromStorage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Row(
          children: [
            Icon(
              Icons.psychology,
              color: Theme.of(context).colorScheme.primary,
              size: 30,
            ),
            const SizedBox(width: 12),
            Text(
              'AI 에이전트 설정 대시보드'.tr,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              child: Text(
                'RoboClaw Core v0.2.1',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF82B1FF)
                      : Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          const _LanguageToggle(),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.save_alt,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: '백업 (내보내기/가져오기)'.tr,
            onSelected: (value) {
              if (value == 'export') {
                _showExportDialog();
              } else if (value == 'import') {
                _startImportFlow();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'export', child: Text('전체 설정 내보내기'.tr)),
              PopupMenuItem(value: 'import', child: Text('백업 파일 가져오기'.tr)),
            ],
          ),
          IconButton(
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: widget.themeMode == ThemeMode.dark
                ? '라이트 모드 전환'.tr
                : '다크 모드 전환'.tr,
            onPressed: widget.onThemeModeChanged,
          ),
          IconButton(
            icon: Icon(
              Icons.vpn_key,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: '관리자 토큰 설정'.tr,
            onPressed: _showTokenDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침'.tr,
            onPressed: () {
              _configTabKey.currentState?.refresh();
              _scenarioTabKey.currentState?.refresh();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentTabIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _currentTabIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF161616)
                : const Color(0xFFF1F5F9),
            selectedIconTheme: IconThemeData(
              color: Theme.of(context).colorScheme.primary,
            ),
            unselectedIconTheme: const IconThemeData(color: Colors.grey),
            selectedLabelTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.settings),
                label: Text('설정 관리'.tr),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.playlist_play),
                label: Text('시나리오'.tr),
              ),
            ],
          ),
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                ConfigTab(key: _configTabKey, onUnauthorized: _showTokenDialog),
                ScenarioTab(
                  key: _scenarioTabKey,
                  onUnauthorized: _showTokenDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== 백업 내보내기 / 가져오기 =====

  Future<void> _showExportDialog() async {
    var includeConfigs = true;
    var includeScenarios = true;
    var includeSecrets = false;
    var exporting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.save_alt,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text('전체 설정 내보내기'.tr),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: Text('설정 프로필 포함'.tr),
                  value: includeConfigs,
                  onChanged: exporting
                      ? null
                      : (v) => setDialogState(() => includeConfigs = v),
                ),
                SwitchListTile(
                  title: Text('테스트 시나리오 포함'.tr),
                  value: includeScenarios,
                  onChanged: exporting
                      ? null
                      : (v) => setDialogState(() => includeScenarios = v),
                ),
                SwitchListTile(
                  title: Text('API Key와 토큰 포함'.tr),
                  subtitle: Text(
                    '이 옵션을 켜면 민감 정보가 평문으로 파일에 포함됩니다.'.tr,
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                  value: includeSecrets,
                  onChanged: exporting
                      ? null
                      : (v) => setDialogState(() => includeSecrets = v),
                ),
                if (includeSecrets)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '경고: 이 백업에는 API Key와 인증 토큰이 평문으로 포함됩니다. 안전한 위치에 보관하고 사용 후 삭제하세요.'
                            .tr,
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: exporting ? null : () => Navigator.pop(context),
              child: Text('취소'.tr),
            ),
            ElevatedButton.icon(
              onPressed: exporting
                  ? null
                  : () async {
                      if (!includeConfigs && !includeScenarios) {
                        _showSnack('적어도 하나의 항목을 선택해야 합니다.'.tr);
                        return;
                      }
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      setDialogState(() => exporting = true);
                      await _backupController.exportBackup(
                        includeSecrets: includeSecrets,
                        includeConfigs: includeConfigs,
                        includeScenarios: includeScenarios,
                      );
                      if (!mounted) return;
                      if (_backupController.status == BackupStatus.success) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('백업 파일이 다운로드되었습니다.'.tr)),
                        );
                        navigator.pop();
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              '${'백업 내보내기 실패: '.tr}${_backupController.error}',
                            ),
                          ),
                        );
                      }
                      setDialogState(() => exporting = false);
                    },
              icon: exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download, size: 16),
              label: Text(
                exporting ? '내보내는 중...'.tr : '내보내기'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startImportFlow() async {
    await _backupController.pickAndValidate();
    if (!mounted) return;
    if (_backupController.status == BackupStatus.ready) {
      await _showImportConfirmDialog();
    } else if (_backupController.status == BackupStatus.error) {
      _showSnack('${'백업 검증 실패: '.tr}${_backupController.error}');
    }
  }

  Future<void> _showImportConfirmDialog() async {
    final validation = _backupController.validation ?? {};
    final valid = _backupController.isValid;
    final summary = validation['summary'] as Map<String, dynamic>? ?? {};
    final warnings = (validation['warnings'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final errors = (validation['errors'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final includesSecrets = validation['includes_secrets'] == true;

    var conflictPolicy = 'skip';
    var activationPolicy = 'inactive';
    var importing = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.upload_file,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text('백업 파일 가져오기'.tr),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '설정 프로필 ${summary['configs'] ?? 0}건, 시나리오 ${summary['scenarios'] ?? 0}건 (신규 설정 ${summary['new_configs'] ?? 0}건 / 충돌 ${summary['conflicting_configs'] ?? 0}건, 신규 시나리오 ${summary['new_scenarios'] ?? 0}건 / 충돌 ${summary['conflicting_scenarios'] ?? 0}건)'
                      .tr,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  includesSecrets
                      ? '이 백업에는 민감 정보가 포함되어 있습니다.'.tr
                      : '이 백업에는 민감 정보가 포함되지 않았습니다.'.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: includesSecrets ? Colors.orange : Colors.grey,
                  ),
                ),
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...warnings.map(
                    (w) => Text(
                      '• $w',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
                if (errors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...errors.map(
                    (e) => Text(
                      '• $e',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
                const Divider(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: conflictPolicy,
                  decoration: const InputDecoration(labelText: '충돌 처리 정책'),
                  items: const [
                    DropdownMenuItem(
                      value: 'skip',
                      child: Text('건너뛰기 (기존 유지)'),
                    ),
                    DropdownMenuItem(value: 'overwrite', child: Text('덮어쓰기')),
                    DropdownMenuItem(value: 'copy', child: Text('복사본 생성')),
                  ],
                  onChanged: importing
                      ? null
                      : (v) =>
                            setDialogState(() => conflictPolicy = v ?? 'skip'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: activationPolicy,
                  decoration: const InputDecoration(labelText: '활성 상태 정책'),
                  items: const [
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('모두 비활성으로 가져오기 (권장)'),
                    ),
                    DropdownMenuItem(
                      value: 'preserve',
                      child: Text('내보낸 활성 상태 유지'),
                    ),
                    DropdownMenuItem(
                      value: 'keep_existing',
                      child: Text('기존 활성 상태 유지'),
                    ),
                  ],
                  onChanged: importing
                      ? null
                      : (v) => setDialogState(
                          () => activationPolicy = v ?? 'inactive',
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: importing ? null : () => Navigator.pop(context),
              child: Text('취소'.tr),
            ),
            ElevatedButton.icon(
              onPressed: (!valid || importing)
                  ? null
                  : () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      setDialogState(() => importing = true);
                      await _backupController.import(
                        conflictPolicy: conflictPolicy,
                        activationPolicy: activationPolicy,
                      );
                      if (!mounted) return;
                      if (_backupController.status == BackupStatus.success) {
                        final result = _backupController.importResult ?? {};
                        final cfg =
                            result['configs'] as Map<String, dynamic>? ?? {};
                        final sc =
                            result['scenarios'] as Map<String, dynamic>? ?? {};
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              '가져오기 완료: 설정(생성 ${cfg['created']}, 갱신 ${cfg['updated']}, 건너뜀 ${cfg['skipped']}), 시나리오(생성 ${sc['created']}, 갱신 ${sc['updated']}, 건너뜀 ${sc['skipped']})'
                                  .tr,
                            ),
                          ),
                        );
                        navigator.pop();
                        _configTabKey.currentState?.refresh();
                        _scenarioTabKey.currentState?.refresh();
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              '${'백업 가져오기 실패: '.tr}${_backupController.error}',
                            ),
                          ),
                        );
                      }
                      setDialogState(() => importing = false);
                    },
              icon: importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 16),
              label: Text(
                valid ? '가져오기'.tr : '가져올 수 없음'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isTokenDialogOpen = false;

  Future<void> _showTokenDialog() async {
    if (_isTokenDialogOpen) return;
    _isTokenDialogOpen = true;
    final tokenCtrl = TextEditingController(text: ApiService.adminToken ?? '');
    try {
      final bool? isSaved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.security,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text('관리자 인증 토큰 입력'.tr),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '서버 API 보안 인증이 활성화되어 있습니다.\n대시보드 데이터를 가져오기 위해 admin_token을 입력해 주세요.'
                    .tr,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey
                      : const Color(0xFF475569),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tokenCtrl,
                obscureText: true,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  labelText: 'Admin Token'.tr,
                  border: const OutlineInputBorder(),
                  hintText: 'admin_token 값을 입력하세요'.tr,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                ApiService.clearAdminToken();
                Navigator.pop(context, false);
              },
              child: Text(
                '토큰 소거'.tr,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('취소'.tr),
            ),
            ElevatedButton(
              onPressed: () {
                ApiService.saveAdminTokenToStorage(tokenCtrl.text.trim());
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
              ),
              child: Text(
                '저장 및 적용'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (isSaved == true) {
        _configTabKey.currentState?.refresh();
        _scenarioTabKey.currentState?.refresh();
      }
    } finally {
      _isTokenDialogOpen = false;
    }
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageManager.languageCodeNotifier,
      builder: (context, currentLang, _) {
        final isKo = currentLang == 'ko';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildButton(context, 'KO', isKo, () {
                if (!isKo) LanguageManager.languageCode = 'ko';
              }),
              _buildButton(context, 'EN', !isKo, () {
                if (isKo) LanguageManager.languageCode = 'en';
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButton(
    BuildContext context,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    final activeBgColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeTextColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final inactiveTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: double.infinity,
        decoration: BoxDecoration(
          color: isActive ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? activeTextColor : inactiveTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}
