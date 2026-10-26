// frontend/lib/storage/theme_mode_store.dart
//
// 사용자가 선택한 테마(라이트/다크) 저장소 추상화.
// 브라우저 LocalStorage(WebThemeModeStore)와 테스트용 Fake 를 교체 주입할 수 있게 한다.

import 'package:flutter/material.dart';

/// 테마 선택 값을 문자열로 저장/복원하는 저장소.
abstract interface class ThemeModeStore {
  /// 저장된 테마 값을 읽는다. 없으면 null.
  String? read();

  /// 테마 값을 저장한다.
  void write(String modeName);

  /// 저장된 테마 값을 제거한다(기본값으로 복귀).
  void clear();
}

/// [ThemeMode] 와 저장 문자열 사이의 변환 규칙.
///
/// package:web 없이 검증할 수 있도록 브라우저 구현과 분리해 둔다.
class ThemeModeCodec {
  static const String light = 'light';
  static const String dark = 'dark';

  /// 저장 문자열을 [ThemeMode] 로 변환한다.
  ///
  /// 알 수 없는 값이나 빈 값이면 [fallback] 을 사용한다.
  static ThemeMode decode(
    String? value, {
    ThemeMode fallback = ThemeMode.light,
  }) {
    switch (value) {
      case light:
        return ThemeMode.light;
      case dark:
        return ThemeMode.dark;
      default:
        return fallback;
    }
  }

  /// [ThemeMode] 를 저장 문자열로 변환한다. [ThemeMode.system] 은 [light] 로 취급한다.
  static String encode(ThemeMode mode) => mode == ThemeMode.dark ? dark : light;
}
