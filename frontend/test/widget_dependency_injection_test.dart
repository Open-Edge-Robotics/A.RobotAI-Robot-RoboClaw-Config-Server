// frontend/test/widget_dependency_injection_test.dart
//
// Widget 이 전역 인스턴스(HttpAdminApi.instance / DownloadHelper.instance /
// FilePickerHelper.instance / ApiService)를 읽지 않고, 생성자로 주입된
// AppDependencies(또는 개별 의존성)만 사용하는지 검증한다.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/api/http_admin_api.dart';
import 'package:frontend/features/language/language_controller.dart';
import 'package:frontend/screens/config_tab.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/storage/language_store.dart';
import 'package:frontend/widgets/mcp_servers_input_form.dart';

import 'support/app_dependencies.dart';

/// 주입 검증만 하므로 언어는 기본값(한국어)을 유지하는 저장소를 쓴다.
class FakeLanguageStore implements LanguageStore {
  String? value;

  @override
  String? read() => value;

  @override
  void write(String code) => value = code;

  @override
  void clear() => value = null;
}

const _cfg1Json =
    '{"ID":1,"name":"cfg1","robot_name":"butler","environment":"office"}';

void main() {
  Future<void> useWideView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpConfigTab(WidgetTester tester, TestDependencies deps) async {
    await useWideView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigTab(
            api: deps.dependencies.api,
            downloader: deps.dependencies.downloader,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpDashboard(WidgetTester tester, TestDependencies deps) async {
    await useWideView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          themeMode: ThemeMode.dark,
          onThemeModeChanged: () {},
          languageController: LanguageController(store: FakeLanguageStore()),
          dependencies: deps.dependencies,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('주입한 API 로 .env 를 조회하고 주입한 다운로더로 저장한다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/configs/1/files/.env')) {
          return http.Response('ROBOT_ID=butler', 200);
        }
        if (request.url.path.endsWith('/configs')) {
          return http.Response('[$_cfg1Json]', 200);
        }
        return http.Response('[]', 200);
      },
    );

    await pumpConfigTab(tester, deps);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();
    await tester.tap(find.text('.env (환경 변수)'));
    await tester.pumpAndSettle();

    expect(
      deps.requests.map((request) => request.url.path),
      contains('/api/v1/admin/configs/1/files/.env'),
    );
    expect(deps.downloader.textDownloads, hasLength(1));
    expect(deps.downloader.textDownloads.single.content, 'ROBOT_ID=butler');
    expect(deps.downloader.textDownloads.single.filename, '.env');
  });

  testWidgets('주입한 API 로 MCP 카탈로그를 조회해 서버를 추가한다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/mcp/catalog')) {
          return http.Response(
            '{"servers":[{"name":"fs","display_name":"Filesystem",'
            '"transport":"stdio","command":"npx"}]}',
            200,
          );
        }
        return http.Response('[]', 200);
      },
    );
    final controller = TextEditingController(text: '[]');
    addTearDown(controller.dispose);

    await useWideView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: McpServersInputForm(
            controller: controller,
            isEditing: true,
            api: deps.dependencies.api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('MCP 서버 찾아보기'));
    await tester.pumpAndSettle();

    expect(
      deps.requests.map((request) => request.url.path),
      contains('/api/v1/admin/mcp/catalog'),
    );
    expect(find.text('Filesystem'), findsOneWidget);

    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(controller.text, contains('"name":"fs"'));
  });

  testWidgets('토큰 다이얼로그는 주입한 TokenStore 를 읽고 저장/소거한다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async => http.Response('[]', 200),
      token: 'stored-token',
    );

    await pumpDashboard(tester, deps);

    await tester.tap(find.byIcon(Icons.vpn_key));
    await tester.pumpAndSettle();

    final tokenField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
    );
    expect(tokenField.controller?.text, 'stored-token');

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'rotated-token',
    );
    await tester.tap(find.text('저장 및 적용'));
    await tester.pumpAndSettle();

    expect(deps.tokenStore.writes, ['rotated-token']);
    expect(deps.tokenStore.value, 'rotated-token');

    await tester.tap(find.byIcon(Icons.vpn_key));
    await tester.pumpAndSettle();
    await tester.tap(find.text('토큰 소거'));
    await tester.pumpAndSettle();

    expect(deps.tokenStore.clearCount, 1);
    expect(deps.tokenStore.value, isNull);
  });

  testWidgets('백업 내보내기는 주입한 API 와 다운로더를 사용한다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/transfer/export')) {
          return http.Response('{"version":1}', 200);
        }
        return http.Response('[]', 200);
      },
    );

    await pumpDashboard(tester, deps);

    await tester.tap(find.byIcon(Icons.save_alt));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 설정 내보내기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내보내기'));
    await tester.pumpAndSettle();

    expect(
      deps.requests.map((request) => request.url.path),
      contains('/api/v1/admin/transfer/export'),
    );
    expect(deps.downloader.textDownloads, hasLength(1));
    expect(deps.downloader.textDownloads.single.content, '{"version":1}');
  });

  testWidgets('두 위젯 트리가 각자 주입한 API 결과를 사용한다 (전역 인스턴스 변경 없음)', (tester) async {
    final globalInstance = HttpAdminApi.instance;
    final alphaDeps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/configs')) {
          return http.Response(
            '[{"ID":1,"name":"alpha","robot_name":"butler","environment":"office"}]',
            200,
          );
        }
        return http.Response('[]', 200);
      },
    );
    final betaDeps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/configs')) {
          return http.Response(
            '[{"ID":2,"name":"beta","robot_name":"former","environment":"factory"}]',
            200,
          );
        }
        return http.Response('[]', 200);
      },
    );

    await useWideView(tester);

    // 서로 다른 의존성을 주입한 두 개의 ConfigTab 위젯 트리를 차례로 띄운다.
    // Key 가 다르므로 State 가 재사용되지 않고 각 트리가 자기 API 를 쓴다.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigTab(
            key: const Key('alpha-tab'),
            api: alphaDeps.dependencies.api,
            downloader: alphaDeps.dependencies.downloader,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigTab(
            key: const Key('beta-tab'),
            api: betaDeps.dependencies.api,
            downloader: betaDeps.dependencies.downloader,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('alpha'), findsNothing);

    expect(identical(HttpAdminApi.instance, globalInstance), isTrue);
  });
}
