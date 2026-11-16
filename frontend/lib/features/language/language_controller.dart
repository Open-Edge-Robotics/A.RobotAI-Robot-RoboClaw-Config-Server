// frontend/lib/features/language/language_controller.dart
//
// 앱 언어 상태를 관리하는 Controller.
// LanguageStore 를 주입받아 새로고침(앱 재시작) 후에도 사용자의 언어 선택을 복원한다.
// 기본 언어는 한국어다. 기존 위젯이 읽는 전역 LanguageManager 도 함께 동기화한다.

import 'package:material_ui/material_ui.dart';
import '../../storage/language_store.dart';
import '../../utils/localization.dart';

class LanguageController extends ChangeNotifier {
  final LanguageStore store;

  String _code;

  LanguageController({required this.store})
    : _code = LanguageCodeCodec.decode(store.read()) {
    // 첫 렌더부터 복원된 언어로 번역되도록 전역 어댑터를 맞춘다.
    LanguageManager.languageCode = _code;
  }

  String get code => _code;

  bool get isKo => _code == LanguageCodeCodec.ko;

  /// 한국어/영어를 전환하고 선택을 저장한다.
  void toggle() => setCode(isKo ? LanguageCodeCodec.en : LanguageCodeCodec.ko);

  /// 언어를 지정하고 선택을 저장한다. 같은 값이거나 지원하지 않는 값이면 아무 것도 하지 않는다.
  void setCode(String code) {
    if (!LanguageCodeCodec.isSupported(code)) return;
    if (_code == code) return;
    _code = code;
    store.write(code);
    LanguageManager.languageCode = code;
    notifyListeners();
  }

  /// 기본 언어(한국어)로 되돌리고 저장 값을 지운다.
  void reset() {
    final changed = _code != LanguageCodeCodec.fallback;
    _code = LanguageCodeCodec.fallback;
    store.clear();
    LanguageManager.languageCode = _code;
    if (changed) notifyListeners();
  }
}
