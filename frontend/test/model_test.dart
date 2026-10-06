import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/config_model.dart';
import 'package:frontend/models/scenario_model.dart';

void main() {
  test('RoboClawConfig JSON 직렬화 값을 보존한다', () {
    final config = RoboClawConfig(
      id: 10,
      name: 'office-standard',
      robotName: 'butler',
      environment: 'office',
      isActive: true,
      rosDomainId: 30,
      llmProvider: 'ollama',
      llmModel: 'gemma4:e4b',
      llmEmbeddingProvider: 'openai',
      llmEmbeddingModel: 'text-embedding-3-large',
      llmEmbeddingBaseUrl: 'https://api.openai.com/v1',
      llmEmbeddingApiKey: 'embed-key',
      langsmithWorkspaceId: 'workspace-123',
      limitsContent: '{"max_linear_speed":1.0}',
    );

    final decoded = RoboClawConfig.fromJson(config.toJson());

    expect(decoded.id, 10);
    expect(decoded.name, 'office-standard');
    expect(decoded.robotName, 'butler');
    expect(decoded.environment, 'office');
    expect(decoded.isActive, isTrue);
    expect(decoded.rosDomainId, 30);
    expect(decoded.llmProvider, 'ollama');
    expect(decoded.llmModel, 'gemma4:e4b');
    expect(decoded.llmEmbeddingProvider, 'openai');
    expect(decoded.llmEmbeddingModel, 'text-embedding-3-large');
    expect(decoded.llmEmbeddingBaseUrl, 'https://api.openai.com/v1');
    expect(decoded.llmEmbeddingApiKey, 'embed-key');
    expect(decoded.langsmithWorkspaceId, 'workspace-123');
    expect(decoded.limitsContent, '{"max_linear_speed":1.0}');
  });

  test(
    'RoboClawConfig System 1 router fields survive API JSON serialization',
    () {
      final config = RoboClawConfig(
        name: 'office-system1',
        robotName: 'butler',
        environment: 'office',
        system1Router: 'laya',
        system1Shadow: true,
        system1ShadowLog: '/tmp/system1.jsonl',
        system1Scope: 'navigation',
        system1Endpoint: 'http://laya:8000',
        system1Provider: 'laya',
        system1TimeoutMs: 450,
        system1ConfThresholdsJson: '{"smalltalk":0.95}',
        system1Skills: 'get_status,identify_location',
        system1MaxOptions: 8,
        system1ApiKey: 'system1-secret',
      );

      final json = config.toJson();
      expect(json['system1_router'], 'laya');
      expect(json['system1_shadow'], isTrue);
      expect(json['system1_shadow_log'], '/tmp/system1.jsonl');
      expect(json['system1_scope'], 'navigation');
      expect(json['system1_endpoint'], 'http://laya:8000');
      expect(json['system1_provider'], 'laya');
      expect(json['system1_timeout_ms'], 450);
      expect(json['system1_conf_thresholds_json'], '{"smalltalk":0.95}');
      expect(json['system1_skills'], 'get_status,identify_location');
      expect(json['system1_max_options'], 8);
      expect(json['system1_api_key'], 'system1-secret');

      final decoded = RoboClawConfig.fromJson(json);
      expect(decoded.system1Router, 'laya');
      expect(decoded.system1Shadow, isTrue);
      expect(decoded.system1ShadowLog, '/tmp/system1.jsonl');
      expect(decoded.system1Scope, 'navigation');
      expect(decoded.system1Endpoint, 'http://laya:8000');
      expect(decoded.system1Provider, 'laya');
      expect(decoded.system1TimeoutMs, 450);
      expect(decoded.system1ConfThresholdsJson, '{"smalltalk":0.95}');
      expect(decoded.system1Skills, 'get_status,identify_location');
      expect(decoded.system1MaxOptions, 8);
      expect(decoded.system1ApiKey, 'system1-secret');
    },
  );

  test('RoboClawConfig System 1 defaults match the runtime contract', () {
    final config = RoboClawConfig.fromJson({
      'name': 'default',
      'robot_name': 'butler',
      'environment': 'office',
    });

    expect(config.system1Router, 'rule');
    expect(config.system1Shadow, isFalse);
    expect(config.system1ShadowLog, '');
    expect(config.system1Scope, 'readonly');
    expect(config.system1Endpoint, '');
    expect(config.system1Provider, 'laya');
    expect(config.system1TimeoutMs, 300.0);
    expect(
      config.system1ConfThresholdsJson,
      RoboClawConfig.defaultSystem1ConfThresholdsJson,
    );
    expect(config.system1Skills, '');
    expect(config.system1MaxOptions, 12);
    expect(config.system1ApiKey, '');
  });

  test('RoboClawConfig 태스크 큐 / 복합 명령 분해 필드가 JSON 직렬화에서 보존된다', () {
    final config = RoboClawConfig(
      name: 'office-standard',
      robotName: 'butler',
      environment: 'office',
      taskQueueMaxSize: 4,
      llmFailFast: true,
      strictConfig: true,
      enableTaskDecomposition: false,
      taskDecompositionMaxSteps: 8,
      taskStepMaxRetries: 2,
      taskDecompositionWaitMarginCapSec: 900.0,
    );

    final decoded = RoboClawConfig.fromJson(config.toJson());

    expect(decoded.taskQueueMaxSize, 4);
    expect(decoded.llmFailFast, isTrue);
    expect(decoded.strictConfig, isTrue);
    expect(decoded.enableTaskDecomposition, isFalse);
    expect(decoded.taskDecompositionMaxSteps, 8);
    expect(decoded.taskStepMaxRetries, 2);
    expect(decoded.taskDecompositionWaitMarginCapSec, 900.0);
  });

  test('RoboClawConfig 태스크 큐 / 복합 명령 분해 필드 기본값이 모델 생성자와 일치한다', () {
    final decoded = RoboClawConfig.fromJson({
      'name': 'x',
      'robot_name': 'butler',
      'environment': 'office',
    });

    expect(decoded.taskQueueMaxSize, 8);
    expect(decoded.llmFailFast, isFalse);
    expect(decoded.strictConfig, isFalse);
    expect(decoded.enableTaskDecomposition, isTrue);
    expect(decoded.taskDecompositionMaxSteps, 6);
    expect(decoded.taskStepMaxRetries, 1);
    expect(decoded.taskDecompositionWaitMarginCapSec, 1800.0);
  });

  test('RoboClawConfig Dashboard 웹 노드 필드가 JSON 직렬화에서 보존된다', () {
    final config = RoboClawConfig(
      name: 'office-standard',
      robotName: 'butler',
      environment: 'office',
      dashboardHost: '0.0.0.0',
      dashboardPort: 9091,
    );

    final json = config.toJson();
    expect(json['dashboard_host'], '0.0.0.0');
    expect(json['dashboard_port'], 9091);

    final decoded = RoboClawConfig.fromJson(json);
    expect(decoded.dashboardHost, '0.0.0.0');
    expect(decoded.dashboardPort, 9091);
  });

  test('RoboClawConfig Dashboard 웹 노드 기본값이 계약 기본값과 일치한다', () {
    final decoded = RoboClawConfig.fromJson({
      'name': 'x',
      'robot_name': 'butler',
      'environment': 'office',
    });

    expect(decoded.dashboardHost, '127.0.0.1');
    expect(decoded.dashboardPort, 9090);
  });

  test('TestScenario JSON 직렬화 값을 보존한다', () {
    final scenario = TestScenario(
      id: 3,
      name: '기본 시나리오',
      robotName: 'former',
      environment: 'factory',
      isActive: true,
      testCases: [
        TestCase(
          id: 'tc_ping',
          name: 'Ping',
          step: 'Step 1',
          type: 'ping',
          timeoutMs: 3000,
          params: {'mode': 'fast'},
        ),
      ],
    );

    final decoded = TestScenario.fromJson(scenario.toJson());

    expect(decoded.id, 3);
    expect(decoded.name, '기본 시나리오');
    expect(decoded.robotName, 'former');
    expect(decoded.environment, 'factory');
    expect(decoded.isActive, isTrue);
    expect(decoded.testCases, hasLength(1));
    expect(decoded.testCases.first.id, 'tc_ping');
    expect(decoded.testCases.first.params['mode'], 'fast');
  });
}
