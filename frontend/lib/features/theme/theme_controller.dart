// frontend/lib/features/theme/theme_controller.dart
//
// 앱 테마 상태를 관리하는 Controller.
// ThemeModeStore 를 주입받아 새로고침(앱 재시작) 후에도 사용자의 테마 선택을 복원한다.
// 기본 테마는 라이트 모드다.

import 'package:flutter/material.dart';
import '../../storage/theme_mode_store.dart';

class ThemeController extends ChangeNotifier {
  final ThemeModeStore store;

  /// 저장된 값이 없을 때 사용할 테마.
  final ThemeMode fallbackMode;

  ThemeMode _mode;

  ThemeController({required this.store, this.fallbackMode = ThemeMode.light})
    : _mode = ThemeModeCodec.decode(store.read(), fallback: fallbackMode);

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  /// 라이트/다크를 전환하고 선택을 저장한다.
  void toggle() => setMode(isDark ? ThemeMode.light : ThemeMode.dark);

  /// 테마를 지정하고 선택을 저장한다. 같은 값이면 아무 것도 하지 않는다.
  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    store.write(ThemeModeCodec.encode(mode));
    notifyListeners();
  }

  /// 기본 테마(라이트)로 되돌리고 저장 값을 지운다.
  void reset() {
    final changed = _mode != fallbackMode;
    _mode = fallbackMode;
    store.clear();
    if (changed) notifyListeners();
  }
}
