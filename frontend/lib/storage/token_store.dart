// frontend/lib/storage/token_store.dart
//
// 관리자 인증 토큰 저장소 추상화.
// 브라우저 LocalStorage(WebTokenStore)와 테스트용 Fake 를 교체 주입할 수 있게 한다.

abstract interface class TokenStore {
  /// 저장된 토큰을 읽는다. 없으면 null.
  String? read();

  /// 토큰을 저장한다.
  void write(String token);

  /// 토큰을 제거한다.
  void clear();
}
