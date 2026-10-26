// frontend/test/app_theme_test.dart
//
// 앱 루트(App)가 라이트 테마를 기본값으로 사용하고, 사용자가 고른 테마를
// 저장소에서 복원하는지 검증한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/api/http_admin_api.dart';
import 'package:frontend/app.dart';
import 'package:frontend/features/theme/theme_controller.dart';
import 'package:frontend/storage/theme_mode_store.dart';
import 'package:frontend/storage/token_store.dart';
import 'package:frontend/utils/localization.dart';

class FakeThemeModeStore implements ThemeModeStore {
  FakeThemeModeStore([this.value]);

  String? value;

  @override
  String? read() => value;

  @override
  void write(String modeName) => value = modeName;

  @override
  void clear() => value = null;
}

class FakeTokenStore implements TokenStore {
  String? value;
  @override
  String? read() => value;
  @override
  void write(String token) => value = token;
  @override
  void clear() => value = null;
}

Widget buildApp(ThemeModeStore store) =>
    App(themeController: ThemeController(store: store));

void main() {
  setUp(() {
    // 대시보드 탭이 초기 로딩에서 네트워크를 호출하지 않도록 막는다.
    HttpAdminApi.instance = HttpAdminApi(
      client: MockClient((request) async => http.Response('[]', 200)),
      tokenStore: FakeTokenStore(),
    );
  });

  Future<void> pumpApp(WidgetTester tester, ThemeModeStore store) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildApp(store));
    await tester.pumpAndSettle();
  }

  Brightness brightnessOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

  testWidgets('저장된 설정이 없으면 라이트 테마로 시작한다', (tester) async {
    await pumpApp(tester, FakeThemeModeStore());
    expect(brightnessOf(tester), Brightness.light);
  });

  testWidgets('저장된 다크 테마를 복원한다', (tester) async {
    await pumpApp(tester, FakeThemeModeStore('dark'));
    expect(brightnessOf(tester), Brightness.dark);
  });

  testWidgets('테마 토글이 저장소에 기록되어 재시작 후에도 유지된다', (tester) async {
    final store = FakeThemeModeStore();

    await pumpApp(tester, store);
    expect(brightnessOf(tester), Brightness.light);

    await tester.tap(find.byTooltip('다크 모드 전환'.tr));
    await tester.pumpAndSettle();

    expect(store.value, 'dark');
    expect(brightnessOf(tester), Brightness.dark);

    // 새로고침(앱 재시작) 재현
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp(tester, store);

    expect(brightnessOf(tester), Brightness.dark);
  });
}
