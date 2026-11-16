// frontend/test/language_controller_test.dart
//
// LanguageController 가 LanguageStore 를 통해 사용자의 언어 선택(ko/en)을 기억하고,
// 기존 전역 파사드(LanguageManager)를 함께 갱신하는지 검증한다.
// 브라우저(LocalStorage) 대신 FakeLanguageStore 를 주입한다.

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/language/language_controller.dart';
import 'package:frontend/storage/language_store.dart';
import 'package:frontend/utils/localization.dart';

class FakeLanguageStore implements LanguageStore {
  FakeLanguageStore([this.value]);

  String? value;
  int readCount = 0;
  int writeCount = 0;
  int clearCount = 0;

  @override
  String? read() {
    readCount++;
    return value;
  }

  @override
  void write(String code) {
    value = code;
    writeCount++;
  }

  @override
  void clear() {
    value = null;
    clearCount++;
  }
}

void main() {
  // 전역 어댑터(LanguageManager)는 테스트 간에 남으므로 매 테스트 후 되돌린다.
  tearDown(() => LanguageManager.languageCode = 'ko');

  group('LanguageController', () {
    test('저장된 값이 없으면 한국어가 기본값이다', () {
      final controller = LanguageController(store: FakeLanguageStore());

      expect(controller.code, 'ko');
      expect(controller.isKo, isTrue);
      expect(LanguageManager.languageCode, 'ko');
    });

    test('저장된 en 을 복원하고 전역 어댑터에 반영한다', () {
      final controller = LanguageController(store: FakeLanguageStore('en'));

      expect(controller.code, 'en');
      expect(controller.isKo, isFalse);
      expect(LanguageManager.languageCode, 'en');
      expect('AI 에이전트 설정 대시보드'.tr, 'AI Agent Config Dashboard');
    });

    test('알 수 없는 값과 빈 값은 한국어로 복원한다', () {
      expect(LanguageController(store: FakeLanguageStore('??')).code, 'ko');
      expect(LanguageController(store: FakeLanguageStore('')).code, 'ko');
      expect(LanguageController(store: FakeLanguageStore('KO')).code, 'ko');
    });

    test('setCode 는 저장소에 기록하고 리스너에게 알린다', () {
      final store = FakeLanguageStore();
      final controller = LanguageController(store: store);

      var notified = 0;
      controller.addListener(() => notified++);

      controller.setCode('en');

      expect(controller.code, 'en');
      expect(store.value, 'en');
      expect(notified, 1);
      expect(LanguageManager.languageCode, 'en');
      expect('설정 관리'.tr, 'Configs');
    });

    test('같은 값으로 setCode 하면 저장/알림을 하지 않는다', () {
      final store = FakeLanguageStore();
      final controller = LanguageController(store: store);

      var notified = 0;
      controller.addListener(() => notified++);

      controller.setCode('ko');

      expect(store.writeCount, 0);
      expect(notified, 0);
      expect(controller.code, 'ko');
    });

    test('지원하지 않는 코드는 무시한다', () {
      final store = FakeLanguageStore();
      final controller = LanguageController(store: store);

      var notified = 0;
      controller.addListener(() => notified++);

      controller.setCode('fr');

      expect(controller.code, 'ko');
      expect(store.value, isNull);
      expect(store.writeCount, 0);
      expect(notified, 0);
      expect(LanguageManager.languageCode, 'ko');
    });

    test('toggle 은 한국어/영어를 오가며 저장소에 기록한다', () {
      final store = FakeLanguageStore();
      final controller = LanguageController(store: store);

      var notified = 0;
      controller.addListener(() => notified++);

      controller.toggle();
      expect(controller.code, 'en');
      expect(store.value, 'en');
      expect(notified, 1);

      controller.toggle();
      expect(controller.code, 'ko');
      expect(store.value, 'ko');
      expect(notified, 2);
    });

    test('같은 저장소로 새 컨트롤러를 만들면 이전 선택이 복원된다', () {
      final store = FakeLanguageStore();
      LanguageController(store: store).toggle();

      // 새로고침(앱 재시작) 상황 재현
      final restored = LanguageController(store: store);

      expect(restored.code, 'en');
      expect(LanguageManager.languageCode, 'en');
    });

    test('reset 은 한국어로 되돌리고 저장 값을 지운다', () {
      final store = FakeLanguageStore('en');
      final controller = LanguageController(store: store);

      var notified = 0;
      controller.addListener(() => notified++);

      controller.reset();

      expect(controller.code, 'ko');
      expect(LanguageManager.languageCode, 'ko');
      expect(store.value, isNull);
      expect(store.clearCount, 1);
      expect(notified, 1);
    });

    test('이미 한국어일 때 reset 하면 알림 없이 저장 값만 지운다', () {
      final store = FakeLanguageStore();
      final controller = LanguageController(store: store);

      var notified = 0;
      controller.addListener(() => notified++);

      controller.reset();

      expect(controller.code, 'ko');
      expect(store.clearCount, 1);
      expect(notified, 0);
    });
  });

  group('언어 기본 동작 보존', () {
    test('컨트롤러 없이 LanguageManager 만 써도 기존 API 가 동작한다', () {
      expect(LanguageManager.languageCode, 'ko');
      expect(LanguageManager.isKo, isTrue);
      expect(LanguageManager.tr('삭제'), '삭제');
      expect('번역되지 않은 키'.tr, '번역되지 않은 키');

      LanguageManager.languageCode = 'en';

      expect(LanguageManager.isKo, isFalse);
      expect(LanguageManager.tr('삭제'), 'Delete');
      expect('번역되지 않은 키'.tr, '번역되지 않은 키');
    });
  });
}
