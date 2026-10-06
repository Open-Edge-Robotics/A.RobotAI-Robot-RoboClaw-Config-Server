// frontend/lib/models/config_model.dart

class RoboClawConfig {
  static const defaultSystem1ConfThresholdsJson =
      '{"smalltalk":0.9,"single_skill":0.85,"skill":0.8,"target_place":0.8,"ambiguous":0.5}';

  final int? id;
  String name;
  String robotName;
  String environment;
  bool isActive;
  String description;

  // ROS 2 설정
  int rosDomainId;
  String agentId;

  // LLM 기본
  String llmProvider;
  String llmModel;

  // 자격 증명
  String azureOpenaiEndpoint;
  String azureOpenaiApiKey;
  String openaiApiKey;
  String anthropicApiKey;

  // Ollama
  String ollamaBaseUrl;
  String ollamaOptionsJson;

  // RAG
  bool enableRag;
  String llmEmbeddingModel;
  String llmEmbeddingProvider;
  String llmEmbeddingBaseUrl;
  String llmEmbeddingApiKey;
  String ragVectorBackend;
  String qdrantUrl;
  String qdrantCollection;

  // Messenger
  bool enableDiscord;
  bool enableTelegram;
  bool enableSlack;
  bool enableGrpc;
  bool useGrpc;
  bool enableGrpcClient;
  int grpcPort;
  String grpcPeerToken;
  String grpcTargetHost;
  int grpcTargetPort;
  String grpcTargetPeersJson;
  String discordBotToken;
  String slackAppToken;
  String slackBotToken;
  String telegramBotToken;

  // HTTP API 보안 설정
  String httpHost;
  int httpPort;
  String httpReadonlyToken;
  String httpControlToken;
  String httpAllowedCidrsJson;
  int httpRateLimitPerMinute;
  String httpAllowedSkillsJson;
  String httpBlockedSkillsJson;

  // Dashboard 웹 노드 설정 (HTTP 채널 포트 8080과 별개)
  String dashboardHost;
  int dashboardPort;

  // MCP 서버 연동
  bool enableMcp;
  String mcpServersJson;

  // RAG 추가 설정
  int ragTopK;
  double ragScoreThreshold;
  String qdrantApiKey;
  double qdrantTimeoutSec;
  bool ragLocalMirror;
  String memoryDir;

  // 경로 및 리소스 설정
  String agentWorkspaceDir;
  String butlerScriptsDir;
  String butlerSourceDir;
  String configDir;
  String systemPromptFile;
  String robotDescriptionFile;

  // 카메라 / 비전 설정
  String cameraTopic;
  bool useVision;
  String visionModelPath;
  String gripperCameraTopic;
  String gripperDepthTopic;
  String gripperCameraInfoTopic;
  String gripperPointcloudTopic;
  bool useGripperVision;
  double gripperVisionMaxInferenceHz;

  // 자가진단용 센서 토픽
  String lidarTopic;
  String imuTopic;

  // 디버그 설정
  bool debug;

  // 스킬 자가학습
  bool enableSkillLearning;
  double skillLearningSuccessSampleRate;
  int skillLearningReflectIntervalSec;

  // 태스크 큐 / 복합 명령 자동 분해
  int taskQueueMaxSize;
  bool llmFailFast;
  bool strictConfig;
  bool enableTaskDecomposition;
  int taskDecompositionMaxSteps;
  int taskStepMaxRetries;
  double taskDecompositionWaitMarginCapSec;

  // LangSmith 트레이싱 / 모니터링 설정
  bool langsmithTracing;
  String langsmithApiKey;
  String langsmithProject;
  String langsmithEndpoint;
  String langsmithWorkspaceId;

  // System 1 Fast Router (contract v2.4.0)
  String system1Router;
  bool system1Shadow;
  String system1ShadowLog;
  String system1Scope;
  String system1Endpoint;
  String system1Provider;
  double system1TimeoutMs;
  String system1ConfThresholdsJson;
  String system1Skills;
  int system1MaxOptions;
  String system1ApiKey;

  // Maestro FleetControl outbound connector (contract v2.2.0)
  String maestroIp;
  int robotPort;
  String robotId;
  String robotSiteId;
  String robotMapId;
  String robotMapVersion;
  String robotMapFrameId;
  String maestroDisconnectPolicy;
  double fleetHeartbeatSec;
  String fleetCommandJournalPath;
  String fleetSkillsGuideFile;
  bool fleetControlTls;
  String fleetControlCaCert;
  String fleetControlClientCert;
  String fleetControlClientKey;

  // Markdown Contents
  String soulContent;
  String skillsContent;
  String troubleshootingContent;
  String limitsContent;

  RoboClawConfig({
    this.id,
    required this.name,
    required this.robotName,
    required this.environment,
    this.isActive = false,
    this.description = '',
    this.rosDomainId = 0,
    this.agentId = '',
    this.llmProvider = 'azure',
    this.llmModel = 'gpt-4o',
    this.azureOpenaiEndpoint = '',
    this.azureOpenaiApiKey = '',
    this.openaiApiKey = '',
    this.anthropicApiKey = '',
    this.ollamaBaseUrl = '',
    this.ollamaOptionsJson = '',
    this.enableRag = false,
    this.llmEmbeddingModel = '',
    this.llmEmbeddingProvider = '',
    this.llmEmbeddingBaseUrl = '',
    this.llmEmbeddingApiKey = '',
    this.ragVectorBackend = '',
    this.qdrantUrl = '',
    this.qdrantCollection = '',
    this.enableDiscord = false,
    this.enableTelegram = false,
    this.enableSlack = false,
    this.enableGrpc = true,
    this.useGrpc = false,
    this.enableGrpcClient = false,
    this.grpcPort = 50052,
    this.grpcPeerToken = '',
    this.grpcTargetHost = '127.0.0.1',
    this.grpcTargetPort = 50051,
    this.grpcTargetPeersJson = '[]',
    this.discordBotToken = '',
    this.slackAppToken = '',
    this.slackBotToken = '',
    this.telegramBotToken = '',
    this.httpHost = '127.0.0.1',
    this.httpPort = 8080,
    this.httpReadonlyToken = '',
    this.httpControlToken = '',
    this.httpAllowedCidrsJson = '[]',
    this.httpRateLimitPerMinute = 60,
    this.httpAllowedSkillsJson = '[]',
    this.httpBlockedSkillsJson = '[]',
    this.dashboardHost = '127.0.0.1',
    this.dashboardPort = 9090,
    this.enableMcp = false,
    this.mcpServersJson = '[]',
    this.ragTopK = 2,
    this.ragScoreThreshold = 0.7,
    this.qdrantApiKey = '',
    this.qdrantTimeoutSec = 5.0,
    this.ragLocalMirror = true,
    this.memoryDir = '',
    this.agentWorkspaceDir = '',
    this.butlerScriptsDir = '',
    this.butlerSourceDir = '',
    this.configDir = '',
    this.systemPromptFile = '',
    this.robotDescriptionFile = '',
    this.cameraTopic = '',
    this.useVision = false,
    this.visionModelPath = '',
    this.gripperCameraTopic = '',
    this.gripperDepthTopic = '',
    this.gripperCameraInfoTopic = '',
    this.gripperPointcloudTopic = '',
    this.useGripperVision = false,
    this.gripperVisionMaxInferenceHz = 5.0,
    this.lidarTopic = '',
    this.imuTopic = '',
    this.debug = true,
    this.enableSkillLearning = false,
    this.skillLearningSuccessSampleRate = 0.1,
    this.skillLearningReflectIntervalSec = 1800,
    this.taskQueueMaxSize = 8,
    this.llmFailFast = false,
    this.strictConfig = false,
    this.enableTaskDecomposition = true,
    this.taskDecompositionMaxSteps = 6,
    this.taskStepMaxRetries = 1,
    this.taskDecompositionWaitMarginCapSec = 1800.0,
    this.langsmithTracing = false,
    this.langsmithApiKey = '',
    this.langsmithProject = 'former-0045-claw',
    this.langsmithEndpoint = '',
    this.langsmithWorkspaceId = '',
    this.system1Router = 'rule',
    this.system1Shadow = false,
    this.system1ShadowLog = '',
    this.system1Scope = 'readonly',
    this.system1Endpoint = '',
    this.system1Provider = 'laya',
    this.system1TimeoutMs = 300.0,
    this.system1ConfThresholdsJson = defaultSystem1ConfThresholdsJson,
    this.system1Skills = '',
    this.system1MaxOptions = 12,
    this.system1ApiKey = '',
    this.maestroIp = '',
    this.robotPort = 50053,
    this.robotId = '',
    this.robotSiteId = '',
    this.robotMapId = '',
    this.robotMapVersion = '',
    this.robotMapFrameId = 'map',
    this.maestroDisconnectPolicy = 'complete',
    this.fleetHeartbeatSec = 1.0,
    this.fleetCommandJournalPath = '/tmp/robo_claw_fleet_commands.sqlite3',
    this.fleetSkillsGuideFile = '',
    this.fleetControlTls = false,
    this.fleetControlCaCert = '',
    this.fleetControlClientCert = '',
    this.fleetControlClientKey = '',
    this.soulContent = '',
    this.skillsContent = '',
    this.troubleshootingContent = '',
    this.limitsContent = '',
  });

  factory RoboClawConfig.fromJson(Map<String, dynamic> json) {
    return RoboClawConfig(
      id: json['ID'],
      name: json['name'] ?? '',
      robotName: json['robot_name'] ?? '',
      environment: json['environment'] ?? '',
      isActive: json['is_active'] ?? false,
      description: json['description'] ?? '',
      rosDomainId: json['ros_domain_id'] ?? 0,
      agentId: json['agent_id'] ?? '',
      llmProvider: json['llm_provider'] ?? 'azure',
      llmModel: json['llm_model'] ?? 'gpt-4o',
      azureOpenaiEndpoint: json['azure_openai_endpoint'] ?? '',
      azureOpenaiApiKey: json['azure_openai_api_key'] ?? '',
      openaiApiKey: json['openai_api_key'] ?? '',
      anthropicApiKey: json['anthropic_api_key'] ?? '',
      ollamaBaseUrl: json['ollama_base_url'] ?? '',
      ollamaOptionsJson: json['ollama_options_json'] ?? '',
      enableRag: json['enable_rag'] ?? false,
      llmEmbeddingModel: json['llm_embedding_model'] ?? '',
      llmEmbeddingProvider: json['llm_embedding_provider'] ?? '',
      llmEmbeddingBaseUrl: json['llm_embedding_base_url'] ?? '',
      llmEmbeddingApiKey: json['llm_embedding_api_key'] ?? '',
      ragVectorBackend: json['rag_vector_backend'] ?? '',
      qdrantUrl: json['qdrant_url'] ?? '',
      qdrantCollection: json['qdrant_collection'] ?? '',
      enableDiscord: json['enable_discord'] ?? false,
      enableTelegram: json['enable_telegram'] ?? false,
      enableSlack: json['enable_slack'] ?? false,
      enableGrpc: json['enable_grpc'] ?? true,
      useGrpc: json['use_grpc'] ?? false,
      enableGrpcClient: json['enable_grpc_client'] ?? false,
      grpcPort: json['grpc_port'] ?? 50052,
      grpcPeerToken: json['grpc_peer_token'] ?? '',
      grpcTargetHost: json['grpc_target_host'] ?? '127.0.0.1',
      grpcTargetPort: json['grpc_target_port'] ?? 50051,
      grpcTargetPeersJson: json['grpc_target_peers_json'] ?? '[]',
      discordBotToken: json['discord_bot_token'] ?? '',
      slackAppToken: json['slack_app_token'] ?? '',
      slackBotToken: json['slack_bot_token'] ?? '',
      telegramBotToken: json['telegram_bot_token'] ?? '',
      httpHost: json['http_host'] ?? '127.0.0.1',
      httpPort: json['http_port'] ?? 8080,
      httpReadonlyToken: json['http_readonly_token'] ?? '',
      httpControlToken: json['http_control_token'] ?? '',
      httpAllowedCidrsJson: json['http_allowed_cidrs_json'] ?? '[]',
      httpRateLimitPerMinute: json['http_rate_limit_per_minute'] ?? 60,
      httpAllowedSkillsJson: json['http_allowed_skills_json'] ?? '[]',
      httpBlockedSkillsJson: json['http_blocked_skills_json'] ?? '[]',
      dashboardHost: json['dashboard_host'] ?? '127.0.0.1',
      dashboardPort: json['dashboard_port'] ?? 9090,
      enableMcp: json['enable_mcp'] ?? false,
      mcpServersJson: json['mcp_servers_json'] ?? '[]',
      ragTopK: json['rag_top_k'] ?? 2,
      ragScoreThreshold: (json['rag_score_threshold'] ?? 0.7).toDouble(),
      qdrantApiKey: json['qdrant_api_key'] ?? '',
      qdrantTimeoutSec: (json['qdrant_timeout_sec'] ?? 5.0).toDouble(),
      ragLocalMirror: json['rag_local_mirror'] ?? true,
      memoryDir: json['memory_dir'] ?? '',
      agentWorkspaceDir: json['agent_workspace_dir'] ?? '',
      butlerScriptsDir: json['butler_scripts_dir'] ?? '',
      butlerSourceDir: json['butler_source_dir'] ?? '',
      configDir: json['config_dir'] ?? '',
      systemPromptFile: json['system_prompt_file'] ?? '',
      robotDescriptionFile: json['robot_description_file'] ?? '',
      cameraTopic: json['camera_topic'] ?? '',
      useVision: json['use_vision'] ?? false,
      visionModelPath: json['vision_model_path'] ?? '',
      gripperCameraTopic: json['gripper_camera_topic'] ?? '',
      gripperDepthTopic: json['gripper_depth_topic'] ?? '',
      gripperCameraInfoTopic: json['gripper_camera_info_topic'] ?? '',
      gripperPointcloudTopic: json['gripper_pointcloud_topic'] ?? '',
      useGripperVision: json['use_gripper_vision'] ?? false,
      gripperVisionMaxInferenceHz:
          (json['gripper_vision_max_inference_hz'] ?? 5.0).toDouble(),
      lidarTopic: json['lidar_topic'] ?? '',
      imuTopic: json['imu_topic'] ?? '',
      debug: json['debug'] ?? true,
      enableSkillLearning: json['enable_skill_learning'] ?? false,
      skillLearningSuccessSampleRate:
          (json['skill_learning_success_sample_rate'] ?? 0.1).toDouble(),
      skillLearningReflectIntervalSec:
          json['skill_learning_reflect_interval_sec'] ?? 1800,
      taskQueueMaxSize: json['task_queue_max_size'] ?? 8,
      llmFailFast: json['llm_fail_fast'] ?? false,
      strictConfig: json['strict_config'] ?? false,
      enableTaskDecomposition: json['enable_task_decomposition'] ?? true,
      taskDecompositionMaxSteps: json['task_decomposition_max_steps'] ?? 6,
      taskStepMaxRetries: json['task_step_max_retries'] ?? 1,
      taskDecompositionWaitMarginCapSec:
          (json['task_decomposition_wait_margin_cap_sec'] ?? 1800.0).toDouble(),
      langsmithTracing: json['langsmith_tracing'] ?? false,
      langsmithApiKey: json['langsmith_api_key'] ?? '',
      langsmithProject: json['langsmith_project'] ?? 'former-0045-claw',
      langsmithEndpoint: json['langsmith_endpoint'] ?? '',
      langsmithWorkspaceId: json['langsmith_workspace_id'] ?? '',
      system1Router: json['system1_router'] ?? 'rule',
      system1Shadow: json['system1_shadow'] ?? false,
      system1ShadowLog: json['system1_shadow_log'] ?? '',
      system1Scope: json['system1_scope'] ?? 'readonly',
      system1Endpoint: json['system1_endpoint'] ?? '',
      system1Provider: json['system1_provider'] ?? 'laya',
      system1TimeoutMs: (json['system1_timeout_ms'] ?? 300.0).toDouble(),
      system1ConfThresholdsJson:
          json['system1_conf_thresholds_json'] ??
          defaultSystem1ConfThresholdsJson,
      system1Skills: json['system1_skills'] ?? '',
      system1MaxOptions: json['system1_max_options'] ?? 12,
      system1ApiKey: json['system1_api_key'] ?? '',
      maestroIp: json['maestro_ip'] ?? '',
      robotPort: json['robot_port'] ?? 50053,
      robotId: json['robot_id'] ?? '',
      robotSiteId: json['robot_site_id'] ?? '',
      robotMapId: json['robot_map_id'] ?? '',
      robotMapVersion: json['robot_map_version'] ?? '',
      robotMapFrameId: json['robot_map_frame_id'] ?? 'map',
      maestroDisconnectPolicy: json['maestro_disconnect_policy'] ?? 'complete',
      fleetHeartbeatSec: (json['fleet_heartbeat_sec'] ?? 1.0).toDouble(),
      fleetCommandJournalPath:
          json['fleet_command_journal_path'] ??
          '/tmp/robo_claw_fleet_commands.sqlite3',
      fleetSkillsGuideFile: json['skills_guide_file'] ?? '',
      fleetControlTls: json['fleet_control_tls'] ?? false,
      fleetControlCaCert: json['fleet_control_ca_cert'] ?? '',
      fleetControlClientCert: json['fleet_control_client_cert'] ?? '',
      fleetControlClientKey: json['fleet_control_client_key'] ?? '',
      soulContent: json['soul_content'] ?? '',
      skillsContent: json['skills_content'] ?? '',
      troubleshootingContent: json['troubleshooting_content'] ?? '',
      limitsContent: json['limits_content'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'ID': id,
      'name': name,
      'robot_name': robotName,
      'environment': environment,
      'is_active': isActive,
      'description': description,
      'ros_domain_id': rosDomainId,
      'agent_id': agentId,
      'llm_provider': llmProvider,
      'llm_model': llmModel,
      'azure_openai_endpoint': azureOpenaiEndpoint,
      'azure_openai_api_key': azureOpenaiApiKey,
      'openai_api_key': openaiApiKey,
      'anthropic_api_key': anthropicApiKey,
      'ollama_base_url': ollamaBaseUrl,
      'ollama_options_json': ollamaOptionsJson,
      'enable_rag': enableRag,
      'llm_embedding_model': llmEmbeddingModel,
      'llm_embedding_provider': llmEmbeddingProvider,
      'llm_embedding_base_url': llmEmbeddingBaseUrl,
      'llm_embedding_api_key': llmEmbeddingApiKey,
      'rag_vector_backend': ragVectorBackend,
      'qdrant_url': qdrantUrl,
      'qdrant_collection': qdrantCollection,
      'enable_discord': enableDiscord,
      'enable_telegram': enableTelegram,
      'enable_slack': enableSlack,
      'enable_grpc': enableGrpc,
      'use_grpc': useGrpc,
      'enable_grpc_client': enableGrpcClient,
      'grpc_port': grpcPort,
      'grpc_peer_token': grpcPeerToken,
      'grpc_target_host': grpcTargetHost,
      'grpc_target_port': grpcTargetPort,
      'grpc_target_peers_json': grpcTargetPeersJson,
      'discord_bot_token': discordBotToken,
      'slack_app_token': slackAppToken,
      'slack_bot_token': slackBotToken,
      'telegram_bot_token': telegramBotToken,
      'http_host': httpHost,
      'http_port': httpPort,
      'http_readonly_token': httpReadonlyToken,
      'http_control_token': httpControlToken,
      'http_allowed_cidrs_json': httpAllowedCidrsJson,
      'http_rate_limit_per_minute': httpRateLimitPerMinute,
      'http_allowed_skills_json': httpAllowedSkillsJson,
      'http_blocked_skills_json': httpBlockedSkillsJson,
      'dashboard_host': dashboardHost,
      'dashboard_port': dashboardPort,
      'enable_mcp': enableMcp,
      'mcp_servers_json': mcpServersJson,
      'rag_top_k': ragTopK,
      'rag_score_threshold': ragScoreThreshold,
      'qdrant_api_key': qdrantApiKey,
      'qdrant_timeout_sec': qdrantTimeoutSec,
      'rag_local_mirror': ragLocalMirror,
      'memory_dir': memoryDir,
      'agent_workspace_dir': agentWorkspaceDir,
      'butler_scripts_dir': butlerScriptsDir,
      'butler_source_dir': butlerSourceDir,
      'config_dir': configDir,
      'system_prompt_file': systemPromptFile,
      'robot_description_file': robotDescriptionFile,
      'camera_topic': cameraTopic,
      'use_vision': useVision,
      'vision_model_path': visionModelPath,
      'gripper_camera_topic': gripperCameraTopic,
      'gripper_depth_topic': gripperDepthTopic,
      'gripper_camera_info_topic': gripperCameraInfoTopic,
      'gripper_pointcloud_topic': gripperPointcloudTopic,
      'use_gripper_vision': useGripperVision,
      'gripper_vision_max_inference_hz': gripperVisionMaxInferenceHz,
      'lidar_topic': lidarTopic,
      'imu_topic': imuTopic,
      'debug': debug,
      'enable_skill_learning': enableSkillLearning,
      'skill_learning_success_sample_rate': skillLearningSuccessSampleRate,
      'skill_learning_reflect_interval_sec': skillLearningReflectIntervalSec,
      'task_queue_max_size': taskQueueMaxSize,
      'llm_fail_fast': llmFailFast,
      'strict_config': strictConfig,
      'enable_task_decomposition': enableTaskDecomposition,
      'task_decomposition_max_steps': taskDecompositionMaxSteps,
      'task_step_max_retries': taskStepMaxRetries,
      'task_decomposition_wait_margin_cap_sec':
          taskDecompositionWaitMarginCapSec,
      'langsmith_tracing': langsmithTracing,
      'langsmith_api_key': langsmithApiKey,
      'langsmith_project': langsmithProject,
      'langsmith_endpoint': langsmithEndpoint,
      'langsmith_workspace_id': langsmithWorkspaceId,
      'system1_router': system1Router,
      'system1_shadow': system1Shadow,
      'system1_shadow_log': system1ShadowLog,
      'system1_scope': system1Scope,
      'system1_endpoint': system1Endpoint,
      'system1_provider': system1Provider,
      'system1_timeout_ms': system1TimeoutMs,
      'system1_conf_thresholds_json': system1ConfThresholdsJson,
      'system1_skills': system1Skills,
      'system1_max_options': system1MaxOptions,
      'system1_api_key': system1ApiKey,
      'maestro_ip': maestroIp,
      'robot_port': robotPort,
      'robot_id': robotId,
      'robot_site_id': robotSiteId,
      'robot_map_id': robotMapId,
      'robot_map_version': robotMapVersion,
      'robot_map_frame_id': robotMapFrameId,
      'maestro_disconnect_policy': maestroDisconnectPolicy,
      'fleet_heartbeat_sec': fleetHeartbeatSec,
      'fleet_command_journal_path': fleetCommandJournalPath,
      'skills_guide_file': fleetSkillsGuideFile,
      'fleet_control_tls': fleetControlTls,
      'fleet_control_ca_cert': fleetControlCaCert,
      'fleet_control_client_cert': fleetControlClientCert,
      'fleet_control_client_key': fleetControlClientKey,
      'soul_content': soulContent,
      'skills_content': skillsContent,
      'troubleshooting_content': troubleshootingContent,
      'limits_content': limitsContent,
    };
  }

  RoboClawConfig clone() {
    return RoboClawConfig.fromJson(toJson());
  }
}
