// frontend/lib/storage/web_token_store.dart
//
// 브라우저 LocalStorage 기반 TokenStore 구현.
// package:web 에 대한 의존은 이 파일에만 국한한다.

import 'package:web/web.dart' as web;
import 'token_store.dart';

class WebTokenStore implements TokenStore {
  static const String _key = 'admin_token';

  @override
  String? read() => web.window.localStorage.getItem(_key);

  @override
  void write(String token) => web.window.localStorage.setItem(_key, token);

  @override
  void clear() => web.window.localStorage.removeItem(_key);
}
