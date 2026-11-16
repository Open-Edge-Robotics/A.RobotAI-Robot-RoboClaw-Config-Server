// frontend/lib/features/configs/config_form_values.dart
//
// Ollama 옵션 폼 값 (TextEditingController 텍스트 형태).
// Flutter 에 의존하지 않는 순수 값 타입이며, 기존 import 경로를 위해
// config_form_mapper.dart 가 이 타입을 다시 내보낸다.

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
