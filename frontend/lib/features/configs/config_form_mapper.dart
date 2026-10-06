// frontend/lib/features/configs/config_form_mapper.dart
//
// 설정 폼 ↔ 모델 변환 로직. 특히 Ollama 옵션 JSON 의 생성/파싱을 담당한다.
// 순수 로직이므로 Widget 없이 단위 테스트할 수 있다.

import 'dart:convert';

/// Ollama 옵션 폼 값 (TextEditingController 텍스트 형태).
class OllamaFormValues {
  final String numCtx;
  final String temperature;
  final String repeatPenalty;
  final String repeatLastN;
  final String seed;
  final String numPredict;
  final String topK;
  final String topP;
  final String minP;
  final String think;
  final Map<String, dynamic> extraOptions;

  const OllamaFormValues({
    required this.numCtx,
    required this.temperature,
    required this.repeatPenalty,
    required this.repeatLastN,
    required this.seed,
    required this.numPredict,
    required this.topK,
    required this.topP,
    required this.minP,
    required this.think,
    this.extraOptions = const {},
  });
}

class ConfigFormMapper {
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
