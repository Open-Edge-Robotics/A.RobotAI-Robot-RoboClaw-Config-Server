// frontend/test/theme_controller_test.dart
//
// ThemeController 가 ThemeModeStore 를 통해 사용자 테마 선택을 기억하는지 검증한다.
// 브라우저(LocalStorage) 대신 FakeThemeModeStore 를 주입한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/theme/theme_controller.dart';
import 'package:frontend/storage/theme_mode_store.dart';

class FakeThemeModeStore implements ThemeModeStore {
  FakeThemeModeStore([this.value]);

  String? value;
  int writeCount = 0;

  @override
  String? read() => value;

  @override
  void write(String modeName) {
    value = modeName;
    writeCount++;
  }

  @override
  void clear() => value = null;
}

void main() {
  group('ThemeModeCodec', () {
    test('저장 문자열을 ThemeMode 로 변환한다', () {
      expect(ThemeModeCodec.decode('light'), ThemeMode.light);
      expect(ThemeModeCodec.decode('dark'), ThemeMode.dark);
    });

    test('알 수 없는 값/빈 값은 fallback 을 사용한다', () {
      expect(ThemeModeCodec.decode(null), ThemeMode.light);
      expect(ThemeModeCodec.decode(''), ThemeMode.light);
      expect(ThemeModeCodec.decode('sepia'), ThemeMode.light);
      expect(
        ThemeModeCodec.decode('sepia', fallback: ThemeMode.dark),
        ThemeMode.dark,
      );
    });

    test('ThemeMode 를 저장 문자열로 변환한다', () {
      expect(ThemeModeCodec.encode(ThemeMode.light), 'light');
      expect(ThemeModeCodec.encode(ThemeMode.dark), 'dark');
      // system 은 다크가 아닌 값으로 취급한다.
      expect(ThemeModeCodec.encode(ThemeMode.system), 'light');
    });
  });

  group('ThemeController', () {
    test('저장된 값이 없으면 라이트 테마가 기본값이다', () {
      final controller = ThemeController(store: FakeThemeModeStore());
      expect(controller.mode, ThemeMode.light);
      expect(controller.isDark, isFalse);
    });

    test('저장된 다크 테마를 복원한다', () {
      final controller = ThemeController(store: FakeThemeModeStore('dark'));
      expect(controller.mode, ThemeMode.dark);
      expect(controller.isDark, isTrue);
    });

    test('알 수 없는 저장 값은 라이트 테마로 복원한다', () {
      final controller = ThemeController(store: FakeThemeModeStore('??'));
      expect(controller.mode, ThemeMode.light);
    });

    test('toggle 은 라이트/다크를 오가며 저장소에 기록한다', () {
      final store = FakeThemeModeStore();
      final controller = ThemeController(store: store);

      var notified = 0;
      controller.addListener(() => notified++);

      controller.toggle();
      expect(controller.mode, ThemeMode.dark);
      expect(store.value, 'dark');
      expect(notified, 1);

      controller.toggle();
      expect(controller.mode, ThemeMode.light);
      expect(store.value, 'light');
      expect(notified, 2);
    });

    test('같은 모드로 setMode 하면 저장/알림을 하지 않는다', () {
      final store = FakeThemeModeStore();
      final controller = ThemeController(store: store);

      var notified = 0;
      controller.addListener(() => notified++);

      controller.setMode(ThemeMode.light);
      expect(store.writeCount, 0);
      expect(notified, 0);
    });

    test('setMode 는 저장소에 기록하고 리스너에게 알린다', () {
      final store = FakeThemeModeStore();
      final controller = ThemeController(store: store);

      controller.setMode(ThemeMode.dark);
      expect(controller.mode, ThemeMode.dark);
      expect(store.value, 'dark');
    });

    test('같은 저장소로 새 컨트롤러를 만들면 이전 선택이 복원된다', () {
      final store = FakeThemeModeStore();
      ThemeController(store: store).toggle();

      // 새로고침(앱 재시작) 상황 재현
      final restored = ThemeController(store: store);
      expect(restored.mode, ThemeMode.dark);
    });

    test('reset 은 기본 라이트 테마로 되돌리고 저장 값을 지운다', () {
      final store = FakeThemeModeStore('dark');
      final controller = ThemeController(store: store);

      controller.reset();
      expect(controller.mode, ThemeMode.light);
      expect(store.value, isNull);
    });
  });
}
