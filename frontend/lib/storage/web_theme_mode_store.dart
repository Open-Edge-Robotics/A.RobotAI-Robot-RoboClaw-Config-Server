// frontend/lib/storage/web_theme_mode_store.dart
//
// 브라우저 LocalStorage 기반 ThemeModeStore 구현.
// package:web 에 대한 의존은 이 파일에만 국한한다.

import 'package:web/web.dart' as web;
import 'theme_mode_store.dart';

class WebThemeModeStore implements ThemeModeStore {
  static const String _key = 'theme_mode';

  @override
  String? read() => web.window.localStorage.getItem(_key);

  @override
  void write(String modeName) =>
      web.window.localStorage.setItem(_key, modeName);

  @override
  void clear() => web.window.localStorage.removeItem(_key);
}
