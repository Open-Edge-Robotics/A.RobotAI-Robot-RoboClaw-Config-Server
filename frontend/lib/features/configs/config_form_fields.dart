// frontend/lib/features/configs/config_form_fields.dart
//
// 설정 폼의 UI 어댑터. TextEditingController 자원만 소유하고, 모델 규칙은
// ConfigFormMapper/ConfigDraft(순수 로직)에 둔다.
//
// known key 접근자(text/flag/choice/ollamaText)로만 값을 다루므로 오타는
// 조용한 기본값이 아니라 ArgumentError 로 드러난다.

import 'package:flutter/widgets.dart';

import '../../models/config_model.dart';
import 'config_draft.dart';
import 'config_form_mapper.dart';

class ConfigFormFields {
  /// 모델에서 TextEditingController 가 아니라 드롭다운 값으로 다루는 키.
  static const choiceKeys = {
    'llm_provider',
    'system1_router',
    'system1_step_routing',
    'system1_scope',
    'maestro_disconnect_policy',
  };

  /// Ollama options JSON 의 개별 숫자 옵션 키.
  static const ollamaTextKeys = {
    'num_ctx',
    'temperature',
    'repeat_penalty',
    'repeat_last_n',
    'seed',
    'num_predict',
    'top_k',
    'top_p',
    'min_p',
  };

  static const _ollamaThinkValues = {
    'unset',
    'false',
    'true',
    'low',
    'medium',
    'high',
    'max',
  };

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, TextEditingController> _ollamaControllers = {};
  final Map<String, bool> _flags = {};
  final Map<String, String> _choices = {};
  String _ollamaThink = 'unset';
  Map<String, dynamic> _ollamaExtraOptions = const {};

  /// 모델 생성자 기본값으로 시작한다. 필드 기본값의 단일 소스는 모델이다.
  ConfigFormFields() {
    load(
      ConfigFormMapper.fromConfig(
        RoboClawConfig(name: '', robotName: '', environment: ''),
      ),
    );
  }

  /// 모델 JSON 키에 대응하는 raw text 컨트롤러.
  TextEditingController text(String apiKey) {
    if (choiceKeys.contains(apiKey)) {
      throw ArgumentError.value(apiKey, 'apiKey', 'choice 접근자를 사용해야 합니다');
    }
    if (!ConfigDraft.textKeys.contains(apiKey)) {
      throw ArgumentError.value(apiKey, 'apiKey', '알 수 없는 설정 텍스트 키');
    }
    return _textControllers.putIfAbsent(apiKey, TextEditingController.new);
  }

  bool flag(String apiKey) {
    _assertFlagKey(apiKey);
    return _flags[apiKey]!;
  }

  void setFlag(String apiKey, bool value) {
    _assertFlagKey(apiKey);
    _flags[apiKey] = value;
  }

  String choice(String apiKey) {
    _assertChoiceKey(apiKey);
    return _choices[apiKey]!;
  }

  void setChoice(String apiKey, String value) {
    _assertChoiceKey(apiKey);
    _choices[apiKey] = value;
  }

  /// Ollama 옵션 JSON 의 개별 숫자 옵션 컨트롤러.
  TextEditingController ollamaText(String optionKey) {
    if (!ollamaTextKeys.contains(optionKey)) {
      throw ArgumentError.value(optionKey, 'optionKey', '알 수 없는 Ollama 옵션 키');
    }
    return _ollamaControllers.putIfAbsent(optionKey, TextEditingController.new);
  }

  String get ollamaThink => _ollamaThink;

  void setOllamaThink(String value) {
    if (!_ollamaThinkValues.contains(value)) {
      throw ArgumentError.value(value, 'value', '알 수 없는 Ollama think 값');
    }
    _ollamaThink = value;
  }

  /// 폼 raw 입력 스냅샷을 현재 컨트롤러 상태로 채운다.
  void load(ConfigDraft draft) {
    for (final key in ConfigDraft.textKeys) {
      final value = draft.texts[key]!;
      if (choiceKeys.contains(key)) {
        _choices[key] = value;
      } else {
        text(key).text = value;
      }
    }
    for (final key in ConfigDraft.flagKeys) {
      _flags[key] = draft.flags[key]!;
    }
    _loadOllama(draft.options);
  }

  /// 현재 컨트롤러 상태를 순수 스냅샷으로 모은다.
  ConfigDraft snapshot() {
    final texts = <String, String>{};
    for (final key in ConfigDraft.textKeys) {
      texts[key] = choiceKeys.contains(key) ? _choices[key]! : text(key).text;
    }
    final flags = <String, bool>{
      for (final key in ConfigDraft.flagKeys) key: _flags[key]!,
    };
    return ConfigDraft(
      texts: texts,
      flags: flags,
      options: OllamaFormValues(
        numCtx: ollamaText('num_ctx').text,
        temperature: ollamaText('temperature').text,
        repeatPenalty: ollamaText('repeat_penalty').text,
        repeatLastN: ollamaText('repeat_last_n').text,
        seed: ollamaText('seed').text,
        numPredict: ollamaText('num_predict').text,
        topK: ollamaText('top_k').text,
        topP: ollamaText('top_p').text,
        minP: ollamaText('min_p').text,
        think: _ollamaThink,
        extraOptions: _ollamaExtraOptions,
      ),
    );
  }

  /// Ollama 템플릿 적용: known 옵션과 think 만 되돌리고 알 수 없는 extra 는
  /// 사용자가 넣은 값을 그대로 둔다(기존 템플릿 동작).
  void applyOllamaTemplate() {
    ollamaText('num_ctx').text = '8192';
    ollamaText('temperature').text = '0.7';
    ollamaText('repeat_penalty').text = '1.1';
    ollamaText('repeat_last_n').text = '64';
    ollamaText('seed').text = '42';
    ollamaText('num_predict').text = '-1';
    ollamaText('top_k').text = '40';
    ollamaText('top_p').text = '0.9';
    ollamaText('min_p').text = '0.0';
    _ollamaThink = 'unset';
  }

  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
    for (final controller in _ollamaControllers.values) {
      controller.dispose();
    }
    _ollamaControllers.clear();
  }

  void _loadOllama(OllamaFormValues values) {
    ollamaText('num_ctx').text = values.numCtx;
    ollamaText('temperature').text = values.temperature;
    ollamaText('repeat_penalty').text = values.repeatPenalty;
    ollamaText('repeat_last_n').text = values.repeatLastN;
    ollamaText('seed').text = values.seed;
    ollamaText('num_predict').text = values.numPredict;
    ollamaText('top_k').text = values.topK;
    ollamaText('top_p').text = values.topP;
    ollamaText('min_p').text = values.minP;
    _ollamaThink = values.think;
    _ollamaExtraOptions = values.extraOptions;
  }

  void _assertFlagKey(String apiKey) {
    if (!ConfigDraft.flagKeys.contains(apiKey)) {
      throw ArgumentError.value(apiKey, 'apiKey', '알 수 없는 설정 bool 키');
    }
  }

  void _assertChoiceKey(String apiKey) {
    if (!choiceKeys.contains(apiKey)) {
      throw ArgumentError.value(apiKey, 'apiKey', '알 수 없는 설정 choice 키');
    }
  }
}
