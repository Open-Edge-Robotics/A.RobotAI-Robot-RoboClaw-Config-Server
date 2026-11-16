// frontend/test/config_draft_test.dart
//
// ConfigDraft / ConfigFormMapper 의 순수(pure) 매핑 회귀 테스트.
// 기존 ConfigTab._populateForm 의 정규화와 _saveConfig 의 fallback 을 고정한다.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/configs/config_draft.dart';
import 'package:frontend/features/configs/config_form_mapper.dart';
import 'package:frontend/models/config_model.dart';

RoboClawConfig _defaultConfig() =>
    RoboClawConfig(name: '', robotName: '', environment: '');

ConfigDraft _defaultDraft() => ConfigFormMapper.fromConfig(_defaultConfig());

/// 기존 `_saveConfig` 의 숫자 파싱 실패 fallback 표.
///
/// 모델 생성자 기본값과 반드시 일치해야 하며, 아래 테스트가 그 일치를 검증한다.
const _numericFallbacks = <String, num>{
  'ros_domain_id': 0,
  'grpc_port': 50052,
  'grpc_target_port': 50051,
  'http_port': 8080,
  'http_rate_limit_per_minute': 60,
  'dashboard_port': 9090,
  'rag_top_k': 2,
  'skill_learning_reflect_interval_sec': 1800,
  'task_queue_max_size': 8,
  'task_decomposition_max_steps': 6,
  'task_step_max_retries': 1,
  'system1_max_options': 12,
  'robot_port': 50053,
  'rag_score_threshold': 0.7,
  'qdrant_timeout_sec': 5.0,
  'gripper_vision_max_inference_hz': 5.0,
  'skill_learning_success_sample_rate': 0.1,
  'task_decomposition_wait_margin_cap_sec': 1800.0,
  'system1_timeout_ms': 300.0,
  'fleet_heartbeat_sec': 1.0,
};

/// 모든 모델 필드에 서로 다른 sentinel 값을 채운 JSON.
Map<String, dynamic> _sentinelJson() {
  final defaults = _defaultConfig().toJson();
  final json = <String, dynamic>{};
  for (final entry in defaults.entries) {
    if (entry.key == 'is_active' || entry.key == 'ollama_options_json') {
      continue;
    }
    json[entry.key] = switch (entry.value) {
      bool value => !value,
      int _ => 7,
      double _ => 0.25,
      String _ => 'sentinel_${entry.key}',
      final other => other,
    };
  }
  json['ID'] = 77;
  json['is_active'] = true;
  json['ollama_options_json'] =
      '{"num_ctx":2048,"temperature":0.2,"repeat_penalty":1.05,'
      '"repeat_last_n":32,"seed":7,"num_predict":256,"top_k":20,'
      '"top_p":0.85,"min_p":0.05,"think":"low","stop":["User:"],'
      '"draft_num_predict":4,"nested":{"levels":[1,2]}}';
  return json;
}

Set<String> _schemaKeysOf(ConfigDraftFieldType type) => ConfigDraft
    .schema
    .entries
    .where((entry) => entry.value == type)
    .map((entry) => entry.key)
    .toSet();

void main() {
  group('ConfigDraft schema', () {
    test('모든 모델 JSON 스칼라는 text/flag 로 분류되고 ID/is_active 는 제외된다', () {
      final modelKeys = _defaultConfig().toJson().keys.toSet();
      final covered = {...ConfigDraft.textKeys, ...ConfigDraft.flagKeys};

      expect(modelKeys.difference(covered), {
        'is_active',
        'ollama_options_json',
      });
      expect(covered.contains('ID'), isFalse);
      expect(covered.contains('is_active'), isFalse);
      expect(covered.contains('ollama_options_json'), isFalse);
    });

    test('flag 키는 모델의 bool 필드와 정확히 일치한다', () {
      final expected = _defaultConfig()
          .toJson()
          .entries
          .where((entry) => entry.value is bool && entry.key != 'is_active')
          .map((entry) => entry.key)
          .toSet();

      expect(ConfigDraft.flagKeys, expected);
      expect(_schemaKeysOf(ConfigDraftFieldType.flag), expected);
    });

    test('text 키는 문자열/숫자 필드와 정확히 일치한다', () {
      final expected = _defaultConfig()
          .toJson()
          .entries
          .where(
            (entry) =>
                entry.key != 'ollama_options_json' &&
                entry.key != 'is_active' &&
                entry.value is! bool,
          )
          .map((entry) => entry.key)
          .toSet();

      expect(ConfigDraft.textKeys, expected);
    });

    test('모델 스키마의 실제 키(skills_guide_file)를 사용한다', () {
      expect(ConfigDraft.textKeys, contains('skills_guide_file'));
      expect(ConfigDraft.textKeys, isNot(contains('fleet_skills_guide_file')));
    });

    test('숫자 필드 fallback 표가 모든 숫자 키를 덮는다', () {
      final numericKeys = {
        ..._schemaKeysOf(ConfigDraftFieldType.integer),
        ..._schemaKeysOf(ConfigDraftFieldType.decimal),
      };

      expect(numericKeys, _numericFallbacks.keys.toSet());
    });
  });

  group('ConfigDraft 불변성/검증', () {
    test('raw map 은 unmodifiable 이고 입력 map 변경에 영향받지 않는다', () {
      final base = _defaultDraft();
      final texts = Map<String, String>.from(base.texts);
      final flags = Map<String, bool>.from(base.flags);
      final draft = ConfigDraft(
        texts: texts,
        flags: flags,
        options: base.options,
      );

      texts['name'] = 'changed';
      flags['debug'] = !flags['debug']!;

      expect(draft.texts['name'], '');
      expect(draft.flags['debug'], isTrue);
      expect(() => draft.texts['name'] = 'x', throwsUnsupportedError);
      expect(() => draft.flags['debug'] = false, throwsUnsupportedError);
    });

    test('copyWith 는 원본을 바꾸지 않는다', () {
      final draft = _defaultDraft();
      final copy = draft.copyWith(texts: {'name': 'copied'});

      expect(draft.texts['name'], '');
      expect(copy.texts['name'], 'copied');
    });

    test('알 수 없는 키와 타입 경계 위반을 거부한다', () {
      final draft = _defaultDraft();

      expect(() => draft.copyWith(texts: {'nmae': 'x'}), throwsArgumentError);
      expect(
        () => draft.copyWith(flags: {'debugg': true}),
        throwsArgumentError,
      );
      expect(
        () => draft.copyWith(texts: {'debug': 'true'}),
        throwsArgumentError,
      );
      expect(() => draft.copyWith(flags: {'name': true}), throwsArgumentError);
    });

    test('누락된 known 키를 거부한다', () {
      final draft = _defaultDraft();
      final missingText = Map<String, String>.from(draft.texts)..remove('name');
      final missingFlag = Map<String, bool>.from(draft.flags)..remove('debug');

      expect(
        () => ConfigDraft(
          texts: missingText,
          flags: draft.flags,
          options: draft.options,
        ),
        throwsArgumentError,
      );
      expect(
        () => ConfigDraft(
          texts: draft.texts,
          flags: missingFlag,
          options: draft.options,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ConfigFormMapper.fromConfig 정규화', () {
    test('System1 기본값 정규화는 기존 _populateForm 과 동일하다', () {
      final config = RoboClawConfig(
        name: 'a',
        robotName: 'b',
        environment: 'c',
        system1Router: '',
        system1StepRouting: '',
        system1Scope: '',
        system1Provider: '',
        system1TimeoutMs: 0,
        system1ConfThresholdsJson: '',
        system1MaxOptions: 0,
      );

      final draft = ConfigFormMapper.fromConfig(config);

      expect(draft.texts['system1_router'], 'rule');
      expect(draft.texts['system1_step_routing'], 'shadow');
      expect(draft.texts['system1_scope'], 'readonly');
      expect(draft.texts['system1_provider'], 'laya');
      expect(draft.texts['system1_timeout_ms'], '300');
      expect(
        draft.texts['system1_conf_thresholds_json'],
        RoboClawConfig.defaultSystem1ConfThresholdsJson,
      );
      expect(draft.texts['system1_max_options'], '12');
    });

    test('System1 유효값은 그대로 보존한다', () {
      final config = RoboClawConfig(
        name: 'a',
        robotName: 'b',
        environment: 'c',
        system1Router: 'laya',
        system1StepRouting: 'on',
        system1Scope: 'navigation',
        system1Provider: 'custom-provider',
        system1TimeoutMs: 120.5,
        system1ConfThresholdsJson: '{"skill":0.7}',
        system1MaxOptions: 3,
      );

      final draft = ConfigFormMapper.fromConfig(config);

      expect(draft.texts['system1_router'], 'laya');
      expect(draft.texts['system1_step_routing'], 'on');
      expect(draft.texts['system1_scope'], 'navigation');
      expect(draft.texts['system1_provider'], 'custom-provider');
      expect(draft.texts['system1_timeout_ms'], '120.5');
      expect(draft.texts['system1_conf_thresholds_json'], '{"skill":0.7}');
      expect(draft.texts['system1_max_options'], '3');
    });

    test('숫자 필드는 모델 toString 과 동일한 raw text 가 된다', () {
      final config = RoboClawConfig(
        name: 'a',
        robotName: 'b',
        environment: 'c',
        rosDomainId: 5,
        ragScoreThreshold: 0.25,
        grpcPort: 6000,
      );

      final draft = ConfigFormMapper.fromConfig(config);

      expect(draft.texts['ros_domain_id'], '5');
      expect(draft.texts['rag_score_threshold'], '0.25');
      expect(draft.texts['qdrant_timeout_sec'], '5.0');
      expect(draft.texts['grpc_port'], '6000');
    });

    test('agent_id 와 cloid motion json 만 저장 시 trim 한다', () {
      final config = RoboClawConfig(
        name: ' name ',
        robotName: ' robot ',
        environment: 'env',
        agentId: '  agent  ',
        cloidCleanupDemoMotionIdsJson: '  ["m1"]  ',
      );

      final draft = ConfigFormMapper.fromConfig(config);
      expect(draft.texts['agent_id'], '  agent  ');
      expect(draft.texts['name'], ' name ');

      final saved = ConfigFormMapper.toConfig(draft, id: null, isActive: false);

      expect(saved.agentId, 'agent');
      expect(saved.cloidCleanupDemoMotionIdsJson, '["m1"]');
      expect(saved.name, ' name ');
      expect(saved.robotName, ' robot ');
    });
  });

  group('ConfigFormMapper.toConfig', () {
    test('모든 모델 필드 sentinel roundtrip 이 보존된다', () {
      final original = RoboClawConfig.fromJson(_sentinelJson());
      final draft = ConfigFormMapper.fromConfig(original);
      final roundtrip = ConfigFormMapper.toConfig(
        draft,
        id: original.id,
        isActive: original.isActive,
      );

      final expected = original.toJson();
      final actual = roundtrip.toJson();
      expect(actual.keys.toSet(), expected.keys.toSet());
      for (final key in expected.keys) {
        if (key == 'ollama_options_json') continue;
        expect(actual[key], expected[key], reason: key);
      }
    });

    test('알 수 없는 Ollama extra/nested 데이터와 think 를 보존한다', () {
      const rawOptions =
          '{"num_ctx":2048,"temperature":0.2,"repeat_penalty":1.05,'
          '"repeat_last_n":32,"seed":7,"num_predict":256,"top_k":20,'
          '"top_p":0.85,"min_p":0.05,"think":"low","stop":["User:"],'
          '"draft_num_predict":4,"nested":{"levels":[1,2]}}';
      final original = RoboClawConfig(
        name: 'a',
        robotName: 'b',
        environment: 'c',
        ollamaOptionsJson: rawOptions,
      );

      final roundtrip = ConfigFormMapper.toConfig(
        ConfigFormMapper.fromConfig(original),
        id: null,
        isActive: false,
      );

      expect(jsonDecode(roundtrip.ollamaOptionsJson), jsonDecode(rawOptions));
    });

    test('think unset 은 키를 출력하지 않는다', () {
      final original = RoboClawConfig(
        name: 'a',
        robotName: 'b',
        environment: 'c',
        ollamaOptionsJson: '{"num_ctx":2048,"think":false}',
      );
      final draft = ConfigFormMapper.fromConfig(original);
      final copied = draft.copyWith(
        options: ConfigFormMapper.parseOllamaOptions('{"num_ctx":2048}'),
      );

      final saved = ConfigFormMapper.toConfig(
        copied,
        id: null,
        isActive: false,
      );
      final decoded =
          jsonDecode(saved.ollamaOptionsJson) as Map<String, dynamic>;

      expect(decoded['num_ctx'], 2048);
      expect(decoded.containsKey('think'), isFalse);
    });

    test('모든 숫자 필드의 잘못된 텍스트는 기존 fallback 기본값을 쓴다', () {
      final base = _defaultDraft();

      for (final entry in _numericFallbacks.entries) {
        for (final raw in ['', 'not-a-number', '1.2.3']) {
          final draft = base.copyWith(texts: {entry.key: raw});
          final saved = ConfigFormMapper.toConfig(
            draft,
            id: null,
            isActive: false,
          );
          expect(
            saved.toJson()[entry.key],
            entry.value,
            reason: '${entry.key} = "$raw"',
          );
        }
      }
    });

    test('저장 시에는 populate 정규화를 다시 적용하지 않는다', () {
      final base = _defaultDraft();
      final saved = ConfigFormMapper.toConfig(
        base.copyWith(
          texts: {
            'system1_max_options': '0',
            'system1_timeout_ms': '-5',
            'system1_router': '',
          },
        ),
        id: null,
        isActive: false,
      );

      expect(saved.system1MaxOptions, 0);
      expect(saved.system1TimeoutMs, -5.0);
      expect(saved.system1Router, '');
    });

    test('false/0/빈 문자열/masking placeholder 를 보존한다', () {
      final original = RoboClawConfig(
        name: 'a',
        robotName: 'b',
        environment: 'c',
        httpControlToken: '********',
        httpReadonlyToken: '',
        rosDomainId: 0,
        enableGrpc: false,
      );

      final draft = ConfigFormMapper.fromConfig(original);
      expect(draft.texts['http_control_token'], '********');

      final saved = ConfigFormMapper.toConfig(draft, id: 3, isActive: false);

      expect(saved.id, 3);
      expect(saved.isActive, isFalse);
      expect(saved.httpControlToken, '********');
      expect(saved.httpReadonlyToken, '');
      expect(saved.rosDomainId, 0);
      expect(saved.enableGrpc, isFalse);
    });

    test('ID/is_active 는 명시 인자로만 정해진다', () {
      final base = _defaultDraft();

      final created = ConfigFormMapper.toConfig(
        base,
        id: null,
        isActive: false,
      );
      expect(created.id, isNull);
      expect(created.isActive, isFalse);

      final updated = ConfigFormMapper.toConfig(base, id: 42, isActive: true);
      expect(updated.id, 42);
      expect(updated.isActive, isTrue);
    });

    test('ollama_options_json 은 빈 extra 로 시작해도 known 기본값을 갖는다', () {
      final base = _defaultDraft();
      final saved = ConfigFormMapper.toConfig(base, id: null, isActive: false);
      final decoded =
          jsonDecode(saved.ollamaOptionsJson) as Map<String, dynamic>;

      expect(decoded['num_ctx'], 8192);
      expect(decoded['temperature'], 0.7);
      expect(decoded['min_p'], 0.0);
      expect(decoded.containsKey('think'), isFalse);
    });
  });

  group('OllamaFormValues re-export', () {
    test('기존 타입 이름을 config_form_values 와 mapper 양쪽에서 쓸 수 있다', () {
      final values = OllamaFormValues(
        numCtx: '1',
        temperature: '2',
        repeatPenalty: '3',
        repeatLastN: '4',
        seed: '5',
        numPredict: '6',
        topK: '7',
        topP: '8',
        minP: '9',
        think: 'unset',
      );

      expect(values.numCtx, '1');
      expect(ConfigFormMapper.parseOllamaOptions('{}').numCtx, '8192');
    });
  });
}
