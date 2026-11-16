// frontend/test/mcp_catalog_dialog_test.dart

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/widgets/mcp_catalog_dialog.dart';

import 'support/app_dependencies.dart';
import 'support/localization_audit.dart';

void main() {
  late TestDependencies deps;

  setUp(() {
    deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/mcp/catalog')) {
          return http.Response(
            '{"servers":[{"name":"fs","display_name":"Filesystem","transport":"stdio","command":"npx"}]}',
            200,
          );
        }
        return http.Response('[]', 200);
      },
    );
  });

  testWidgets('MCP 카탈로그 다이얼로그가 항목을 표시한다', (tester) async {
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

    expect(find.text('MCP 서버 찾아보기'), findsOneWidget);
    expect(find.text('Filesystem'), findsOneWidget);
  });

  testWidgets('MCP 카탈로그 검색 필드가 표시된다', (tester) async {
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

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('영어 모드에서는 카탈로그 다이얼로그에 한국어가 남지 않는다', (tester) async {
    useEnglishLocale();

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

    // 카탈로그 항목(이름/설명/명령)은 서버 제공 데이터이므로 검사 대상이 아니다.
    expectNoKoreanText(tester);
  });
}
