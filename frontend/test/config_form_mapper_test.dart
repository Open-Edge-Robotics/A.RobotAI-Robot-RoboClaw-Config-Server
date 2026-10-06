// frontend/test/config_form_mapper_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/configs/config_form_mapper.dart';

void main() {
  group('buildOllamaOptions', () {
    test('유효한 값으로 options 를 만든다', () {
      final options = ConfigFormMapper.buildOllamaOptions(
        numCtx: '4096',
        temperature: '0.3',
        repeatPenalty: '1.2',
        repeatLastN: '32',
        seed: '7',
        numPredict: '100',
        topK: '20',
        topP: '0.8',
        minP: '0.1',
        think: 'unset',
      );
      expect(options['num_ctx'], 4096);
      expect(options['temperature'], 0.3);
      expect(options['repeat_penalty'], 1.2);
      expect(options['repeat_last_n'], 32);
      expect(options['seed'], 7);
      expect(options['num_predict'], 100);
      expect(options['top_k'], 20);
      expect(options['top_p'], 0.8);
      expect(options['min_p'], 0.1);
      expect(options.containsKey('think'), isFalse);
    });

    test('숫자 파싱 실패 시 기본값을 사용한다', () {
      final options = ConfigFormMapper.buildOllamaOptions(
        numCtx: 'abc',
        temperature: 'xyz',
        repeatPenalty: '',
        repeatLastN: '',
        seed: '',
        numPredict: '',
        topK: '',
        topP: '',
        minP: '',
        think: 'unset',
      );
      expect(options['num_ctx'], 8192);
      expect(options['temperature'], 0.7);
      expect(options['repeat_penalty'], 1.1);
      expect(options['repeat_last_n'], 64);
      expect(options['seed'], 42);
      expect(options['num_predict'], -1);
      expect(options['top_k'], 40);
      expect(options['top_p'], 0.9);
      expect(options['min_p'], 0.0);
    });

    test('think false/true/low 를 올바르게 직렬화한다', () {
      final f = ConfigFormMapper.buildOllamaOptions(
        numCtx: '8192',
        temperature: '0.7',
        repeatPenalty: '1.1',
        repeatLastN: '64',
        seed: '42',
        numPredict: '-1',
        topK: '40',
        topP: '0.9',
        minP: '0.0',
        think: 'false',
      );
      expect(f['think'], isFalse);

      final t = ConfigFormMapper.buildOllamaOptions(
        numCtx: '8192',
        temperature: '0.7',
        repeatPenalty: '1.1',
        repeatLastN: '64',
        seed: '42',
        numPredict: '-1',
        topK: '40',
        topP: '0.9',
        minP: '0.0',
        think: 'true',
      );
      expect(t['think'], isTrue);

      final low = ConfigFormMapper.buildOllamaOptions(
        numCtx: '8192',
        temperature: '0.7',
        repeatPenalty: '1.1',
        repeatLastN: '64',
        seed: '42',
        numPredict: '-1',
        topK: '40',
        topP: '0.9',
        minP: '0.0',
        think: 'low',
      );
      expect(low['think'], 'low');
    });
  });

  group('parseOllamaOptions', () {
    test('유효한 JSON 을 폼 값으로 파싱한다', () {
      final v = ConfigFormMapper.parseOllamaOptions(
        '{"num_ctx":4096,"temperature":0.3,"think":true}',
      );
      expect(v.numCtx, '4096');
      expect(v.temperature, '0.3');
      expect(v.think, 'true');
    });

    test('필드가 없으면 기본값을 사용한다', () {
      final v = ConfigFormMapper.parseOllamaOptions('{}');
      expect(v.numCtx, '8192');
      expect(v.temperature, '0.7');
      expect(v.think, 'unset');
    });

    test('잘못된 JSON 은 기본값을 사용한다', () {
      final v = ConfigFormMapper.parseOllamaOptions('{bad');
      expect(v.numCtx, '8192');
      expect(v.think, 'unset');
    });

    test('think 문자열(low~max)을 보존한다', () {
      final v = ConfigFormMapper.parseOllamaOptions('{"think":"high"}');
      expect(v.think, 'high');
    });

    test('UI가 모르는 Ollama 옵션을 round-trip 보존한다', () {
      final v = ConfigFormMapper.parseOllamaOptions(
        '{"num_ctx":4096,"stop":["User:"],"draft_num_predict":4}',
      );
      final options = ConfigFormMapper.buildOllamaOptions(
        numCtx: v.numCtx,
        temperature: v.temperature,
        repeatPenalty: v.repeatPenalty,
        repeatLastN: v.repeatLastN,
        seed: v.seed,
        numPredict: v.numPredict,
        topK: v.topK,
        topP: v.topP,
        minP: v.minP,
        think: v.think,
        extraOptions: v.extraOptions,
      );

      expect(options['stop'], ['User:']);
      expect(options['draft_num_predict'], 4);
    });
  });
}
