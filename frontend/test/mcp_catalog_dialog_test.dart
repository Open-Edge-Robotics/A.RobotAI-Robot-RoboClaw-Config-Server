// frontend/test/mcp_catalog_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/api/http_admin_api.dart';
import 'package:frontend/storage/token_store.dart';
import 'package:frontend/widgets/mcp_catalog_dialog.dart';

class FakeTokenStore implements TokenStore {
  String? value;
  @override
  String? read() => value;
  @override
  void write(String token) => value = token;
  @override
  void clear() => value = null;
}

void main() {
  setUp(() {
    HttpAdminApi.instance = HttpAdminApi(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/mcp/catalog')) {
          return http.Response(
            '{"servers":[{"name":"fs","display_name":"Filesystem","transport":"stdio","command":"npx"}]}',
            200,
          );
        }
        return http.Response('[]', 200);
      }),
      tokenStore: FakeTokenStore(),
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
              onPressed: () => showMcpCatalogDialog(context),
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
              onPressed: () => showMcpCatalogDialog(context),
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
}
