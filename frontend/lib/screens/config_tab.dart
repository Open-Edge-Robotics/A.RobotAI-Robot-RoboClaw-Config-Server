// frontend/lib/screens/config_tab.dart

import 'package:material_ui/material_ui.dart';
import '../api/admin_api.dart';
import '../api/api_exception.dart';
import '../features/configs/config_controller.dart';
import '../features/configs/config_form_fields.dart';
import '../features/configs/config_form_mapper.dart';
import '../models/config_model.dart';
import '../platform/file_downloader.dart';
import '../services/logger.dart';
import '../widgets/config_editor_form.dart';
import '../widgets/config_list_panel.dart';
import '../utils/localization.dart';

class ConfigTab extends StatefulWidget {
  final AdminApi api;
  final FileDownloader downloader;
  final VoidCallback? onUnauthorized;

  const ConfigTab({
    super.key,
    required this.api,
    required this.downloader,
    this.onUnauthorized,
  });

  @override
  State<ConfigTab> createState() => ConfigTabState();
}

class ConfigTabState extends State<ConfigTab> {
  // --- Configs State ---
  late final ConfigController _configController;

  // 목록/로딩 상태의 single source 는 Controller 이다.
  List<RoboClawConfig> get _configs => _configController.configs;
  bool get _isLoading => _configController.loading;

  String _searchRobot = '';
  String _searchEnv = '';

  RoboClawConfig? _selectedConfig;
  bool _isEditing = false;
  bool _isCreatingNew = false;

  final _formKey = GlobalKey<FormState>();

  // 폼 컨트롤러와 폼 raw 상태는 ConfigFormFields 어댑터가 소유한다.
  final _fields = ConfigFormFields();

  @override
  void initState() {
    super.initState();
    _configController = ConfigController(api: widget.api);
    _loadConfigs();
  }

  @override
  void dispose() {
    _configController.dispose();
    _fields.dispose();
    super.dispose();
  }

  void refresh() {
    _loadConfigs();
  }

  // --- Config API Methods ---

  Future<void> _loadConfigs() async {
    await _configController.load(
      robotName: _searchRobot,
      environment: _searchEnv,
    );
    if (!mounted) return;
    if (_configController.unauthorized) {
      _showError('인증 오류: 올바르지 않거나 만료된 관리자 토큰입니다.'.tr);
      if (widget.onUnauthorized != null) widget.onUnauthorized!();
    } else if (_configController.error != null) {
      _showError('${'서버 오류: '.tr}${_configController.error}');
    }
  }

  Future<void> _activateConfig(int id) async {
    // 변이 진행 중(busy) 재호출은 중복 API 호출이므로 무시한다.
    if (_configController.busy) return;
    try {
      await _configController.activate(id);
      if (!mounted) return;
      _showSuccess('설정이 성공적으로 활성화되었습니다.'.tr);
      setState(() {
        if (_selectedConfig?.id == id) {
          // 목록이 교체되어 대상이 사라진 경우에도 예외 없이 기존 선택을 유지한다.
          _selectedConfig = _configs.firstWhere(
            (c) => c.id == id,
            orElse: () => _selectedConfig!,
          );
        }
      });
    } on ApiException catch (e) {
      _showError('${'활성화 실패: '.tr}${e.message}');
    } catch (e) {
      _showError('${'활성화 처리 중 에러 발생: '.tr}$e');
    }
  }

  Future<void> _deleteConfig(int id) async {
    if (_configController.busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('설정 삭제'.tr),
        content: Text('정말로 이 설정을 삭제하시겠습니까?'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('삭제'.tr),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      await _configController.delete(id);
      if (!mounted) return;
      _showSuccess('삭제되었습니다.'.tr);
      setState(() {
        if (_selectedConfig?.id == id) {
          _selectedConfig = null;
          _isEditing = false;
        }
      });
    } on ApiException catch (e) {
      _showError('${'삭제 실패: '.tr}${e.message}');
    } catch (e) {
      _showError('${'삭제 처리 중 에러 발생: '.tr}$e');
    }
  }

  Future<void> _cloneConfig(int id) async {
    if (_configController.busy) return;
    try {
      final cloned = await _configController.clone(id);
      if (!mounted) return;
      _showSuccess('${'설정이 복제되었습니다: '.tr}${cloned.name}');
      setState(() {
        _selectedConfig = cloned;
        _isEditing = false;
        _isCreatingNew = false;
        _populateForm(cloned);
      });
    } on ApiException catch (e) {
      if (_configController.unauthorized) {
        _showError('인증 오류: 올바르지 않거나 만료된 관리자 토큰입니다.'.tr);
        if (widget.onUnauthorized != null) widget.onUnauthorized!();
      } else {
        _showError('${'복제 실패: '.tr}${e.message}\n${'상세내용: '.tr}${e.body}');
      }
    } catch (e) {
      _showError('${'복제 처리 중 에러 발생: '.tr}$e');
    }
  }

  Future<void> _saveConfig() async {
    if (_configController.busy) return;
    if (!_formKey.currentState!.validate()) {
      AppLogger.warning('Form validation failed.');
      return;
    }

    final config = ConfigFormMapper.toConfig(
      _fields.snapshot(),
      id: _isCreatingNew ? null : _selectedConfig?.id,
      isActive: _isCreatingNew ? false : (_selectedConfig?.isActive ?? false),
    );

    try {
      final savedConfig = await _configController.save(config, _isCreatingNew);
      if (!mounted) return;
      _showSuccess('성공적으로 저장되었습니다.'.tr);
      setState(() {
        _selectedConfig = savedConfig;
        _isEditing = false;
        _isCreatingNew = false;
      });
    } on ApiException catch (e) {
      _showError('${'저장 실패: '.tr}${e.message}\n${'상세내용: '.tr}${e.body}');
    } catch (e) {
      _showError('${'저장 처리 중 에러 발생: '.tr}$e');
    }
  }

  void _populateForm(RoboClawConfig config) {
    _fields.load(ConfigFormMapper.fromConfig(config));
  }

  // RoboClawConfig()의 기본값을 그대로 신뢰하여 폼을 초기화한다.
  // 필드 기본값이 두 곳(여기와 모델 생성자)에서 따로 관리되면 한쪽만 바뀌었을 때
  // 조용히 어긋나므로, 값 나열 대신 모델 생성자를 단일 소스로 사용한다.
  void _clearForm() {
    _populateForm(RoboClawConfig(name: '', robotName: '', environment: ''));
  }

  Future<void> _exportFile(String filename) async {
    if (_selectedConfig == null) return;

    final cfg = _selectedConfig!;
    switch (filename) {
      case '.env':
        await _downloadEnvFile(cfg);
        break;
      case 'ROBOT.md':
        widget.downloader.downloadText(cfg.soulContent, 'ROBOT.md');
        break;
      case 'SKILLS.md':
        widget.downloader.downloadText(cfg.skillsContent, 'SKILLS.md');
        break;
      case 'TROUBLESHOOTING.md':
        widget.downloader.downloadText(
          cfg.troubleshootingContent,
          'TROUBLESHOOTING.md',
        );
        break;
      case 'ROBOT_LIMITS.json':
        widget.downloader.downloadText(cfg.limitsContent, 'ROBOT_LIMITS.json');
        break;
      case 'all':
        await _downloadAllFiles(cfg);
        break;
    }
  }

  Future<void> _downloadEnvFile(RoboClawConfig cfg) async {
    try {
      final content = await widget.api.fetchConfigFile(cfg.id!, '.env');
      if (!mounted) return;
      widget.downloader.downloadText(content, '.env');
    } on ApiException catch (e) {
      _showError('${'.env 파일 조회 실패: '.tr}${e.message}');
    } catch (e) {
      _showError('${'.env 파일 조회 중 에러 발생: '.tr}$e');
    }
  }

  Future<void> _downloadAllFiles(RoboClawConfig cfg) async {
    try {
      final env = await widget.api.fetchConfigFile(cfg.id!, '.env');
      if (!mounted) return;
      final fileMap = {
        '.env': env,
        'ROBOT.md': cfg.soulContent,
        'SKILLS.md': cfg.skillsContent,
        'TROUBLESHOOTING.md': cfg.troubleshootingContent,
        'ROBOT_LIMITS.json': cfg.limitsContent,
      };
      widget.downloader.downloadZip(
        fileMap,
        '${cfg.robotName}_${cfg.environment}_config.zip',
      );
    } on ApiException catch (e) {
      _showError('${'.env 파일 조회 실패: '.tr}${e.message}');
    } catch (e) {
      _showError('${'설정 압축 파일 생성 중 에러 발생: '.tr}$e');
    }
  }

  // --- Helper Methods ---

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  // --- Layout Builders (Configs) ---

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _configController,
      builder: (context, _) {
        final width = MediaQuery.of(context).size.width;
        final isDesktop = width > 900;

        return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 380,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: _buildLeftPanel(),
          ),
        ),
        Expanded(
          child: Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF161616)
                : const Color(0xFFF1F5F9),
            child: _buildRightPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    if (_isEditing || _isCreatingNew || _selectedConfig != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          setState(() {
            if (_isEditing || _isCreatingNew) {
              _isEditing = false;
              _isCreatingNew = false;
            } else {
              _selectedConfig = null;
            }
          });
        },
        child: _buildRightPanel(),
      );
    }
    return _buildLeftPanel();
  }

  Widget _buildLeftPanel() {
    return ConfigListPanel(
      configs: _configs,
      isLoading: _isLoading,
      selectedConfig: _selectedConfig,
      onConfigSelected: (cfg) {
        setState(() {
          _selectedConfig = cfg;
          _isEditing = false;
          _isCreatingNew = false;
          _populateForm(cfg);
        });
      },
      onConfigActivated: _activateConfig,
      onConfigCloned: _cloneConfig,
      onConfigDeleted: _deleteConfig,
      onSearchRobotChanged: (val) {
        _searchRobot = val;
        _loadConfigs();
      },
      onSearchEnvChanged: (val) {
        _searchEnv = val;
        _loadConfigs();
      },
      onAddPressed: () {
        _clearForm();
        setState(() {
          _isCreatingNew = true;
          _isEditing = true;
          _selectedConfig = null;
        });
      },
    );
  }

  Widget _buildRightPanel() {
    if (_selectedConfig == null && !_isCreatingNew) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.terminal,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey
                  : const Color(0xFF334155),
            ),
            const SizedBox(height: 16),
            Text(
              '조회할 설정을 선택하거나 추가 버튼을 누르세요.'.tr,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey
                    : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      );
    }

    final isNew = _isCreatingNew;
    final titleText = isNew
        ? '신규 에이전트 설정 추가'.tr
        : '${_selectedConfig?.name} ${"설정 상세".tr}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF161616)
            : const Color(0xFFFFFFFF),
        elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 1,
        title: Text(
          titleText,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF0F172A),
          ),
        ),
        leading: MediaQuery.of(context).size.width <= 900
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedConfig = null;
                    _isEditing = false;
                    _isCreatingNew = false;
                  });
                },
              )
            : null,
        actions: [
          if (!_isEditing && _selectedConfig != null) ...[
            PopupMenuButton<String>(
              icon: Icon(
                Icons.download,
                color: Theme.of(context).colorScheme.primary,
              ),
              tooltip: '설정 파일 내보내기'.tr,
              onSelected: (filename) {
                _exportFile(filename);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: '.env', child: Text('.env (환경 변수)'.tr)),
                const PopupMenuItem(
                  value: 'ROBOT.md',
                  child: Text('ROBOT.md (Soul)'),
                ),
                PopupMenuItem(
                  value: 'SKILLS.md',
                  child: Text('SKILLS.md (스킬 가이드)'.tr),
                ),
                PopupMenuItem(
                  value: 'TROUBLESHOOTING.md',
                  child: Text('TROUBLESHOOTING.md (장애 대응)'.tr),
                ),
                PopupMenuItem(
                  value: 'ROBOT_LIMITS.json',
                  child: Text('ROBOT_LIMITS.json (스펙 제한)'.tr),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'all', child: Text('모두 받기 (ZIP)'.tr)),
              ],
            ),
            const SizedBox(width: 8),
          ],
          if (!_isEditing)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(Icons.edit, size: 16),
              label: Text(
                '편집'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          else ...[
            ElevatedButton.icon(
              onPressed: _configController.busy ? null : _saveConfig,
              icon: const Icon(Icons.save, size: 16),
              label: Text(
                '저장'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  if (isNew) {
                    _selectedConfig = null;
                    _isCreatingNew = false;
                    _isEditing = false;
                  } else {
                    _isEditing = false;
                    _populateForm(_selectedConfig!);
                  }
                });
              },
              child: Text('취소'.tr),
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: ConfigEditorForm(
        formKey: _formKey,
        fields: _fields,
        isEditing: _isEditing,
        api: widget.api,
        onChanged: () => setState(() {}),
      ),
    );
  }
}
