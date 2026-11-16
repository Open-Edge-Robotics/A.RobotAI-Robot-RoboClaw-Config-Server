// frontend/test/config_form_fields_test.dart
//
// ConfigFormFields 는 TextEditingController 자원만 소유하는 UI 어댑터다.
// 모든 known key 매핑, snapshot/load round-trip, dispose, Ollama 템플릿 규칙을 검증한다.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/configs/config_draft.dart';
import 'package:frontend/features/configs/config_form_fields.dart';
import 'package:frontend/features/configs/config_form_mapper.dart';
import 'package:frontend/models/config_model.dart';

RoboClawConfig _defaultConfig() =>
    RoboClawConfig(name: '', robotName: '', environment: '');

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
  json['ID'] = 11;
  json['is_active'] = true;
  return json;
}

void main() {
  group('key → model 매핑', () {
    test('모든 text 키가 모델 필드로 매핑된다', () {
      final fields = ConfigFormFields();
      addTearDown(fields.dispose);

      for (final key in ConfigDraft.textKeys) {
        final type = ConfigDraft.schema[key]!;
        final raw = switch (type) {
          ConfigDraftFieldType.integer => '17',
          ConfigDraftFieldType.decimal => '0.25',
          ConfigDraftFieldType.text => 'value_$key',
          ConfigDraftFieldType.flag => throw StateError('flag: $key'),
        };
        if (ConfigFormFields.choiceKeys.contains(key)) {
          fields.setChoice(key, raw);
        } else {
          fields.text(key).text = raw;
        }
      }

      final saved = ConfigFormMapper.toConfig(
        fields.snapshot(),
        id: null,
        isActive: false,
      );
      final json = saved.toJson();

      for (final key in ConfigDraft.textKeys) {
        final expected = switch (ConfigDraft.schema[key]!) {
          ConfigDraftFieldType.integer => 17,
          ConfigDraftFieldType.decimal => 0.25,
          ConfigDraftFieldType.text => 'value_$key',
          ConfigDraftFieldType.flag => throw StateError('flag: $key'),
        };
        expect(json[key], expected, reason: key);
      }
    });

    test('모든 flag 키가 모델 bool 필드로 매핑된다', () {
      final fields = ConfigFormFields();
      addTearDown(fields.dispose);
      final defaults = ConfigFormMapper.fromConfig(_defaultConfig()).flags;

      for (final key in ConfigDraft.flagKeys) {
        fields.setFlag(key, !defaults[key]!);
      }

      final saved = ConfigFormMapper.toConfig(
        fields.snapshot(),
        id: null,
        isActive: false,
      );
      final json = saved.toJson();

      for (final key in ConfigDraft.flagKeys) {
        expect(json[key], !defaults[key]!, reason: key);
      }
    });
  });

  group('load / snapshot', () {
    test('한 필드만 수정해도 렌더링되지 않는 다른 필드는 보존된다', () {
      final original = RoboClawConfig.fromJson(_sentinelJson());
      final fields = ConfigFormFields();
      addTearDown(fields.dispose);

      fields.load(ConfigFormMapper.fromConfig(original));
      fields.text('http_control_token').text = 'edited-token';

      final saved = ConfigFormMapper.toConfig(
        fields.snapshot(),
        id: original.id,
        isActive: original.isActive,
      );
      expect(saved.httpControlToken, 'edited-token');

      final expected = original.toJson();
      final actual = saved.toJson();
      for (final key in expected.keys) {
        if (key == 'http_control_token' || key == 'ollama_options_json') {
          continue;
        }
        expect(actual[key], expected[key], reason: key);
      }
    });

    test('choice 키는 텍스트 컨트롤러가 아니라 choice 접근자로 유지된다', () {
      final fields = ConfigFormFields();
      addTearDown(fields.dispose);

      fields.setChoice('llm_provider', 'ollama');
      final snapshot = fields.snapshot();

      expect(snapshot.texts['llm_provider'], 'ollama');
      expect(fields.choice('llm_provider'), 'ollama');
    });

    test('알 수 없는/잘못된 접근자 키를 거부한다', () {
      final fields = ConfigFormFields();
      addTearDown(fields.dispose);

      expect(() => fields.text('nmae'), throwsArgumentError);
      expect(() => fields.text('llm_provider'), throwsArgumentError);
      expect(() => fields.text('debug'), throwsArgumentError);
      expect(() => fields.flag('name'), throwsArgumentError);
      expect(() => fields.choice('name'), throwsArgumentError);
      expect(() => fields.ollamaText('num_ctx2'), throwsArgumentError);
      expect(() => fields.setOllamaThink('sometimes'), throwsArgumentError);
    });
  });

  group('Ollama 옵션', () {
    test('템플릿 적용은 known 옵션/think 만 초기화하고 extra 는 보존한다', () {
      final original = RoboClawConfig(
        name: 'a',
        robotName: 'b',
        environment: 'c',
        ollamaOptionsJson:
            '{"num_ctx":1024,"temperature":0.1,"think":"high",'
            '"stop":["User:"],"draft_num_predict":4}',
      );
      final fields = ConfigFormFields();
      addTearDown(fields.dispose);

      fields.load(ConfigFormMapper.fromConfig(original));
      fields.applyOllamaTemplate();
      final snapshot = fields.snapshot();

      expect(snapshot.options.numCtx, '8192');
      expect(snapshot.options.temperature, '0.7');
      expect(snapshot.options.repeatPenalty, '1.1');
      expect(snapshot.options.seed, '42');
      expect(snapshot.options.think, 'unset');
      expect(snapshot.options.extraOptions, {
        'stop': ['User:'],
        'draft_num_predict': 4,
      });

      final saved = ConfigFormMapper.toConfig(
        snapshot,
        id: null,
        isActive: false,
      );
      final decoded =
          jsonDecode(saved.ollamaOptionsJson) as Map<String, dynamic>;
      expect(decoded['num_ctx'], 8192);
      expect(decoded['stop'], ['User:']);
      expect(decoded['draft_num_predict'], 4);
      expect(decoded.containsKey('think'), isFalse);
    });

    test('빈/잘못된 options 를 로드하면 이전 extra 까지 기본값으로 초기화된다', () {
      final fields = ConfigFormFields();
      addTearDown(fields.dispose);

      fields.load(
        ConfigFormMapper.fromConfig(
          RoboClawConfig(
            name: 'a',
            robotName: 'b',
            environment: 'c',
            ollamaOptionsJson:
                '{"num_ctx":1024,"stop":["User:"],"draft_num_predict":4}',
          ),
        ),
      );

      for (final raw in ['', '{bad']) {
        fields.load(
          ConfigFormMapper.fromConfig(
            RoboClawConfig(
              name: '',
              robotName: '',
              environment: '',
              ollamaOptionsJson: raw,
            ),
          ),
        );
        final snapshot = fields.snapshot();
        expect(snapshot.options.numCtx, '8192', reason: '"$raw"');
        expect(snapshot.options.temperature, '0.7', reason: '"$raw"');
        expect(snapshot.options.think, 'unset', reason: '"$raw"');
        expect(snapshot.options.extraOptions, isEmpty, reason: '"$raw"');
      }
    });

    test('dispose 는 소유한 TextEditingController 를 모두 정리한다', () {
      final fields = ConfigFormFields();
      final textController = fields.text('name');
      final ollamaController = fields.ollamaText('num_ctx');

      fields.dispose();

      expect(() => textController.addListener(() {}), throwsStateError);
      expect(() => ollamaController.addListener(() {}), throwsStateError);
    });
  });
}
