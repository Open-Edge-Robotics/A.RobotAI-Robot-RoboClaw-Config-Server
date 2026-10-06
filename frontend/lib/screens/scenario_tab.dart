import 'package:flutter/material.dart';
import '../api/http_admin_api.dart';
import '../features/scenarios/scenario_controller.dart';
import '../models/scenario_model.dart';
import '../services/logger.dart';
import '../utils/scenario_editor_utils.dart';
import '../utils/localization.dart';
import '../widgets/scenario_detail_panel.dart';
import '../widgets/scenario_list_panel.dart';

class ScenarioTab extends StatefulWidget {
  final VoidCallback? onUnauthorized;

  const ScenarioTab({super.key, this.onUnauthorized});

  @override
  State<ScenarioTab> createState() => ScenarioTabState();
}

class ScenarioTabState extends State<ScenarioTab> {
  // --- Scenarios State ---
  final _scenarioController = ScenarioController(api: HttpAdminApi.instance);

  List<TestScenario> _scenarios = [];
  bool _isLoadingScenarios = true;
  String _searchScenarioRobot = '';
  String _searchScenarioEnv = '';

  TestScenario? _selectedScenario;
  bool _isEditingScenario = false;
  bool _isCreatingNewScenario = false;

  final _scenarioFormKey = GlobalKey<FormState>();

  // 폼 컨트롤러 (Scenarios)
  final _scenarioNameCtrl = TextEditingController();
  final _scenarioRobotCtrl = TextEditingController();
  final _scenarioEnvCtrl = TextEditingController();
  final _scenarioDescCtrl = TextEditingController();
  final _scenarioCasesCtrl = TextEditingController(); // JSON String

  List<TestCase> _editingTestCases = [];
  bool _isJsonMode = false;

  @override
  void initState() {
    super.initState();
    _loadScenarios();
  }

  @override
  void dispose() {
    _scenarioNameCtrl.dispose();
    _scenarioRobotCtrl.dispose();
    _scenarioEnvCtrl.dispose();
    _scenarioDescCtrl.dispose();
    _scenarioCasesCtrl.dispose();
    super.dispose();
  }

  void refresh() {
    _loadScenarios();
  }

  // --- Scenario API Methods ---

  Future<void> _loadScenarios() async {
    await _scenarioController.load(
      robotName: _searchScenarioRobot,
      environment: _searchScenarioEnv,
    );
    if (!mounted) return;
    setState(() {
      _scenarios = _scenarioController.scenarios;
      _isLoadingScenarios = _scenarioController.loading;
    });
    if (_scenarioController.unauthorized) {
      _showError('인증 오류: 올바르지 않거나 만료된 관리자 토큰입니다.'.tr);
      if (widget.onUnauthorized != null) widget.onUnauthorized!();
    } else if (_scenarioController.error != null) {
      _showError('${'서버 오류: '.tr}${_scenarioController.error}');
    }
  }

  Future<void> _activateScenario(int id) async {
    try {
      await _scenarioController.activate(id);
      _showSuccess('시나리오가 성공적으로 활성화되었습니다.'.tr);
      setState(() {
        _scenarios = _scenarioController.scenarios;
        if (_selectedScenario?.id == id) {
          _selectedScenario = _scenarios.firstWhere((s) => s.id == id);
        }
      });
    } on ApiException catch (e) {
      _showError('${"활성화 실패: ".tr}${e.message}');
    } catch (e) {
      _showError('${"활성화 처리 중 에러 발생: ".tr}$e');
    }
  }

  Future<void> _cloneScenario(int id) async {
    try {
      final cloned = await _scenarioController.clone(id);
      _showSuccess('${"시나리오 복제 완료: ".tr}${cloned.name}');
      setState(() {
        _scenarios = _scenarioController.scenarios;
        _selectedScenario = cloned;
        _isEditingScenario = false;
        _isCreatingNewScenario = false;
        _populateScenarioForm(cloned);
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _showError('인증 오류: 올바르지 않거나 만료된 관리자 토큰입니다.'.tr);
        if (widget.onUnauthorized != null) widget.onUnauthorized!();
      } else {
        _showError('${"복제 실패: ".tr}${e.message}\n${"상세내용: ".tr}${e.body}');
      }
    } catch (e) {
      _showError('${"복제 처리 중 에러 발생: ".tr}$e');
    }
  }

  Future<void> _deleteScenario(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('시나리오 삭제'.tr),
        content: Text('정말로 이 테스트 시나리오를 삭제하시겠습니까?'.tr),
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

    try {
      await _scenarioController.delete(id);
      _showSuccess('시나리오 삭제 완료'.tr);
      setState(() {
        _scenarios = _scenarioController.scenarios;
        if (_selectedScenario?.id == id) {
          _selectedScenario = null;
          _isEditingScenario = false;
        }
      });
    } on ApiException catch (e) {
      _showError('${"삭제 실패: ".tr}${e.message}');
    } catch (e) {
      _showError('${"삭제 처리 중 에러 발생: ".tr}$e');
    }
  }

  Future<void> _saveScenario() async {
    if (!_scenarioFormKey.currentState!.validate()) {
      AppLogger.warning('Scenario Form validation failed.');
      return;
    }

    List<TestCase> testCasesList = [];
    if (_isJsonMode) {
      try {
        testCasesList = parseScenarioTestCasesJson(_scenarioCasesCtrl.text);
      } catch (e) {
        _showError('${"Test Cases JSON 형식이 올바르지 않습니다: ".tr}$e');
        return;
      }
    } else {
      testCasesList = _editingTestCases.map((tc) => tc.clone()).toList();
      if (testCasesList.isEmpty) {
        _showError('최소 하나 이상의 테스트 케이스가 필요합니다.'.tr);
        return;
      }
    }

    final scenario = TestScenario(
      id: _isCreatingNewScenario ? null : _selectedScenario?.id,
      name: _scenarioNameCtrl.text,
      description: _scenarioDescCtrl.text,
      robotName: _scenarioRobotCtrl.text,
      environment: _scenarioEnvCtrl.text,
      testCases: testCasesList,
    );

    try {
      final saved = await _scenarioController.save(
        scenario,
        _isCreatingNewScenario,
      );
      _showSuccess('시나리오 저장'.tr);
      setState(() {
        _scenarios = _scenarioController.scenarios;
        _selectedScenario = saved;
        _isEditingScenario = false;
        _isCreatingNewScenario = false;
      });
    } on ApiException catch (e) {
      _showError('${"저장 실패: ".tr}${e.message}\n${"상세내용: ".tr}${e.body}');
    } catch (e) {
      _showError('${"저장 처리 중 에러 발생: ".tr}$e');
    }
  }

  void _populateScenarioForm(TestScenario scenario) {
    _scenarioNameCtrl.text = scenario.name;
    _scenarioRobotCtrl.text = scenario.robotName;
    _scenarioEnvCtrl.text = scenario.environment;
    _scenarioDescCtrl.text = scenario.description;

    _editingTestCases = scenario.testCases.map((tc) => tc.clone()).toList();
    _isJsonMode = false;
    _scenarioCasesCtrl.text = encodeScenarioTestCasesJson(scenario.testCases);
  }

  void _clearScenarioForm() {
    _scenarioNameCtrl.clear();
    _scenarioRobotCtrl.clear();
    _scenarioEnvCtrl.clear();
    _scenarioDescCtrl.clear();
    _editingTestCases = [];
    _isJsonMode = false;
    _scenarioCasesCtrl.text = '[]';
  }

  void _showScenarioList() {
    setState(() {
      _selectedScenario = null;
      _isEditingScenario = false;
      _isCreatingNewScenario = false;
    });
  }

  void _startScenarioEdit() {
    setState(() {
      _isEditingScenario = true;
    });
  }

  void _cancelScenarioEdit() {
    setState(() {
      if (_isCreatingNewScenario) {
        _selectedScenario = null;
        _isCreatingNewScenario = false;
        _isEditingScenario = false;
      } else if (_selectedScenario != null) {
        _isEditingScenario = false;
        _populateScenarioForm(_selectedScenario!);
      }
    });
  }

  void _selectScenario(TestScenario scenario) {
    setState(() {
      _selectedScenario = scenario;
      _isEditingScenario = false;
      _isCreatingNewScenario = false;
      _populateScenarioForm(scenario);
    });
  }

  void _startNewScenario() {
    _clearScenarioForm();
    setState(() {
      _isCreatingNewScenario = true;
      _isEditingScenario = true;
      _selectedScenario = null;
    });
  }

  void _updateEditingTestCases(List<TestCase> testCases) {
    setState(() {
      _editingTestCases = testCases;
    });
  }

  void _switchToGuiEditor() {
    try {
      final currentText = _scenarioCasesCtrl.text.trim();
      if (currentText.isEmpty || currentText == '[]') {
        setState(() {
          _editingTestCases = [];
          _isJsonMode = false;
        });
        return;
      }

      final parsed = parseScenarioTestCasesJson(currentText);
      setState(() {
        _editingTestCases = parsed;
        _isJsonMode = false;
      });
    } catch (e) {
      _showError('${"JSON 구문 오류로 인해 GUI 에디터로 전환할 수 없습니다.\n오류: ".tr}$e');
    }
  }

  void _switchToJsonEditor() {
    setState(() {
      _scenarioCasesCtrl.text = encodeScenarioTestCasesJson(_editingTestCases);
      _isJsonMode = true;
    });
  }

  void _addTestCaseTemplate(String type) {
    if (!_isEditingScenario) {
      _showError('편집 모드일 때만 템플릿을 추가할 수 있습니다.'.tr);
      return;
    }

    try {
      final updatedText = appendScenarioTestCaseTemplate(
        currentText: _scenarioCasesCtrl.text,
        type: type,
      );
      setState(() {
        _scenarioCasesCtrl.text = updatedText;
      });
      _showSuccess('[$type] ${" 템플릿이 리스트에 추가되었습니다.".tr}');
    } catch (e) {
      _showError('$e');
    }
  }

  // --- Helper Methods ---

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  // --- Layout Builders (Scenarios) ---

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return isDesktop
        ? _buildDesktopScenarioLayout()
        : _buildMobileScenarioLayout();
  }

  Widget _buildDesktopScenarioLayout() {
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
            child: ScenarioListPanel(
              scenarios: _scenarios,
              isLoadingScenarios: _isLoadingScenarios,
              selectedScenario: _selectedScenario,
              onScenarioSelected: _selectScenario,
              onScenarioActivated: _activateScenario,
              onScenarioCloned: _cloneScenario,
              onScenarioDeleted: _deleteScenario,
              onSearchRobotChanged: (val) {
                _searchScenarioRobot = val;
                _loadScenarios();
              },
              onSearchEnvChanged: (val) {
                _searchScenarioEnv = val;
                _loadScenarios();
              },
              onAddPressed: _startNewScenario,
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF161616)
                : const Color(0xFFF1F5F9),
            child: _buildRightScenarioPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileScenarioLayout() {
    if (_isEditingScenario ||
        _isCreatingNewScenario ||
        _selectedScenario != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          setState(() {
            if (_isEditingScenario || _isCreatingNewScenario) {
              _isEditingScenario = false;
              _isCreatingNewScenario = false;
            } else {
              _selectedScenario = null;
            }
          });
        },
        child: _buildRightScenarioPanel(),
      );
    }
    return ScenarioListPanel(
      scenarios: _scenarios,
      isLoadingScenarios: _isLoadingScenarios,
      selectedScenario: _selectedScenario,
      onScenarioSelected: _selectScenario,
      onScenarioActivated: _activateScenario,
      onScenarioCloned: _cloneScenario,
      onScenarioDeleted: _deleteScenario,
      onSearchRobotChanged: (val) {
        _searchScenarioRobot = val;
        _loadScenarios();
      },
      onSearchEnvChanged: (val) {
        _searchScenarioEnv = val;
        _loadScenarios();
      },
      onAddPressed: _startNewScenario,
    );
  }

  Widget _buildRightScenarioPanel() {
    return ScenarioDetailPanel(
      formKey: _scenarioFormKey,
      nameController: _scenarioNameCtrl,
      robotController: _scenarioRobotCtrl,
      environmentController: _scenarioEnvCtrl,
      descriptionController: _scenarioDescCtrl,
      scenarioCasesController: _scenarioCasesCtrl,
      editingTestCases: _editingTestCases,
      selectedScenario: _selectedScenario,
      isEditing: _isEditingScenario,
      isCreatingNewScenario: _isCreatingNewScenario,
      isJsonMode: _isJsonMode,
      onBack: _showScenarioList,
      onStartEditing: _startScenarioEdit,
      onSave: _saveScenario,
      onCancel: _cancelScenarioEdit,
      onSelectGuiEditor: _switchToGuiEditor,
      onSelectJsonEditor: _switchToJsonEditor,
      onTestCasesChanged: _updateEditingTestCases,
      onAddTemplate: _addTestCaseTemplate,
    );
  }
}
