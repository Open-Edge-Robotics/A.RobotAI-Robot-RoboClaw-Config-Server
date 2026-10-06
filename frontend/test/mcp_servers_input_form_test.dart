// frontend/test/mcp_servers_input_form_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/mcp_servers_input_form.dart';

void main() {
  Future<void> pumpForm(
    WidgetTester tester,
    TextEditingController controller,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: McpServersInputForm(controller: controller, isEditing: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('MCP 서버가 없으면 빈 상태를 표시한다', (tester) async {
    await pumpForm(tester, TextEditingController(text: '[]'));
    expect(find.text('등록된 MCP 서버가 없습니다.'), findsOneWidget);
  });

  testWidgets('MCP 서버 목록을 표시한다', (tester) async {
    await pumpForm(
      tester,
      TextEditingController(
        text: '[{"name":"fs","transport":"stdio","command":"npx"}]',
      ),
    );
    expect(find.text('fs'), findsOneWidget);
  });

  testWidgets('마스킹된 값(********)은 빈 상태로 처리한다', (tester) async {
    await pumpForm(tester, TextEditingController(text: '********'));
    expect(find.text('등록된 MCP 서버가 없습니다.'), findsOneWidget);
  });

  // 회귀: JSON 전체가 마스킹되어 등록한 MCP 서버가 보이지 않던 문제.
  // 자격 증명만 마스킹되면 서버 카드는 그대로 보여야 한다.
  testWidgets('자격 증명만 마스킹된 목록도 서버를 표시한다', (tester) async {
    await pumpForm(
      tester,
      TextEditingController(
        text:
            '[{"name":"fs","transport":"stdio","command":"npx",'
            '"env":{"GITHUB_TOKEN":"********"}}]',
      ),
    );

    expect(find.text('fs'), findsOneWidget);
    expect(find.text('npx'), findsOneWidget);
    expect(find.text('등록된 MCP 서버가 없습니다.'), findsNothing);
    expect(find.textContaining('마스킹되어 있습니다'), findsOneWidget);
  });

  testWidgets('MCP 서버 추가 버튼으로 서버 폼을 추가한다', (tester) async {
    final controller = TextEditingController(text: '[]');
    await pumpForm(tester, controller);

    await tester.tap(find.text('MCP 서버 추가'));
    await tester.pumpAndSettle();

    expect(find.text('서버 이름'), findsWidgets);
  });
}
