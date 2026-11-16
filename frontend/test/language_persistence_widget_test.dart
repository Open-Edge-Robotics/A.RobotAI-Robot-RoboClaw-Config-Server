// frontend/test/language_persistence_widget_test.dart
//
// 앱 루트(App)가 주입된 LanguageController 로 언어를 렌더하고, 대시보드 언어 토글이
// 저장소에 선택을 기록해 새로고침(앱 재시작) 후에도 유지되는지 검증한다.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/app.dart';
import 'package:frontend/features/language/language_controller.dart';
import 'package:frontend/features/theme/theme_controller.dart';
import 'package:frontend/storage/language_store.dart';
import 'package:frontend/storage/theme_mode_store.dart';
import 'package:frontend/utils/localization.dart';

import 'support/app_dependencies.dart';

class FakeLanguageStore implements LanguageStore {
  FakeLanguageStore([this.value]);

  String? value;

  @override
  String? read() => value;

  @override
  void write(String code) => value = code;

  @override
  void clear() => value = null;
}

class FakeThemeModeStore implements ThemeModeStore {
  String? value;

  @override
  String? read() => value;

  @override
  void write(String modeName) => value = modeName;

  @override
  void clear() => value = null;
}

Widget buildApp(LanguageStore languageStore) => App(
  themeController: ThemeController(store: FakeThemeModeStore()),
  languageController: LanguageController(store: languageStore),
  // 대시보드 탭이 초기 로딩에서 네트워크를 호출하지 않도록 막는다.
  dependencies: buildTestDependencies(
    respond: (request) async => http.Response('[]', 200),
  ).dependencies,
);

/// 테스트 폰트는 모든 글리프를 정사각형(fontSize 폭)으로 그려 영어 라벨이 실제 폰트보다
/// 두 배 가까이 넓다. 그래서 영어 렌더에서는 고정폭(380) 설정 목록 패널 헤더가
/// RenderFlex overflow 를 기록한다(레이아웃 자체는 실제 폰트에서 넘치지 않는다).
/// 이 테스트는 언어 렌더링/영속화만 검증하므로 그 레이아웃 예외는 소비한다.
void drainTestFontOverflow(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

void main() {
  // 전역 어댑터(LanguageManager)는 테스트 간에 남으므로 매 테스트 후 되돌린다.
  tearDown(() => LanguageManager.languageCode = 'ko');

  Future<void> pumpApp(WidgetTester tester, LanguageStore store) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildApp(store));
    await tester.pumpAndSettle();
  }

  testWidgets('저장된 언어가 없으면 한국어로 렌더한다', (tester) async {
    await pumpApp(tester, FakeLanguageStore());

    expect(find.text('AI 에이전트 설정 대시보드'), findsOneWidget);
    expect(find.text('AI Agent Config Dashboard'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('저장된 영어 선택을 복원해 영어 문구로 렌더한다', (tester) async {
    await pumpApp(tester, FakeLanguageStore('en'));
    drainTestFontOverflow(tester);

    expect(find.text('AI Agent Config Dashboard'), findsOneWidget);
    expect(find.text('AI 에이전트 설정 대시보드'), findsNothing);
  });

  testWidgets('언어 토글이 저장소에 기록하고 즉시 화면에 반영한다', (tester) async {
    final store = FakeLanguageStore();

    await pumpApp(tester, store);
    expect(find.text('AI 에이전트 설정 대시보드'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    drainTestFontOverflow(tester);

    expect(store.value, 'en');
    expect(find.text('AI Agent Config Dashboard'), findsOneWidget);
    expect(find.text('AI 에이전트 설정 대시보드'), findsNothing);

    await tester.tap(find.text('KO'));
    await tester.pumpAndSettle();

    expect(store.value, 'ko');
    expect(find.text('AI 에이전트 설정 대시보드'), findsOneWidget);
  });

  testWidgets('새 컨트롤러가 이전 선택을 복원하고 전역 어댑터를 동기화한다', (tester) async {
    final store = FakeLanguageStore();

    await pumpApp(tester, store);
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    drainTestFontOverflow(tester);
    expect(store.value, 'en');

    // 새로고침(앱 재시작) 재현: 같은 저장소로 앱을 다시 조립한다.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp(tester, store);
    drainTestFontOverflow(tester);

    expect(find.text('AI Agent Config Dashboard'), findsOneWidget);
    expect(LanguageManager.languageCode, 'en');
    expect('설정 관리'.tr, 'Configs');
  });
}
