// frontend/lib/api/api_exception.dart
//
// 관리자 API 오류의 중립 타입. HTTP 구현(http_admin_api.dart)과 분리해 두어
// UI/Controller 가 특정 구현(HttpAdminApi)을 import 하지 않고 오류를 다룰 수 있다.

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  ApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}
