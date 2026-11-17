// frontend/lib/widgets/config_editor_form.dart
//
// ConfigTab 우측 패널의 그룹별 폼 구성. 값 접근은
// ConfigFormFields(어댑터)로 위임한다.

import 'package:material_ui/material_ui.dart';

import '../api/admin_api.dart';
import '../features/configs/config_form_fields.dart';
import 'config_fleet_section.dart';
import 'config_form_group_layout.dart';
import 'config_form_sections.dart';

class ConfigEditorForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final ConfigFormFields fields;
  final bool isEditing;
  final AdminApi api;
  final VoidCallback onChanged;

  const ConfigEditorForm({
    super.key,
    required this.formKey,
    required this.fields,
    required this.isEditing,
    required this.api,
    required this.onChanged,
  });

  void _onFlag(String apiKey, bool value) {
    fields.setFlag(apiKey, value);
    onChanged();
  }

  void _onChoice(String apiKey, String value) {
    fields.setChoice(apiKey, value);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ConfigGroupNavigator(
        groups: [
          ConfigFormGroup(
            title: '프로필·ROS 환경',
            icon: Icons.badge_outlined,
            sections: [
              ConfigBasicSection(
                isEditing: isEditing,
                nameCtrl: fields.text('name'),
                robotCtrl: fields.text('robot_name'),
                envCtrl: fields.text('environment'),
                descCtrl: fields.text('description'),
                rosDomainCtrl: fields.text('ros_domain_id'),
                agentIdCtrl: fields.text('agent_id'),
                debug: fields.flag('debug'),
                onDebugChanged: (val) => _onFlag('debug', val),
              ),
            ],
          ),
          ConfigFormGroup(
            title: 'AI 모델·지식',
            icon: Icons.psychology_outlined,
            sections: [
              ConfigLlmSection(
                isEditing: isEditing,
                llmProvider: fields.choice('llm_provider'),
                llmModelCtrl: fields.text('llm_model'),
                llmToolCalling: fields.flag('llm_tool_calling'),
                onLlmToolCallingChanged: (val) =>
                    _onFlag('llm_tool_calling', val),
                azureEndpointCtrl: fields.text('azure_openai_endpoint'),
                azureApiKeyCtrl: fields.text('azure_openai_api_key'),
                openaiApiKeyCtrl: fields.text('openai_api_key'),
                anthropicApiKeyCtrl: fields.text('anthropic_api_key'),
                ollamaBaseUrlCtrl: fields.text('ollama_base_url'),
                ollamaNumCtxCtrl: fields.ollamaText('num_ctx'),
                ollamaTemperatureCtrl: fields.ollamaText('temperature'),
                ollamaRepeatPenaltyCtrl: fields.ollamaText('repeat_penalty'),
                ollamaRepeatLastNCtrl: fields.ollamaText('repeat_last_n'),
                ollamaSeedCtrl: fields.ollamaText('seed'),
                ollamaNumPredictCtrl: fields.ollamaText('num_predict'),
                ollamaTopKCtrl: fields.ollamaText('top_k'),
                ollamaTopPCtrl: fields.ollamaText('top_p'),
                ollamaMinPCtrl: fields.ollamaText('min_p'),
                onProviderChanged: (val) => _onChoice('llm_provider', val!),
                onApplyOllamaTemplate: () {
                  fields.applyOllamaTemplate();
                  onChanged();
                },
                ollamaThink: fields.ollamaThink,
                onOllamaThinkChanged: (val) {
                  fields.setOllamaThink(val ?? 'unset');
                  onChanged();
                },
              ),
              ConfigRagSection(
                isEditing: isEditing,
                enableRag: fields.flag('enable_rag'),
                onEnableRagChanged: (val) => _onFlag('enable_rag', val),
                embeddingModelCtrl: fields.text('llm_embedding_model'),
                embeddingProviderCtrl: fields.text('llm_embedding_provider'),
                embeddingBaseUrlCtrl: fields.text('llm_embedding_base_url'),
                embeddingApiKeyCtrl: fields.text('llm_embedding_api_key'),
                vectorBackendCtrl: fields.text('rag_vector_backend'),
                qdrantUrlCtrl: fields.text('qdrant_url'),
                qdrantCollCtrl: fields.text('qdrant_collection'),
                qdrantApiKeyCtrl: fields.text('qdrant_api_key'),
                qdrantTimeoutSecCtrl: fields.text('qdrant_timeout_sec'),
                ragTopKCtrl: fields.text('rag_top_k'),
                ragScoreThresholdCtrl: fields.text('rag_score_threshold'),
                ragLocalMirror: fields.flag('rag_local_mirror'),
                onRagLocalMirrorChanged: (val) =>
                    _onFlag('rag_local_mirror', val),
                memoryDirCtrl: fields.text('memory_dir'),
              ),
              ConfigSystem1Section(
                isEditing: isEditing,
                router: fields.choice('system1_router'),
                onRouterChanged: (value) =>
                    _onChoice('system1_router', value ?? 'rule'),
                shadow: fields.flag('system1_shadow'),
                onShadowChanged: (value) => _onFlag('system1_shadow', value),
                shadowLogCtrl: fields.text('system1_shadow_log'),
                scope: fields.choice('system1_scope'),
                onScopeChanged: (value) =>
                    _onChoice('system1_scope', value ?? 'readonly'),
                stepRouting: fields.choice('system1_step_routing'),
                onStepRoutingChanged: (value) =>
                    _onChoice('system1_step_routing', value ?? 'shadow'),
                endpointCtrl: fields.text('system1_endpoint'),
                providerCtrl: fields.text('system1_provider'),
                timeoutMsCtrl: fields.text('system1_timeout_ms'),
                confThresholdsJsonCtrl: fields.text(
                  'system1_conf_thresholds_json',
                ),
                skillsCtrl: fields.text('system1_skills'),
                maxOptionsCtrl: fields.text('system1_max_options'),
                apiKeyCtrl: fields.text('system1_api_key'),
              ),
            ],
          ),
          ConfigFormGroup(
            title: '로봇 기능·센서',
            icon: Icons.precision_manufacturing_outlined,
            sections: [
              ConfigCleanupDemoSection(
                isEditing: isEditing,
                enabled: fields.flag('cloid_cleanup_demo_enabled'),
                onEnabledChanged: (value) =>
                    _onFlag('cloid_cleanup_demo_enabled', value),
                motionIdsJsonCtrl: fields.text(
                  'cloid_cleanup_demo_motion_ids_json',
                ),
                expressionEnabled: fields.flag('cloid_expression_enabled'),
                onExpressionEnabledChanged: (value) =>
                    _onFlag('cloid_expression_enabled', value),
                navigationPoseEnabled: fields.flag(
                  'cloid_navigation_pose_enabled',
                ),
                onNavigationPoseEnabledChanged: (value) =>
                    _onFlag('cloid_navigation_pose_enabled', value),
              ),
              ConfigCameraSection(
                isEditing: isEditing,
                cameraTopicCtrl: fields.text('camera_topic'),
                useVision: fields.flag('use_vision'),
                onUseVisionChanged: (val) => _onFlag('use_vision', val),
                visionModelPathCtrl: fields.text('vision_model_path'),
                gripperCameraTopicCtrl: fields.text('gripper_camera_topic'),
                gripperDepthTopicCtrl: fields.text('gripper_depth_topic'),
                gripperCameraInfoTopicCtrl: fields.text(
                  'gripper_camera_info_topic',
                ),
                gripperPointcloudTopicCtrl: fields.text(
                  'gripper_pointcloud_topic',
                ),
                useGripperVision: fields.flag('use_gripper_vision'),
                onUseGripperVisionChanged: (val) =>
                    _onFlag('use_gripper_vision', val),
                gripperVisionMaxInferenceHzCtrl: fields.text(
                  'gripper_vision_max_inference_hz',
                ),
                lidarTopicCtrl: fields.text('lidar_topic'),
                imuTopicCtrl: fields.text('imu_topic'),
              ),
            ],
          ),
          ConfigFormGroup(
            title: '에이전트 동작·자료',
            icon: Icons.tune,
            sections: [
              ConfigTaskQueueSection(
                isEditing: isEditing,
                taskQueueMaxSizeCtrl: fields.text('task_queue_max_size'),
                llmFailFast: fields.flag('llm_fail_fast'),
                onLlmFailFastChanged: (val) => _onFlag('llm_fail_fast', val),
                strictConfig: fields.flag('strict_config'),
                onStrictConfigChanged: (val) => _onFlag('strict_config', val),
                enableTaskDecomposition: fields.flag(
                  'enable_task_decomposition',
                ),
                onEnableTaskDecompositionChanged: (val) =>
                    _onFlag('enable_task_decomposition', val),
                taskDecompositionMaxStepsCtrl: fields.text(
                  'task_decomposition_max_steps',
                ),
                taskStepMaxRetriesCtrl: fields.text('task_step_max_retries'),
                taskDecompositionWaitMarginCapSecCtrl: fields.text(
                  'task_decomposition_wait_margin_cap_sec',
                ),
              ),
              ConfigLearningSection(
                isEditing: isEditing,
                enableSkillLearning: fields.flag('enable_skill_learning'),
                onEnableSkillLearningChanged: (val) =>
                    _onFlag('enable_skill_learning', val),
                skillLearningSuccessSampleRateCtrl: fields.text(
                  'skill_learning_success_sample_rate',
                ),
                skillLearningReflectIntervalSecCtrl: fields.text(
                  'skill_learning_reflect_interval_sec',
                ),
              ),
              ConfigMarkdownSection(
                isEditing: isEditing,
                soulCtrl: fields.text('soul_content'),
                skillsCtrl: fields.text('skills_content'),
                troubleCtrl: fields.text('troubleshooting_content'),
                limitsCtrl: fields.text('limits_content'),
              ),
              ConfigPathSection(
                isEditing: isEditing,
                agentWorkspaceDirCtrl: fields.text('agent_workspace_dir'),
                butlerScriptsDirCtrl: fields.text('butler_scripts_dir'),
                butlerSourceDirCtrl: fields.text('butler_source_dir'),
                configDirCtrl: fields.text('config_dir'),
                systemPromptFileCtrl: fields.text('system_prompt_file'),
                robotDescriptionFileCtrl: fields.text('robot_description_file'),
                cleanupRunLogPathCtrl: fields.text('cleanup_run_log_path'),
              ),
            ],
          ),
          ConfigFormGroup(
            title: '외부 연동',
            icon: Icons.hub_outlined,
            sections: [
              ConfigMessengerSection(
                isEditing: isEditing,
                maestroEnabled: fields.flag('maestro_enabled'),
                enableDiscord: fields.flag('enable_discord'),
                enableSlack: fields.flag('enable_slack'),
                enableTelegram: fields.flag('enable_telegram'),
                enableGrpc: fields.flag('enable_grpc'),
                useGrpc: fields.flag('use_grpc'),
                enableGrpcClient: fields.flag('enable_grpc_client'),
                onDiscordChanged: (val) => _onFlag('enable_discord', val),
                onSlackChanged: (val) => _onFlag('enable_slack', val),
                onTelegramChanged: (val) => _onFlag('enable_telegram', val),
                onGrpcChanged: (val) => _onFlag('enable_grpc', val),
                onUseGrpcChanged: (val) => _onFlag('use_grpc', val),
                onGrpcClientChanged: (val) =>
                    _onFlag('enable_grpc_client', val),
                discordTokenCtrl: fields.text('discord_bot_token'),
                slackAppTokenCtrl: fields.text('slack_app_token'),
                slackBotTokenCtrl: fields.text('slack_bot_token'),
                telegramTokenCtrl: fields.text('telegram_bot_token'),
                grpcTargetHostCtrl: fields.text('grpc_target_host'),
                grpcTargetPortCtrl: fields.text('grpc_target_port'),
                grpcTargetPeersJsonCtrl: fields.text('grpc_target_peers_json'),
                grpcPeerTokenCtrl: fields.text('grpc_peer_token'),
                grpcPortCtrl: fields.text('grpc_port'),
              ),
              ConfigMcpSection(
                api: api,
                isEditing: isEditing,
                enableMcp: fields.flag('enable_mcp'),
                onEnableMcpChanged: (val) => _onFlag('enable_mcp', val),
                mcpServersJsonCtrl: fields.text('mcp_servers_json'),
              ),
              ConfigFleetSection(
                isEditing: isEditing,
                maestroEnabled: fields.flag('maestro_enabled'),
                onMaestroEnabledChanged: (val) =>
                    _onFlag('maestro_enabled', val),
                maestroIpCtrl: fields.text('maestro_ip'),
                robotPortCtrl: fields.text('robot_port'),
                robotIdCtrl: fields.text('robot_id'),
                robotSiteIdCtrl: fields.text('robot_site_id'),
                robotMapIdCtrl: fields.text('robot_map_id'),
                robotMapVersionCtrl: fields.text('robot_map_version'),
                robotMapFrameIdCtrl: fields.text('robot_map_frame_id'),
                disconnectPolicy: fields.choice('maestro_disconnect_policy'),
                onDisconnectPolicyChanged: (val) =>
                    _onChoice('maestro_disconnect_policy', val ?? 'complete'),
                heartbeatSecCtrl: fields.text('fleet_heartbeat_sec'),
                commandJournalPathCtrl: fields.text(
                  'fleet_command_journal_path',
                ),
                skillsGuideFileCtrl: fields.text('skills_guide_file'),
                controlTls: fields.flag('fleet_control_tls'),
                onControlTlsChanged: (val) => _onFlag('fleet_control_tls', val),
                controlCaCertCtrl: fields.text('fleet_control_ca_cert'),
                controlClientCertCtrl: fields.text('fleet_control_client_cert'),
                controlClientKeyCtrl: fields.text('fleet_control_client_key'),
              ),
            ],
          ),
          ConfigFormGroup(
            title: '서버·보안·관측',
            icon: Icons.security_outlined,
            sections: [
              ConfigHttpSecSection(
                isEditing: isEditing,
                httpHostCtrl: fields.text('http_host'),
                httpPortCtrl: fields.text('http_port'),
                httpReadonlyTokenCtrl: fields.text('http_readonly_token'),
                httpControlTokenCtrl: fields.text('http_control_token'),
                httpAllowedCidrsCtrl: fields.text('http_allowed_cidrs_json'),
                httpRateLimitCtrl: fields.text('http_rate_limit_per_minute'),
                httpAllowedSkillsCtrl: fields.text('http_allowed_skills_json'),
                httpBlockedSkillsCtrl: fields.text('http_blocked_skills_json'),
              ),
              ConfigDashboardSection(
                isEditing: isEditing,
                useDashboard: fields.flag('use_dashboard'),
                onUseDashboardChanged: (value) =>
                    _onFlag('use_dashboard', value),
                dashboardHostCtrl: fields.text('dashboard_host'),
                dashboardPortCtrl: fields.text('dashboard_port'),
              ),
              ConfigLangsmithSection(
                isEditing: isEditing,
                langsmithTracing: fields.flag('langsmith_tracing'),
                onLangsmithTracingChanged: (val) =>
                    _onFlag('langsmith_tracing', val),
                langsmithApiKeyCtrl: fields.text('langsmith_api_key'),
                langsmithProjectCtrl: fields.text('langsmith_project'),
                langsmithEndpointCtrl: fields.text('langsmith_endpoint'),
                langsmithWorkspaceIdCtrl: fields.text('langsmith_workspace_id'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
