// frontend/lib/storage/web_language_store.dart
//
// 브라우저 LocalStorage 기반 LanguageStore 구현.
// package:web 에 대한 의존은 이 파일에만 국한한다.

import 'package:web/web.dart' as web;
import 'language_store.dart';

class WebLanguageStore implements LanguageStore {
  static const String _key = 'language_code';

  @override
  String? read() => web.window.localStorage.getItem(_key);

  @override
  void write(String code) => web.window.localStorage.setItem(_key, code);

  @override
  void clear() => web.window.localStorage.removeItem(_key);
}
