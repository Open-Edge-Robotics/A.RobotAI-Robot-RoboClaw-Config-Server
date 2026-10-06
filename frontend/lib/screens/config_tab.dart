// frontend/lib/screens/config_tab.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/http_admin_api.dart';
import '../features/configs/config_controller.dart';
import '../features/configs/config_form_mapper.dart';
import '../models/config_model.dart';
import '../services/api_service.dart';
import '../services/logger.dart';
import '../widgets/config_list_panel.dart';
import '../widgets/config_form_sections.dart';
import '../widgets/config_fleet_section.dart';
import '../services/download_helper.dart';
import '../utils/localization.dart';

class ConfigTab extends StatefulWidget {
  final VoidCallback? onUnauthorized;

  const ConfigTab({super.key, this.onUnauthorized});

  @override
  State<ConfigTab> createState() => ConfigTabState();
}

class ConfigTabState extends State<ConfigTab> {
  // --- Configs State ---
  final _configController = ConfigController(api: HttpAdminApi.instance);

  List<RoboClawConfig> _configs = [];
  bool _isLoading = true;
  String _searchRobot = '';
  String _searchEnv = '';

  RoboClawConfig? _selectedConfig;
  bool _isEditing = false;
  bool _isCreatingNew = false;

  final _formKey = GlobalKey<FormState>();

  // 폼 컨트롤러 (Configs)
  final _nameCtrl = TextEditingController();
  final _robotCtrl = TextEditingController();
  final _envCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _rosDomainCtrl = TextEditingController();
  final _agentIdCtrl = TextEditingController();

  String _llmProvider = 'azure';
  final _llmModelCtrl = TextEditingController();

  final _azureEndpointCtrl = TextEditingController();
  final _azureApiKeyCtrl = TextEditingController();
  final _openaiApiKeyCtrl = TextEditingController();
  final _anthropicApiKeyCtrl = TextEditingController();

  final _ollamaBaseUrlCtrl = TextEditingController();
  final _ollamaNumCtxCtrl = TextEditingController();
  final _ollamaTemperatureCtrl = TextEditingController();
  final _ollamaRepeatPenaltyCtrl = TextEditingController();
  final _ollamaRepeatLastNCtrl = TextEditingController();
  final _ollamaSeedCtrl = TextEditingController();
  final _ollamaNumPredictCtrl = TextEditingController();
  final _ollamaTopKCtrl = TextEditingController();
  final _ollamaTopPCtrl = TextEditingController();
  final _ollamaMinPCtrl = TextEditingController();
  // think: unset(미설정·키 미출력) | false | true | low | medium | high | max
  String _ollamaThink = 'unset';
  Map<String, dynamic> _ollamaExtraOptions = {};

  bool _enableRag = false;
  final _embeddingModelCtrl = TextEditingController();
  final _embeddingProviderCtrl = TextEditingController();
  final _embeddingBaseUrlCtrl = TextEditingController();
  final _embeddingApiKeyCtrl = TextEditingController();
  final _vectorBackendCtrl = TextEditingController();
  final _qdrantUrlCtrl = TextEditingController();
  final _qdrantCollCtrl = TextEditingController();

  bool _enableDiscord = false;
  bool _enableTelegram = false;
  bool _enableSlack = false;
  bool _enableGrpc = true;
  bool _useGrpc = false;
  bool _enableGrpcClient = false;
  final _discordTokenCtrl = TextEditingController();
  final _slackAppTokenCtrl = TextEditingController();
  final _slackBotTokenCtrl = TextEditingController();
  final _telegramTokenCtrl = TextEditingController();
  final _grpcTargetHostCtrl = TextEditingController();
  final _grpcTargetPortCtrl = TextEditingController();
  final _grpcTargetPeersJsonCtrl = TextEditingController();
  final _grpcPeerTokenCtrl = TextEditingController();
  final _grpcPortCtrl = TextEditingController();

  final _soulCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _troubleCtrl = TextEditingController();
  final _limitsCtrl = TextEditingController();

  // HTTP API 보안 설정 컨트롤러
  final _httpHostCtrl = TextEditingController();
  final _httpPortCtrl = TextEditingController();
  final _httpReadonlyTokenCtrl = TextEditingController();
  final _httpControlTokenCtrl = TextEditingController();
  final _httpAllowedCidrsCtrl = TextEditingController();
  final _httpRateLimitCtrl = TextEditingController();
  final _httpAllowedSkillsCtrl = TextEditingController();
  final _httpBlockedSkillsCtrl = TextEditingController();

  // Dashboard 웹 노드 설정 컨트롤러
  final _dashboardHostCtrl = TextEditingController();
  final _dashboardPortCtrl = TextEditingController();

  // MCP 서버 연동 설정
  bool _enableMcp = false;
  final _mcpServersJsonCtrl = TextEditingController();

  // RAG 추가 설정 컨트롤러
  final _ragTopKCtrl = TextEditingController();
  final _ragScoreThresholdCtrl = TextEditingController();
  final _qdrantApiKeyCtrl = TextEditingController();
  final _qdrantTimeoutSecCtrl = TextEditingController();
  bool _ragLocalMirror = true;
  final _memoryDirCtrl = TextEditingController();

  // 경로 및 리소스 설정 컨트롤러
  final _agentWorkspaceDirCtrl = TextEditingController();
  final _butlerScriptsDirCtrl = TextEditingController();
  final _butlerSourceDirCtrl = TextEditingController();
  final _configDirCtrl = TextEditingController();
  final _systemPromptFileCtrl = TextEditingController();
  final _robotDescriptionFileCtrl = TextEditingController();

  // 카메라 / 비전 설정 컨트롤러 및 변수
  final _cameraTopicCtrl = TextEditingController();
  bool _useVision = false;
  final _visionModelPathCtrl = TextEditingController();
  final _gripperCameraTopicCtrl = TextEditingController();
  final _gripperDepthTopicCtrl = TextEditingController();
  final _gripperCameraInfoTopicCtrl = TextEditingController();
  final _gripperPointcloudTopicCtrl = TextEditingController();
  bool _useGripperVision = false;
  final _gripperVisionMaxInferenceHzCtrl = TextEditingController();

  // 자가진단용 센서 토픽 컨트롤러
  final _lidarTopicCtrl = TextEditingController();
  final _imuTopicCtrl = TextEditingController();

  // 스킬 자가학습 설정 컨트롤러 및 변수
  bool _enableSkillLearning = false;
  final _skillLearningSuccessSampleRateCtrl = TextEditingController();
  final _skillLearningReflectIntervalSecCtrl = TextEditingController();

  // 태스크 큐 / 복합 명령 자동 분해 설정 컨트롤러 및 변수
  final _taskQueueMaxSizeCtrl = TextEditingController();
  bool _llmFailFast = false;
  bool _strictConfig = false;
  bool _enableTaskDecomposition = true;
  final _taskDecompositionMaxStepsCtrl = TextEditingController();
  final _taskStepMaxRetriesCtrl = TextEditingController();
  final _taskDecompositionWaitMarginCapSecCtrl = TextEditingController();

  // 디버그 설정 변수
  bool _debug = true;

  // LangSmith 트레이싱 설정 컨트롤러 및 변수
  bool _langsmithTracing = false;
  final _langsmithApiKeyCtrl = TextEditingController();
  final _langsmithProjectCtrl = TextEditingController();
  final _langsmithEndpointCtrl = TextEditingController();
  final _langsmithWorkspaceIdCtrl = TextEditingController();

  // System 1 Fast Router 설정 컨트롤러 및 변수
  String _system1Router = 'rule';
  bool _system1Shadow = false;
  final _system1ShadowLogCtrl = TextEditingController();
  String _system1Scope = 'readonly';
  final _system1EndpointCtrl = TextEditingController();
  final _system1ProviderCtrl = TextEditingController();
  final _system1TimeoutMsCtrl = TextEditingController();
  final _system1ConfThresholdsJsonCtrl = TextEditingController();
  final _system1SkillsCtrl = TextEditingController();
  final _system1MaxOptionsCtrl = TextEditingController();
  final _system1ApiKeyCtrl = TextEditingController();

  // Maestro FleetControl 연동 컨트롤러 및 변수 (contract v2.2.0)
  final _maestroIpCtrl = TextEditingController();
  final _robotPortCtrl = TextEditingController();
  final _robotIdCtrl = TextEditingController();
  final _robotSiteIdCtrl = TextEditingController();
  final _robotMapIdCtrl = TextEditingController();
  final _robotMapVersionCtrl = TextEditingController();
  final _robotMapFrameIdCtrl = TextEditingController();
  String _maestroDisconnectPolicy = 'complete';
  final _fleetHeartbeatSecCtrl = TextEditingController();
  final _fleetCommandJournalPathCtrl = TextEditingController();
  final _fleetSkillsGuideFileCtrl = TextEditingController();
  bool _fleetControlTls = false;
  final _fleetControlCaCertCtrl = TextEditingController();
  final _fleetControlClientCertCtrl = TextEditingController();
  final _fleetControlClientKeyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _robotCtrl.dispose();
    _envCtrl.dispose();
    _descCtrl.dispose();
    _rosDomainCtrl.dispose();
    _agentIdCtrl.dispose();
    _llmModelCtrl.dispose();
    _azureEndpointCtrl.dispose();
    _azureApiKeyCtrl.dispose();
    _openaiApiKeyCtrl.dispose();
    _anthropicApiKeyCtrl.dispose();
    _ollamaBaseUrlCtrl.dispose();
    _ollamaNumCtxCtrl.dispose();
    _ollamaTemperatureCtrl.dispose();
    _ollamaRepeatPenaltyCtrl.dispose();
    _ollamaRepeatLastNCtrl.dispose();
    _ollamaSeedCtrl.dispose();
    _ollamaNumPredictCtrl.dispose();
    _ollamaTopKCtrl.dispose();
    _ollamaTopPCtrl.dispose();
    _ollamaMinPCtrl.dispose();
    _embeddingModelCtrl.dispose();
    _embeddingProviderCtrl.dispose();
    _embeddingBaseUrlCtrl.dispose();
    _embeddingApiKeyCtrl.dispose();
    _vectorBackendCtrl.dispose();
    _qdrantUrlCtrl.dispose();
    _qdrantCollCtrl.dispose();
    _discordTokenCtrl.dispose();
    _slackAppTokenCtrl.dispose();
    _slackBotTokenCtrl.dispose();
    _telegramTokenCtrl.dispose();
    _grpcTargetHostCtrl.dispose();
    _grpcTargetPortCtrl.dispose();
    _grpcTargetPeersJsonCtrl.dispose();
    _grpcPeerTokenCtrl.dispose();
    _grpcPortCtrl.dispose();
    _soulCtrl.dispose();
    _skillsCtrl.dispose();
    _troubleCtrl.dispose();
    _limitsCtrl.dispose();

    _httpHostCtrl.dispose();
    _httpPortCtrl.dispose();
    _httpReadonlyTokenCtrl.dispose();
    _httpControlTokenCtrl.dispose();
    _httpAllowedCidrsCtrl.dispose();
    _httpRateLimitCtrl.dispose();
    _httpAllowedSkillsCtrl.dispose();
    _httpBlockedSkillsCtrl.dispose();
    _dashboardHostCtrl.dispose();
    _dashboardPortCtrl.dispose();
    _mcpServersJsonCtrl.dispose();

    _ragTopKCtrl.dispose();
    _ragScoreThresholdCtrl.dispose();
    _qdrantApiKeyCtrl.dispose();
    _qdrantTimeoutSecCtrl.dispose();
    _memoryDirCtrl.dispose();
    _agentWorkspaceDirCtrl.dispose();
    _butlerScriptsDirCtrl.dispose();
    _butlerSourceDirCtrl.dispose();
    _configDirCtrl.dispose();
    _systemPromptFileCtrl.dispose();
    _robotDescriptionFileCtrl.dispose();
    _cameraTopicCtrl.dispose();
    _visionModelPathCtrl.dispose();
    _gripperCameraTopicCtrl.dispose();
    _gripperDepthTopicCtrl.dispose();
    _gripperCameraInfoTopicCtrl.dispose();
    _gripperPointcloudTopicCtrl.dispose();
    _gripperVisionMaxInferenceHzCtrl.dispose();
    _lidarTopicCtrl.dispose();
    _imuTopicCtrl.dispose();
    _taskQueueMaxSizeCtrl.dispose();
    _taskDecompositionMaxStepsCtrl.dispose();
    _taskStepMaxRetriesCtrl.dispose();
    _taskDecompositionWaitMarginCapSecCtrl.dispose();
    _skillLearningSuccessSampleRateCtrl.dispose();
    _skillLearningReflectIntervalSecCtrl.dispose();
    _langsmithApiKeyCtrl.dispose();
    _langsmithProjectCtrl.dispose();
    _langsmithEndpointCtrl.dispose();
    _langsmithWorkspaceIdCtrl.dispose();
    _system1ShadowLogCtrl.dispose();
    _system1EndpointCtrl.dispose();
    _system1ProviderCtrl.dispose();
    _system1TimeoutMsCtrl.dispose();
    _system1ConfThresholdsJsonCtrl.dispose();
    _system1SkillsCtrl.dispose();
    _system1MaxOptionsCtrl.dispose();
    _system1ApiKeyCtrl.dispose();
    _maestroIpCtrl.dispose();
    _robotPortCtrl.dispose();
    _robotIdCtrl.dispose();
    _robotSiteIdCtrl.dispose();
    _robotMapIdCtrl.dispose();
    _robotMapVersionCtrl.dispose();
    _robotMapFrameIdCtrl.dispose();
    _fleetHeartbeatSecCtrl.dispose();
    _fleetCommandJournalPathCtrl.dispose();
    _fleetSkillsGuideFileCtrl.dispose();
    _fleetControlCaCertCtrl.dispose();
    _fleetControlClientCertCtrl.dispose();
    _fleetControlClientKeyCtrl.dispose();
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
    setState(() {
      _configs = _configController.configs;
      _isLoading = _configController.loading;
    });
    if (_configController.unauthorized) {
      _showError('인증 오류: 올바르지 않거나 만료된 관리자 토큰입니다.'.tr);
      if (widget.onUnauthorized != null) widget.onUnauthorized!();
    } else if (_configController.error != null) {
      _showError('${'서버 오류: '.tr}${_configController.error}');
    }
  }

  Future<void> _activateConfig(int id) async {
    try {
      await _configController.activate(id);
      _showSuccess('설정이 성공적으로 활성화되었습니다.'.tr);
      setState(() {
        _configs = _configController.configs;
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

    try {
      await _configController.delete(id);
      _showSuccess('삭제되었습니다.'.tr);
      setState(() {
        _configs = _configController.configs;
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
    try {
      final cloned = await _configController.clone(id);
      _showSuccess('${'설정이 복제되었습니다: '.tr}${cloned.name}');
      setState(() {
        _configs = _configController.configs;
        _selectedConfig = cloned;
        _isEditing = false;
        _isCreatingNew = false;
        _populateForm(cloned);
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
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
    if (!_formKey.currentState!.validate()) {
      AppLogger.warning('Form validation failed.');
      return;
    }

    final config = RoboClawConfig(
      id: _isCreatingNew ? null : _selectedConfig?.id,
      isActive: _isCreatingNew ? false : (_selectedConfig?.isActive ?? false),
      name: _nameCtrl.text,
      robotName: _robotCtrl.text,
      environment: _envCtrl.text,
      description: _descCtrl.text,
      rosDomainId: int.tryParse(_rosDomainCtrl.text) ?? 0,
      agentId: _agentIdCtrl.text.trim(),
      llmProvider: _llmProvider,
      llmModel: _llmModelCtrl.text,
      azureOpenaiEndpoint: _azureEndpointCtrl.text,
      azureOpenaiApiKey: _azureApiKeyCtrl.text,
      openaiApiKey: _openaiApiKeyCtrl.text,
      anthropicApiKey: _anthropicApiKeyCtrl.text,
      ollamaBaseUrl: _ollamaBaseUrlCtrl.text,
      ollamaOptionsJson: jsonEncode(_buildOllamaOptions()),
      enableRag: _enableRag,
      llmEmbeddingModel: _embeddingModelCtrl.text,
      llmEmbeddingProvider: _embeddingProviderCtrl.text,
      llmEmbeddingBaseUrl: _embeddingBaseUrlCtrl.text,
      llmEmbeddingApiKey: _embeddingApiKeyCtrl.text,
      ragVectorBackend: _vectorBackendCtrl.text,
      qdrantUrl: _qdrantUrlCtrl.text,
      qdrantCollection: _qdrantCollCtrl.text,
      enableDiscord: _enableDiscord,
      enableTelegram: _enableTelegram,
      enableSlack: _enableSlack,
      enableGrpc: _enableGrpc,
      useGrpc: _useGrpc,
      enableGrpcClient: _enableGrpcClient,
      grpcPort: int.tryParse(_grpcPortCtrl.text) ?? 50052,
      grpcPeerToken: _grpcPeerTokenCtrl.text,
      grpcTargetHost: _grpcTargetHostCtrl.text,
      grpcTargetPort: int.tryParse(_grpcTargetPortCtrl.text) ?? 50051,
      grpcTargetPeersJson: _grpcTargetPeersJsonCtrl.text,
      discordBotToken: _discordTokenCtrl.text,
      slackAppToken: _slackAppTokenCtrl.text,
      slackBotToken: _slackBotTokenCtrl.text,
      telegramBotToken: _telegramTokenCtrl.text,
      soulContent: _soulCtrl.text,
      skillsContent: _skillsCtrl.text,
      troubleshootingContent: _troubleCtrl.text,
      limitsContent: _limitsCtrl.text,
      httpHost: _httpHostCtrl.text,
      httpPort: int.tryParse(_httpPortCtrl.text) ?? 8080,
      httpReadonlyToken: _httpReadonlyTokenCtrl.text,
      httpControlToken: _httpControlTokenCtrl.text,
      httpAllowedCidrsJson: _httpAllowedCidrsCtrl.text,
      httpRateLimitPerMinute: int.tryParse(_httpRateLimitCtrl.text) ?? 60,
      httpAllowedSkillsJson: _httpAllowedSkillsCtrl.text,
      httpBlockedSkillsJson: _httpBlockedSkillsCtrl.text,
      dashboardHost: _dashboardHostCtrl.text,
      dashboardPort: int.tryParse(_dashboardPortCtrl.text) ?? 9090,
      enableMcp: _enableMcp,
      mcpServersJson: _mcpServersJsonCtrl.text,
      ragTopK: int.tryParse(_ragTopKCtrl.text) ?? 2,
      ragScoreThreshold: double.tryParse(_ragScoreThresholdCtrl.text) ?? 0.7,
      qdrantApiKey: _qdrantApiKeyCtrl.text,
      qdrantTimeoutSec: double.tryParse(_qdrantTimeoutSecCtrl.text) ?? 5.0,
      ragLocalMirror: _ragLocalMirror,
      memoryDir: _memoryDirCtrl.text,
      agentWorkspaceDir: _agentWorkspaceDirCtrl.text,
      butlerScriptsDir: _butlerScriptsDirCtrl.text,
      butlerSourceDir: _butlerSourceDirCtrl.text,
      configDir: _configDirCtrl.text,
      systemPromptFile: _systemPromptFileCtrl.text,
      robotDescriptionFile: _robotDescriptionFileCtrl.text,
      cameraTopic: _cameraTopicCtrl.text,
      useVision: _useVision,
      visionModelPath: _visionModelPathCtrl.text,
      gripperCameraTopic: _gripperCameraTopicCtrl.text,
      gripperDepthTopic: _gripperDepthTopicCtrl.text,
      gripperCameraInfoTopic: _gripperCameraInfoTopicCtrl.text,
      gripperPointcloudTopic: _gripperPointcloudTopicCtrl.text,
      useGripperVision: _useGripperVision,
      gripperVisionMaxInferenceHz:
          double.tryParse(_gripperVisionMaxInferenceHzCtrl.text) ?? 5.0,
      lidarTopic: _lidarTopicCtrl.text,
      imuTopic: _imuTopicCtrl.text,
      debug: _debug,
      enableSkillLearning: _enableSkillLearning,
      skillLearningSuccessSampleRate:
          double.tryParse(_skillLearningSuccessSampleRateCtrl.text) ?? 0.1,
      skillLearningReflectIntervalSec:
          int.tryParse(_skillLearningReflectIntervalSecCtrl.text) ?? 1800,
      taskQueueMaxSize: int.tryParse(_taskQueueMaxSizeCtrl.text) ?? 8,
      llmFailFast: _llmFailFast,
      strictConfig: _strictConfig,
      enableTaskDecomposition: _enableTaskDecomposition,
      taskDecompositionMaxSteps:
          int.tryParse(_taskDecompositionMaxStepsCtrl.text) ?? 6,
      taskStepMaxRetries: int.tryParse(_taskStepMaxRetriesCtrl.text) ?? 1,
      taskDecompositionWaitMarginCapSec:
          double.tryParse(_taskDecompositionWaitMarginCapSecCtrl.text) ??
          1800.0,
      langsmithTracing: _langsmithTracing,
      langsmithApiKey: _langsmithApiKeyCtrl.text,
      langsmithProject: _langsmithProjectCtrl.text,
      langsmithEndpoint: _langsmithEndpointCtrl.text,
      langsmithWorkspaceId: _langsmithWorkspaceIdCtrl.text,
      system1Router: _system1Router,
      system1Shadow: _system1Shadow,
      system1ShadowLog: _system1ShadowLogCtrl.text,
      system1Scope: _system1Scope,
      system1Endpoint: _system1EndpointCtrl.text,
      system1Provider: _system1ProviderCtrl.text,
      system1TimeoutMs: double.tryParse(_system1TimeoutMsCtrl.text) ?? 300.0,
      system1ConfThresholdsJson: _system1ConfThresholdsJsonCtrl.text,
      system1Skills: _system1SkillsCtrl.text,
      system1MaxOptions: int.tryParse(_system1MaxOptionsCtrl.text) ?? 12,
      system1ApiKey: _system1ApiKeyCtrl.text,
      maestroIp: _maestroIpCtrl.text,
      robotPort: int.tryParse(_robotPortCtrl.text) ?? 50053,
      robotId: _robotIdCtrl.text,
      robotSiteId: _robotSiteIdCtrl.text,
      robotMapId: _robotMapIdCtrl.text,
      robotMapVersion: _robotMapVersionCtrl.text,
      robotMapFrameId: _robotMapFrameIdCtrl.text,
      maestroDisconnectPolicy: _maestroDisconnectPolicy,
      fleetHeartbeatSec: double.tryParse(_fleetHeartbeatSecCtrl.text) ?? 1.0,
      fleetCommandJournalPath: _fleetCommandJournalPathCtrl.text,
      fleetSkillsGuideFile: _fleetSkillsGuideFileCtrl.text,
      fleetControlTls: _fleetControlTls,
      fleetControlCaCert: _fleetControlCaCertCtrl.text,
      fleetControlClientCert: _fleetControlClientCertCtrl.text,
      fleetControlClientKey: _fleetControlClientKeyCtrl.text,
    );

    try {
      final savedConfig = await _configController.save(config, _isCreatingNew);
      _showSuccess('성공적으로 저장되었습니다.'.tr);
      setState(() {
        _configs = _configController.configs;
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
    _nameCtrl.text = config.name;
    _robotCtrl.text = config.robotName;
    _envCtrl.text = config.environment;
    _descCtrl.text = config.description;
    _rosDomainCtrl.text = config.rosDomainId.toString();
    _agentIdCtrl.text = config.agentId;

    _llmProvider = config.llmProvider;
    _llmModelCtrl.text = config.llmModel;

    _azureEndpointCtrl.text = config.azureOpenaiEndpoint;
    _azureApiKeyCtrl.text = config.azureOpenaiApiKey;
    _openaiApiKeyCtrl.text = config.openaiApiKey;
    _anthropicApiKeyCtrl.text = config.anthropicApiKey;

    _ollamaBaseUrlCtrl.text = config.ollamaBaseUrl;
    if (config.ollamaOptionsJson.isNotEmpty) {
      final v = ConfigFormMapper.parseOllamaOptions(config.ollamaOptionsJson);
      _ollamaNumCtxCtrl.text = v.numCtx;
      _ollamaTemperatureCtrl.text = v.temperature;
      _ollamaRepeatPenaltyCtrl.text = v.repeatPenalty;
      _ollamaRepeatLastNCtrl.text = v.repeatLastN;
      _ollamaSeedCtrl.text = v.seed;
      _ollamaNumPredictCtrl.text = v.numPredict;
      _ollamaTopKCtrl.text = v.topK;
      _ollamaTopPCtrl.text = v.topP;
      _ollamaMinPCtrl.text = v.minP;
      _ollamaThink = v.think;
      _ollamaExtraOptions = v.extraOptions;
    } else {
      _resetOllamaOptionsToDefault();
    }

    _enableRag = config.enableRag;
    _embeddingModelCtrl.text = config.llmEmbeddingModel;
    _embeddingProviderCtrl.text = config.llmEmbeddingProvider;
    _embeddingBaseUrlCtrl.text = config.llmEmbeddingBaseUrl;
    _embeddingApiKeyCtrl.text = config.llmEmbeddingApiKey;
    _vectorBackendCtrl.text = config.ragVectorBackend;
    _qdrantUrlCtrl.text = config.qdrantUrl;
    _qdrantCollCtrl.text = config.qdrantCollection;

    _enableDiscord = config.enableDiscord;
    _enableTelegram = config.enableTelegram;
    _enableSlack = config.enableSlack;
    _enableGrpc = config.enableGrpc;
    _useGrpc = config.useGrpc;
    _enableGrpcClient = config.enableGrpcClient;
    _grpcTargetHostCtrl.text = config.grpcTargetHost;
    _grpcTargetPortCtrl.text = config.grpcTargetPort.toString();
    _grpcTargetPeersJsonCtrl.text = config.grpcTargetPeersJson;
    _grpcPeerTokenCtrl.text = config.grpcPeerToken;
    _grpcPortCtrl.text = config.grpcPort.toString();
    _discordTokenCtrl.text = config.discordBotToken;
    _slackAppTokenCtrl.text = config.slackAppToken;
    _slackBotTokenCtrl.text = config.slackBotToken;
    _telegramTokenCtrl.text = config.telegramBotToken;

    _soulCtrl.text = config.soulContent;
    _skillsCtrl.text = config.skillsContent;
    _troubleCtrl.text = config.troubleshootingContent;
    _limitsCtrl.text = config.limitsContent;

    _httpHostCtrl.text = config.httpHost;
    _httpPortCtrl.text = config.httpPort.toString();
    _httpReadonlyTokenCtrl.text = config.httpReadonlyToken;
    _httpControlTokenCtrl.text = config.httpControlToken;
    _httpAllowedCidrsCtrl.text = config.httpAllowedCidrsJson;
    _httpRateLimitCtrl.text = config.httpRateLimitPerMinute.toString();
    _httpAllowedSkillsCtrl.text = config.httpAllowedSkillsJson;
    _httpBlockedSkillsCtrl.text = config.httpBlockedSkillsJson;
    _dashboardHostCtrl.text = config.dashboardHost;
    _dashboardPortCtrl.text = config.dashboardPort.toString();

    _enableMcp = config.enableMcp;
    _mcpServersJsonCtrl.text = config.mcpServersJson;

    _ragTopKCtrl.text = config.ragTopK.toString();
    _ragScoreThresholdCtrl.text = config.ragScoreThreshold.toString();
    _qdrantApiKeyCtrl.text = config.qdrantApiKey;
    _qdrantTimeoutSecCtrl.text = config.qdrantTimeoutSec.toString();
    _ragLocalMirror = config.ragLocalMirror;
    _memoryDirCtrl.text = config.memoryDir;
    _agentWorkspaceDirCtrl.text = config.agentWorkspaceDir;
    _butlerScriptsDirCtrl.text = config.butlerScriptsDir;
    _butlerSourceDirCtrl.text = config.butlerSourceDir;
    _configDirCtrl.text = config.configDir;
    _systemPromptFileCtrl.text = config.systemPromptFile;
    _robotDescriptionFileCtrl.text = config.robotDescriptionFile;
    _cameraTopicCtrl.text = config.cameraTopic;
    _useVision = config.useVision;
    _visionModelPathCtrl.text = config.visionModelPath;
    _gripperCameraTopicCtrl.text = config.gripperCameraTopic;
    _gripperDepthTopicCtrl.text = config.gripperDepthTopic;
    _gripperCameraInfoTopicCtrl.text = config.gripperCameraInfoTopic;
    _gripperPointcloudTopicCtrl.text = config.gripperPointcloudTopic;
    _useGripperVision = config.useGripperVision;
    _gripperVisionMaxInferenceHzCtrl.text = config.gripperVisionMaxInferenceHz
        .toString();
    _lidarTopicCtrl.text = config.lidarTopic;
    _imuTopicCtrl.text = config.imuTopic;
    _debug = config.debug;
    _enableSkillLearning = config.enableSkillLearning;
    _skillLearningSuccessSampleRateCtrl.text = config
        .skillLearningSuccessSampleRate
        .toString();
    _skillLearningReflectIntervalSecCtrl.text = config
        .skillLearningReflectIntervalSec
        .toString();
    _taskQueueMaxSizeCtrl.text = config.taskQueueMaxSize.toString();
    _llmFailFast = config.llmFailFast;
    _strictConfig = config.strictConfig;
    _enableTaskDecomposition = config.enableTaskDecomposition;
    _taskDecompositionMaxStepsCtrl.text = config.taskDecompositionMaxSteps
        .toString();
    _taskStepMaxRetriesCtrl.text = config.taskStepMaxRetries.toString();
    _taskDecompositionWaitMarginCapSecCtrl.text = config
        .taskDecompositionWaitMarginCapSec
        .toString();
    _langsmithTracing = config.langsmithTracing;
    _langsmithApiKeyCtrl.text = config.langsmithApiKey;
    _langsmithProjectCtrl.text = config.langsmithProject;
    _langsmithEndpointCtrl.text = config.langsmithEndpoint;
    _langsmithWorkspaceIdCtrl.text = config.langsmithWorkspaceId;
    _system1Router = config.system1Router.isEmpty
        ? 'rule'
        : config.system1Router;
    _system1Shadow = config.system1Shadow;
    _system1ShadowLogCtrl.text = config.system1ShadowLog;
    _system1Scope = config.system1Scope.isEmpty
        ? 'readonly'
        : config.system1Scope;
    _system1EndpointCtrl.text = config.system1Endpoint;
    _system1ProviderCtrl.text = config.system1Provider.isEmpty
        ? 'laya'
        : config.system1Provider;
    _system1TimeoutMsCtrl.text = config.system1TimeoutMs <= 0
        ? '300'
        : config.system1TimeoutMs.toString();
    _system1ConfThresholdsJsonCtrl.text =
        config.system1ConfThresholdsJson.isEmpty
        ? RoboClawConfig.defaultSystem1ConfThresholdsJson
        : config.system1ConfThresholdsJson;
    _system1SkillsCtrl.text = config.system1Skills;
    _system1MaxOptionsCtrl.text = config.system1MaxOptions < 2
        ? '12'
        : config.system1MaxOptions.toString();
    _system1ApiKeyCtrl.text = config.system1ApiKey;
    _maestroIpCtrl.text = config.maestroIp;
    _robotPortCtrl.text = config.robotPort.toString();
    _robotIdCtrl.text = config.robotId;
    _robotSiteIdCtrl.text = config.robotSiteId;
    _robotMapIdCtrl.text = config.robotMapId;
    _robotMapVersionCtrl.text = config.robotMapVersion;
    _robotMapFrameIdCtrl.text = config.robotMapFrameId;
    _maestroDisconnectPolicy = config.maestroDisconnectPolicy;
    _fleetHeartbeatSecCtrl.text = config.fleetHeartbeatSec.toString();
    _fleetCommandJournalPathCtrl.text = config.fleetCommandJournalPath;
    _fleetSkillsGuideFileCtrl.text = config.fleetSkillsGuideFile;
    _fleetControlTls = config.fleetControlTls;
    _fleetControlCaCertCtrl.text = config.fleetControlCaCert;
    _fleetControlClientCertCtrl.text = config.fleetControlClientCert;
    _fleetControlClientKeyCtrl.text = config.fleetControlClientKey;
  }

  // RoboClawConfig()의 기본값을 그대로 신뢰하여 폼을 초기화한다.
  // 필드 기본값이 두 곳(여기와 모델 생성자)에서 따로 관리되면 한쪽만 바뀌었을 때
  // 조용히 어긋나므로, 값 나열 대신 모델 생성자를 단일 소스로 사용한다.
  void _clearForm() {
    _populateForm(RoboClawConfig(name: '', robotName: '', environment: ''));
  }

  Map<String, dynamic> _buildOllamaOptions() {
    return ConfigFormMapper.buildOllamaOptions(
      numCtx: _ollamaNumCtxCtrl.text,
      temperature: _ollamaTemperatureCtrl.text,
      repeatPenalty: _ollamaRepeatPenaltyCtrl.text,
      repeatLastN: _ollamaRepeatLastNCtrl.text,
      seed: _ollamaSeedCtrl.text,
      numPredict: _ollamaNumPredictCtrl.text,
      topK: _ollamaTopKCtrl.text,
      topP: _ollamaTopPCtrl.text,
      minP: _ollamaMinPCtrl.text,
      think: _ollamaThink,
      extraOptions: _ollamaExtraOptions,
    );
  }

  void _resetOllamaOptionsToDefault() {
    _ollamaNumCtxCtrl.text = '8192';
    _ollamaTemperatureCtrl.text = '0.7';
    _ollamaRepeatPenaltyCtrl.text = '1.1';
    _ollamaRepeatLastNCtrl.text = '64';
    _ollamaSeedCtrl.text = '42';
    _ollamaNumPredictCtrl.text = '-1';
    _ollamaTopKCtrl.text = '40';
    _ollamaTopPCtrl.text = '0.9';
    _ollamaMinPCtrl.text = '0.0';
    _ollamaThink = 'unset';
    _ollamaExtraOptions = {};
  }

  Future<void> _exportFile(String filename) async {
    if (_selectedConfig == null) return;

    final cfg = _selectedConfig!;
    switch (filename) {
      case '.env':
        await _downloadEnvFile(cfg);
        break;
      case 'ROBOT.md':
        DownloadHelper.downloadTextFile(cfg.soulContent, 'ROBOT.md');
        break;
      case 'SKILLS.md':
        DownloadHelper.downloadTextFile(cfg.skillsContent, 'SKILLS.md');
        break;
      case 'TROUBLESHOOTING.md':
        DownloadHelper.downloadTextFile(
          cfg.troubleshootingContent,
          'TROUBLESHOOTING.md',
        );
        break;
      case 'ROBOT_LIMITS.json':
        DownloadHelper.downloadTextFile(cfg.limitsContent, 'ROBOT_LIMITS.json');
        break;
      case 'all':
        await _downloadAllFiles(cfg);
        break;
    }
  }

  Future<void> _downloadEnvFile(RoboClawConfig cfg) async {
    try {
      final content = await ApiService.fetchConfigFile(cfg.id!, '.env');
      DownloadHelper.downloadTextFile(content, '.env');
    } on ApiException catch (e) {
      _showError('${'.env 파일 조회 실패: '.tr}${e.message}');
    } catch (e) {
      _showError('${'.env 파일 조회 중 에러 발생: '.tr}$e');
    }
  }

  Future<void> _downloadAllFiles(RoboClawConfig cfg) async {
    try {
      final env = await ApiService.fetchConfigFile(cfg.id!, '.env');
      final fileMap = {
        '.env': env,
        'ROBOT.md': cfg.soulContent,
        'SKILLS.md': cfg.skillsContent,
        'TROUBLESHOOTING.md': cfg.troubleshootingContent,
        'ROBOT_LIMITS.json': cfg.limitsContent,
      };
      DownloadHelper.downloadZipFile(
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  // --- Layout Builders (Configs) ---

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
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
              onPressed: _saveConfig,
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConfigBasicSection(
                isEditing: _isEditing,
                nameCtrl: _nameCtrl,
                robotCtrl: _robotCtrl,
                envCtrl: _envCtrl,
                descCtrl: _descCtrl,
                rosDomainCtrl: _rosDomainCtrl,
                agentIdCtrl: _agentIdCtrl,
                debug: _debug,
                onDebugChanged: (val) => setState(() => _debug = val),
              ),
              const SizedBox(height: 28),
              ConfigLlmSection(
                isEditing: _isEditing,
                llmProvider: _llmProvider,
                llmModelCtrl: _llmModelCtrl,
                azureEndpointCtrl: _azureEndpointCtrl,
                azureApiKeyCtrl: _azureApiKeyCtrl,
                openaiApiKeyCtrl: _openaiApiKeyCtrl,
                anthropicApiKeyCtrl: _anthropicApiKeyCtrl,
                ollamaBaseUrlCtrl: _ollamaBaseUrlCtrl,
                ollamaNumCtxCtrl: _ollamaNumCtxCtrl,
                ollamaTemperatureCtrl: _ollamaTemperatureCtrl,
                ollamaRepeatPenaltyCtrl: _ollamaRepeatPenaltyCtrl,
                ollamaRepeatLastNCtrl: _ollamaRepeatLastNCtrl,
                ollamaSeedCtrl: _ollamaSeedCtrl,
                ollamaNumPredictCtrl: _ollamaNumPredictCtrl,
                ollamaTopKCtrl: _ollamaTopKCtrl,
                ollamaTopPCtrl: _ollamaTopPCtrl,
                ollamaMinPCtrl: _ollamaMinPCtrl,
                onProviderChanged: (val) => setState(() => _llmProvider = val!),
                onApplyOllamaTemplate: () {
                  setState(() {
                    _ollamaNumCtxCtrl.text = '8192';
                    _ollamaTemperatureCtrl.text = '0.7';
                    _ollamaRepeatPenaltyCtrl.text = '1.1';
                    _ollamaRepeatLastNCtrl.text = '64';
                    _ollamaSeedCtrl.text = '42';
                    _ollamaNumPredictCtrl.text = '-1';
                    _ollamaTopKCtrl.text = '40';
                    _ollamaTopPCtrl.text = '0.9';
                    _ollamaMinPCtrl.text = '0.0';
                    _ollamaThink = 'unset';
                  });
                },
                ollamaThink: _ollamaThink,
                onOllamaThinkChanged: (val) =>
                    setState(() => _ollamaThink = val ?? 'unset'),
              ),
              const SizedBox(height: 28),
              ConfigRagSection(
                isEditing: _isEditing,
                enableRag: _enableRag,
                onEnableRagChanged: (val) => setState(() => _enableRag = val),
                embeddingModelCtrl: _embeddingModelCtrl,
                embeddingProviderCtrl: _embeddingProviderCtrl,
                embeddingBaseUrlCtrl: _embeddingBaseUrlCtrl,
                embeddingApiKeyCtrl: _embeddingApiKeyCtrl,
                vectorBackendCtrl: _vectorBackendCtrl,
                qdrantUrlCtrl: _qdrantUrlCtrl,
                qdrantCollCtrl: _qdrantCollCtrl,
                qdrantApiKeyCtrl: _qdrantApiKeyCtrl,
                qdrantTimeoutSecCtrl: _qdrantTimeoutSecCtrl,
                ragTopKCtrl: _ragTopKCtrl,
                ragScoreThresholdCtrl: _ragScoreThresholdCtrl,
                ragLocalMirror: _ragLocalMirror,
                onRagLocalMirrorChanged: (val) =>
                    setState(() => _ragLocalMirror = val),
                memoryDirCtrl: _memoryDirCtrl,
              ),
              const SizedBox(height: 28),
              ConfigMessengerSection(
                isEditing: _isEditing,
                enableDiscord: _enableDiscord,
                enableSlack: _enableSlack,
                enableTelegram: _enableTelegram,
                enableGrpc: _enableGrpc,
                useGrpc: _useGrpc,
                enableGrpcClient: _enableGrpcClient,
                onDiscordChanged: (val) => setState(() => _enableDiscord = val),
                onSlackChanged: (val) => setState(() => _enableSlack = val),
                onTelegramChanged: (val) =>
                    setState(() => _enableTelegram = val),
                onGrpcChanged: (val) => setState(() => _enableGrpc = val),
                onUseGrpcChanged: (val) => setState(() => _useGrpc = val),
                onGrpcClientChanged: (val) =>
                    setState(() => _enableGrpcClient = val),
                discordTokenCtrl: _discordTokenCtrl,
                slackAppTokenCtrl: _slackAppTokenCtrl,
                slackBotTokenCtrl: _slackBotTokenCtrl,
                telegramTokenCtrl: _telegramTokenCtrl,
                grpcTargetHostCtrl: _grpcTargetHostCtrl,
                grpcTargetPortCtrl: _grpcTargetPortCtrl,
                grpcTargetPeersJsonCtrl: _grpcTargetPeersJsonCtrl,
                grpcPeerTokenCtrl: _grpcPeerTokenCtrl,
                grpcPortCtrl: _grpcPortCtrl,
              ),
              const SizedBox(height: 28),
              ConfigHttpSecSection(
                isEditing: _isEditing,
                httpHostCtrl: _httpHostCtrl,
                httpPortCtrl: _httpPortCtrl,
                httpReadonlyTokenCtrl: _httpReadonlyTokenCtrl,
                httpControlTokenCtrl: _httpControlTokenCtrl,
                httpAllowedCidrsCtrl: _httpAllowedCidrsCtrl,
                httpRateLimitCtrl: _httpRateLimitCtrl,
                httpAllowedSkillsCtrl: _httpAllowedSkillsCtrl,
                httpBlockedSkillsCtrl: _httpBlockedSkillsCtrl,
              ),
              const SizedBox(height: 28),
              ConfigDashboardSection(
                isEditing: _isEditing,
                dashboardHostCtrl: _dashboardHostCtrl,
                dashboardPortCtrl: _dashboardPortCtrl,
              ),
              const SizedBox(height: 28),
              ConfigPathSection(
                isEditing: _isEditing,
                agentWorkspaceDirCtrl: _agentWorkspaceDirCtrl,
                butlerScriptsDirCtrl: _butlerScriptsDirCtrl,
                butlerSourceDirCtrl: _butlerSourceDirCtrl,
                configDirCtrl: _configDirCtrl,
                systemPromptFileCtrl: _systemPromptFileCtrl,
                robotDescriptionFileCtrl: _robotDescriptionFileCtrl,
              ),
              const SizedBox(height: 28),
              ConfigCameraSection(
                isEditing: _isEditing,
                cameraTopicCtrl: _cameraTopicCtrl,
                useVision: _useVision,
                onUseVisionChanged: (val) => setState(() => _useVision = val),
                visionModelPathCtrl: _visionModelPathCtrl,
                gripperCameraTopicCtrl: _gripperCameraTopicCtrl,
                gripperDepthTopicCtrl: _gripperDepthTopicCtrl,
                gripperCameraInfoTopicCtrl: _gripperCameraInfoTopicCtrl,
                gripperPointcloudTopicCtrl: _gripperPointcloudTopicCtrl,
                useGripperVision: _useGripperVision,
                onUseGripperVisionChanged: (val) =>
                    setState(() => _useGripperVision = val),
                gripperVisionMaxInferenceHzCtrl:
                    _gripperVisionMaxInferenceHzCtrl,
                lidarTopicCtrl: _lidarTopicCtrl,
                imuTopicCtrl: _imuTopicCtrl,
              ),
              const SizedBox(height: 28),
              ConfigLearningSection(
                isEditing: _isEditing,
                enableSkillLearning: _enableSkillLearning,
                onEnableSkillLearningChanged: (val) =>
                    setState(() => _enableSkillLearning = val),
                skillLearningSuccessSampleRateCtrl:
                    _skillLearningSuccessSampleRateCtrl,
                skillLearningReflectIntervalSecCtrl:
                    _skillLearningReflectIntervalSecCtrl,
              ),
              const SizedBox(height: 28),
              ConfigMarkdownSection(
                isEditing: _isEditing,
                soulCtrl: _soulCtrl,
                skillsCtrl: _skillsCtrl,
                troubleCtrl: _troubleCtrl,
                limitsCtrl: _limitsCtrl,
              ),
              const SizedBox(height: 28),
              ConfigMcpSection(
                isEditing: _isEditing,
                enableMcp: _enableMcp,
                onEnableMcpChanged: (val) => setState(() => _enableMcp = val),
                mcpServersJsonCtrl: _mcpServersJsonCtrl,
              ),
              const SizedBox(height: 28),
              ConfigTaskQueueSection(
                isEditing: _isEditing,
                taskQueueMaxSizeCtrl: _taskQueueMaxSizeCtrl,
                llmFailFast: _llmFailFast,
                onLlmFailFastChanged: (val) =>
                    setState(() => _llmFailFast = val),
                strictConfig: _strictConfig,
                onStrictConfigChanged: (val) =>
                    setState(() => _strictConfig = val),
                enableTaskDecomposition: _enableTaskDecomposition,
                onEnableTaskDecompositionChanged: (val) =>
                    setState(() => _enableTaskDecomposition = val),
                taskDecompositionMaxStepsCtrl: _taskDecompositionMaxStepsCtrl,
                taskStepMaxRetriesCtrl: _taskStepMaxRetriesCtrl,
                taskDecompositionWaitMarginCapSecCtrl:
                    _taskDecompositionWaitMarginCapSecCtrl,
              ),
              const SizedBox(height: 28),
              ConfigLangsmithSection(
                isEditing: _isEditing,
                langsmithTracing: _langsmithTracing,
                onLangsmithTracingChanged: (val) =>
                    setState(() => _langsmithTracing = val),
                langsmithApiKeyCtrl: _langsmithApiKeyCtrl,
                langsmithProjectCtrl: _langsmithProjectCtrl,
                langsmithEndpointCtrl: _langsmithEndpointCtrl,
                langsmithWorkspaceIdCtrl: _langsmithWorkspaceIdCtrl,
              ),
              const SizedBox(height: 28),
              ConfigSystem1Section(
                isEditing: _isEditing,
                router: _system1Router,
                onRouterChanged: (value) =>
                    setState(() => _system1Router = value ?? 'rule'),
                shadow: _system1Shadow,
                onShadowChanged: (value) =>
                    setState(() => _system1Shadow = value),
                shadowLogCtrl: _system1ShadowLogCtrl,
                scope: _system1Scope,
                onScopeChanged: (value) =>
                    setState(() => _system1Scope = value ?? 'readonly'),
                endpointCtrl: _system1EndpointCtrl,
                providerCtrl: _system1ProviderCtrl,
                timeoutMsCtrl: _system1TimeoutMsCtrl,
                confThresholdsJsonCtrl: _system1ConfThresholdsJsonCtrl,
                skillsCtrl: _system1SkillsCtrl,
                maxOptionsCtrl: _system1MaxOptionsCtrl,
                apiKeyCtrl: _system1ApiKeyCtrl,
              ),
              const SizedBox(height: 28),
              ConfigFleetSection(
                isEditing: _isEditing,
                maestroIpCtrl: _maestroIpCtrl,
                robotPortCtrl: _robotPortCtrl,
                robotIdCtrl: _robotIdCtrl,
                robotSiteIdCtrl: _robotSiteIdCtrl,
                robotMapIdCtrl: _robotMapIdCtrl,
                robotMapVersionCtrl: _robotMapVersionCtrl,
                robotMapFrameIdCtrl: _robotMapFrameIdCtrl,
                disconnectPolicy: _maestroDisconnectPolicy,
                onDisconnectPolicyChanged: (val) => setState(
                  () => _maestroDisconnectPolicy = val ?? 'complete',
                ),
                heartbeatSecCtrl: _fleetHeartbeatSecCtrl,
                commandJournalPathCtrl: _fleetCommandJournalPathCtrl,
                skillsGuideFileCtrl: _fleetSkillsGuideFileCtrl,
                controlTls: _fleetControlTls,
                onControlTlsChanged: (val) =>
                    setState(() => _fleetControlTls = val),
                controlCaCertCtrl: _fleetControlCaCertCtrl,
                controlClientCertCtrl: _fleetControlClientCertCtrl,
                controlClientKeyCtrl: _fleetControlClientKeyCtrl,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
