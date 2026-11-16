// frontend/lib/storage/language_store.dart
//
// 사용자가 선택한 언어(ko/en) 저장소 추상화.
// 브라우저 LocalStorage(WebLanguageStore)와 테스트용 Fake 를 교체 주입할 수 있게 한다.

/// 언어 선택 값을 문자열로 저장/복원하는 저장소.
abstract interface class LanguageStore {
  /// 저장된 언어 코드를 읽는다. 없으면 null.
  String? read();

  /// 언어 코드를 저장한다.
  void write(String code);

  /// 저장된 언어 코드를 제거한다(기본값으로 복귀).
  void clear();
}

/// 지원하는 언어 코드와 저장 문자열 사이의 변환 규칙.
///
/// package:web 없이 검증할 수 있도록 브라우저 구현과 분리해 둔다.
class LanguageCodeCodec {
  static const String ko = 'ko';
  static const String en = 'en';

  /// 기본 언어. 지원하지 않는 값이나 미저장 값에 사용한다.
  static const String fallback = ko;

  /// 지원하는 언어 코드인지 확인한다.
  static bool isSupported(String code) => code == ko || code == en;

  /// 저장 문자열을 언어 코드로 변환한다.
  ///
  /// 알 수 없는 값이나 빈 값이면 [fallback] 을 사용한다.
  static String decode(String? value) =>
      isSupported(value ?? '') ? value! : fallback;
}
