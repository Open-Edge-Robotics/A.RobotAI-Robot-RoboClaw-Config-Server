// frontend/lib/services/logger.dart

import 'package:flutter/foundation.dart';

enum LogLevel { info, warning, error }

class AppLogger {
  static void log(
    LogLevel level,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    // info/warning은 디버그 빌드에서만, error는 운영 빌드에서도 콘솔에 남긴다.
    if (!kDebugMode && level != LogLevel.error) return;

    final time = DateTime.now().toIso8601String();
    final prefix = level.name.toUpperCase();
    debugPrint('[$time] [$prefix] $message');
    if (error != null) {
      debugPrint('  Details: $error');
    }
    if (stackTrace != null) {
      debugPrint('  StackTrace:\n$stackTrace');
    }
  }

  static void info(String message) => log(LogLevel.info, message);
  static void warning(String message) => log(LogLevel.warning, message);
  static void error(String message, [dynamic error, StackTrace? stack]) =>
      log(LogLevel.error, message, error, stack);
}
