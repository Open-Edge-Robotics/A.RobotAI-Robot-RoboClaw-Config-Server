// frontend/lib/features/configs/config_form_mapper.dart
//
// 설정 모델 ↔ 폼 raw 입력(ConfigDraft) 순수 변환 로직.
// 특히 Ollama 옵션 JSON 의 생성/파싱을 담당한다.
// Flutter Widget 에 의존하지 않으므로 단위 테스트할 수 있다.

import 'dart:convert';

import '../../models/config_model.dart';
import 'config_draft.dart';
import 'config_form_values.dart';

// 기존 import 경로(`config_form_mapper.dart`)로 OllamaFormValues 를 계속
// 사용할 수 있도록 중립 값 타입을 다시 내보낸다.
export 'config_form_values.dart' show OllamaFormValues;

class ConfigFormMapper {
  /// 기존 `_populateForm`/`_saveConfig` 규칙: 이 두 필드만 저장 시 trim 한다.
  static const _trimmedTextKeys = {
    'agent_id',
    'cloid_cleanup_demo_motion_ids_json',
  };

  static final Map<String, dynamic> _modelDefaults = RoboClawConfig(
    name: '',
    robotName: '',
    environment: '',
  ).toJson();

  /// 모델 인스턴스를 폼 raw 입력 스냅샷으로 바꾼다.
  ///
  /// 값 나열 없이 [RoboClawConfig.toJson] 을 순회하므로 모델 필드가 추가되어도
  /// 폼 스냅샷에서 조용히 빠지지 않는다. System1 기본값 정규화는 기존
  /// `_populateForm` 동작을 그대로 옮긴 것이다.
  static ConfigDraft fromConfig(RoboClawConfig config) {
    final json = config.toJson();
    final texts = <String, String>{};
    final flags = <String, bool>{};

    for (final entry in json.entries) {
      final key = entry.key;
      if (ConfigDraft.reservedKeys.contains(key) ||
          key == ConfigDraft.ollamaOptionsKey) {
        continue;
      }
      final value = entry.value;
      if (value is bool) {
        flags[key] = value;
      } else {
        texts[key] = value.toString();
      }
    }

    texts['system1_router'] = config.system1Router.isEmpty
        ? 'rule'
        : config.system1Router;
    texts['system1_step_routing'] = config.system1StepRouting.isEmpty
        ? 'shadow'
        : config.system1StepRouting;
    texts['system1_scope'] = config.system1Scope.isEmpty
        ? 'readonly'
        : config.system1Scope;
    texts['system1_provider'] = config.system1Provider.isEmpty
        ? 'laya'
        : config.system1Provider;
    texts['system1_timeout_ms'] = config.system1TimeoutMs <= 0
        ? '300'
        : config.system1TimeoutMs.toString();
    texts['system1_conf_thresholds_json'] =
        config.system1ConfThresholdsJson.isEmpty
        ? RoboClawConfig.defaultSystem1ConfThresholdsJson
        : config.system1ConfThresholdsJson;
    texts['system1_max_options'] = config.system1MaxOptions < 2
        ? '12'
        : config.system1MaxOptions.toString();

    return ConfigDraft(
      texts: texts,
      flags: flags,
      options: parseOllamaOptions(config.ollamaOptionsJson),
    );
  }

  /// 폼 raw 입력 스냅샷을 저장 가능한 모델로 되돌린다.
  ///
  /// `id`/`isActive` 는 서버 상태이므로 폼 입력이 아니라 명시 인자로만 정한다.
  /// 숫자 텍스트 파싱 실패 fallback 은 모델 기본값을 사용한다(기존
  /// `_saveConfig` 의 `int.tryParse(...) ?? <기본값>` 과 동일).
  static RoboClawConfig toConfig(
    ConfigDraft draft, {
    required int? id,
    required bool isActive,
  }) {
    final json = <String, dynamic>{};
    final schema = ConfigDraft.schema;

    for (final entry in _modelDefaults.entries) {
      final key = entry.key;
      final defaultValue = entry.value;
      if (ConfigDraft.reservedKeys.contains(key)) continue;

      if (key == ConfigDraft.ollamaOptionsKey) {
        json[key] = jsonEncode(_buildOptions(draft.options));
        continue;
      }

      switch (schema[key]!) {
        case ConfigDraftFieldType.flag:
          json[key] = draft.flags[key] ?? defaultValue;
        case ConfigDraftFieldType.integer:
          final raw = draft.texts[key];
          json[key] = raw == null
              ? defaultValue
              : int.tryParse(raw) ?? defaultValue;
        case ConfigDraftFieldType.decimal:
          final raw = draft.texts[key];
          json[key] = raw == null
              ? defaultValue
              : double.tryParse(raw) ?? defaultValue;
        case ConfigDraftFieldType.text:
          final raw = draft.texts[key] ?? defaultValue as String;
          json[key] = _trimmedTextKeys.contains(key) ? raw.trim() : raw;
      }
    }

    json['is_active'] = isActive;
    if (id != null) json['ID'] = id;
    return RoboClawConfig.fromJson(json);
  }

  static Map<String, dynamic> _buildOptions(OllamaFormValues values) {
    return buildOllamaOptions(
      numCtx: values.numCtx,
      temperature: values.temperature,
      repeatPenalty: values.repeatPenalty,
      repeatLastN: values.repeatLastN,
      seed: values.seed,
      numPredict: values.numPredict,
      topK: values.topK,
      topP: values.topP,
      minP: values.minP,
      think: values.think,
      extraOptions: values.extraOptions,
    );
  }

  /// 폼 텍스트 값들로 Ollama options JSON 객체를 만든다.
  /// think 가 'unset' 이면 키를 출력하지 않아 모델 기본값을 존중한다.
  static Map<String, dynamic> buildOllamaOptions({
    required String numCtx,
    required String temperature,
    required String repeatPenalty,
    required String repeatLastN,
    required String seed,
    required String numPredict,
    required String topK,
    required String topP,
    required String minP,
    required String think,
    Map<String, dynamic> extraOptions = const {},
  }) {
    final options = <String, dynamic>{...extraOptions};
    options.addAll({
      'num_ctx': int.tryParse(numCtx) ?? 8192,
      'temperature': double.tryParse(temperature) ?? 0.7,
      'repeat_penalty': double.tryParse(repeatPenalty) ?? 1.1,
      'repeat_last_n': int.tryParse(repeatLastN) ?? 64,
      'seed': int.tryParse(seed) ?? 42,
      'num_predict': int.tryParse(numPredict) ?? -1,
      'top_k': int.tryParse(topK) ?? 40,
      'top_p': double.tryParse(topP) ?? 0.9,
      'min_p': double.tryParse(minP) ?? 0.0,
    });
    if (think != 'unset') {
      options['think'] = think == 'false'
          ? false
          : think == 'true'
          ? true
          : think;
    }
    return options;
  }

  /// Ollama options JSON 문자열을 폼 값으로 파싱한다.
  /// 잘못된 JSON 이거나 필드가 없으면 기본값을 사용한다.
  static OllamaFormValues parseOllamaOptions(String json) {
    Map<String, dynamic> map = {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) map = decoded;
    } catch (_) {
      // 잘못된 JSON → 기본값 사용
    }

    final thinkVal = map['think'];
    final think = thinkVal == false
        ? 'false'
        : thinkVal == true
        ? 'true'
        : (thinkVal is String &&
              ['low', 'medium', 'high', 'max'].contains(thinkVal))
        ? thinkVal
        : 'unset';

    final knownKeys = {
      'num_ctx',
      'temperature',
      'repeat_penalty',
      'repeat_last_n',
      'seed',
      'num_predict',
      'top_k',
      'top_p',
      'min_p',
      'think',
    };
    final extras = Map<String, dynamic>.fromEntries(
      map.entries.where((entry) => !knownKeys.contains(entry.key)),
    );

    return OllamaFormValues(
      numCtx: (map['num_ctx'] ?? 8192).toString(),
      temperature: (map['temperature'] ?? 0.7).toString(),
      repeatPenalty: (map['repeat_penalty'] ?? 1.1).toString(),
      repeatLastN: (map['repeat_last_n'] ?? 64).toString(),
      seed: (map['seed'] ?? 42).toString(),
      numPredict: (map['num_predict'] ?? -1).toString(),
      topK: (map['top_k'] ?? 40).toString(),
      topP: (map['top_p'] ?? 0.9).toString(),
      minP: (map['min_p'] ?? 0.0).toString(),
      think: think,
      extraOptions: extras,
    );
  }
}
