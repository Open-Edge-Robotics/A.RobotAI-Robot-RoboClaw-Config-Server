// frontend/test/mcp_catalog_edge_test.dart
//
// MCP 카탈로그 다이얼로그의 미탐지 엣지 케이스:
// - 결과가 없을 때 안내 문구
// - 조회 실패 시 오류 상태와 '다시 시도' 재조회
// - 검색 입력 디바운스(300ms) 후 한 번만 재조회

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/widgets/mcp_catalog_dialog.dart';

import 'support/app_dependencies.dart';

const _serversJson =
    '{"servers":[{"name":"fs","display_name":"Filesystem",'
    '"transport":"stdio","command":"npx"}]}';

int _catalogRequestCount(TestDependencies deps) => deps.requests
    .where((request) => request.url.path.endsWith('/mcp/catalog'))
    .length;

void main() {
  Future<void> pumpAndOpenCatalog(
    WidgetTester tester,
    TestDependencies deps,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showMcpCatalogDialog(context, api: deps.dependencies.api),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('카탈로그 결과가 비어 있으면 검색 결과가 없습니다 안내가 표시된다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async => http.Response('{"servers":[]}', 200),
    );

    await pumpAndOpenCatalog(tester, deps);

    expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('카탈로그 조회가 실패하면 오류 상태를 보여주고 다시 시도로 재조회한다', (tester) async {
    var failing = true;
    final deps = buildTestDependencies(
      respond: (request) async {
        if (failing) return http.Response('{"error":"boom"}', 500);
        return http.Response(_serversJson, 200);
      },
    );

    await pumpAndOpenCatalog(tester, deps);

    expect(find.text('카탈로그 조회 실패'), findsOneWidget);
    expect(find.textContaining('MCP 카탈로그 조회 실패'), findsOneWidget);
    expect(find.text('검색 결과가 없습니다.'), findsNothing);

    failing = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(_catalogRequestCount(deps), 2);
    expect(find.text('카탈로그 조회 실패'), findsNothing);
    expect(find.text('Filesystem'), findsOneWidget);
  });

  testWidgets('검색 입력은 300ms 디바운스 후 한 번만 재조회한다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async => http.Response(_serversJson, 200),
    );

    await pumpAndOpenCatalog(tester, deps);
    expect(_catalogRequestCount(deps), 1, reason: '다이얼로그를 열면 한 번 조회한다');

    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'g');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(searchField, 'gi');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(searchField, 'git');
    await tester.pump(const Duration(milliseconds: 200));

    expect(_catalogRequestCount(deps), 1, reason: '입력이 이어지는 동안에는 재조회하지 않는다');

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(_catalogRequestCount(deps), 2, reason: '디바운스 만료 후 한 번만 조회한다');
    expect(
      deps.requests.last.url.queryParameters['q'],
      'git',
      reason: '마지막 입력값으로 조회한다',
    );
  });
}
