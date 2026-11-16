// frontend/lib/features/configs/config_draft.dart
//
// 설정 폼의 raw 입력 스냅샷. Flutter Widget/Controller 에 의존하지 않는
// 순수 값 타입이며, API JSON 키 ↔ raw text/bool 매핑만 담는다.
//
// 스키마의 단일 소스는 RoboClawConfig 의 기본 직렬화 결과다. 필드 타입을
// 여기에 중복 나열하지 않으므로 모델에 필드가 추가되면 자동으로 포함된다.

import '../../models/config_model.dart';
import 'config_form_values.dart';

enum ConfigDraftFieldType { text, integer, decimal, flag }

class ConfigDraft {
  /// 서버가 소유하는 값이라 폼 raw 입력에서 제외한다.
  static const reservedKeys = {'ID', 'is_active'};

  /// Ollama 옵션은 개별 raw text 대신 [options] 로 다룬다.
  static const ollamaOptionsKey = 'ollama_options_json';

  static final Map<String, ConfigDraftFieldType> _schema = _buildSchema();

  static final Set<String> _textKeys = Set.unmodifiable(
    _schema.entries
        .where((entry) => entry.value != ConfigDraftFieldType.flag)
        .map((entry) => entry.key),
  );

  static final Set<String> _flagKeys = Set.unmodifiable(
    _schema.entries
        .where((entry) => entry.value == ConfigDraftFieldType.flag)
        .map((entry) => entry.key),
  );

  /// API JSON 키별 입력 타입.
  static Map<String, ConfigDraftFieldType> get schema =>
      Map.unmodifiable(_schema);

  /// raw text(문자열/숫자) 로 편집하는 키.
  static Set<String> get textKeys => _textKeys;

  /// bool 로 편집하는 키.
  static Set<String> get flagKeys => _flagKeys;

  final Map<String, String> texts;
  final Map<String, bool> flags;
  final OllamaFormValues options;

  ConfigDraft({
    required Map<String, String> texts,
    required Map<String, bool> flags,
    required this.options,
  }) : texts = Map.unmodifiable(texts),
       flags = Map.unmodifiable(flags) {
    _validateKeys(texts, flags);
  }

  ConfigDraft copyWith({
    Map<String, String>? texts,
    Map<String, bool>? flags,
    OllamaFormValues? options,
  }) {
    return ConfigDraft(
      texts: {...this.texts, ...?texts},
      flags: {...this.flags, ...?flags},
      options: options ?? this.options,
    );
  }

  static Map<String, ConfigDraftFieldType> _buildSchema() {
    final defaults = RoboClawConfig(
      name: '',
      robotName: '',
      environment: '',
    ).toJson();
    final schema = <String, ConfigDraftFieldType>{};

    for (final entry in defaults.entries) {
      if (reservedKeys.contains(entry.key) || entry.key == ollamaOptionsKey) {
        continue;
      }
      schema[entry.key] = switch (entry.value) {
        bool _ => ConfigDraftFieldType.flag,
        int _ => ConfigDraftFieldType.integer,
        double _ => ConfigDraftFieldType.decimal,
        String _ => ConfigDraftFieldType.text,
        final value => throw StateError(
          '설정 모델 JSON 이 스칼라가 아닙니다: ${entry.key} ($value)',
        ),
      };
    }
    return schema;
  }

  /// 키 오타/타입 혼동/누락이 조용한 기본값으로 이어지지 않도록 검증한다.
  static void _validateKeys(
    Map<String, String> texts,
    Map<String, bool> flags,
  ) {
    final invalid = <String>[];
    for (final key in texts.keys) {
      final type = _schema[key];
      if (type == null || type == ConfigDraftFieldType.flag) invalid.add(key);
    }
    for (final key in flags.keys) {
      if (_schema[key] != ConfigDraftFieldType.flag) invalid.add(key);
    }
    if (invalid.isNotEmpty) {
      throw ArgumentError('알 수 없거나 타입이 다른 설정 폼 키: $invalid');
    }

    final missing = <String>[
      ..._textKeys.where((key) => !texts.containsKey(key)),
      ..._flagKeys.where((key) => !flags.containsKey(key)),
    ];
    if (missing.isNotEmpty) {
      throw ArgumentError('설정 폼 키가 누락되었습니다: $missing');
    }
  }
}
