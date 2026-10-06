// frontend/test/test_case_list_editor_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/scenario_model.dart';
import 'package:frontend/widgets/test_case_list_editor.dart';

void main() {
  Future<void> pumpEditor(WidgetTester tester, List<TestCase> tcs) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TestCaseListEditor(
              testCases: tcs,
              onChanged: (_) {},
              isEditing: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('테스트 케이스가 없으면 빈 상태를 표시한다', (tester) async {
    await pumpEditor(tester, []);
    expect(find.text('정의된 테스트 케이스가 없습니다.'), findsOneWidget);
  });

  testWidgets('테스트 케이스 목록을 표시한다', (tester) async {
    await pumpEditor(tester, [
      TestCase(id: 'tc1', name: 'Ping', step: 'Step 1', type: 'ping'),
      TestCase(id: 'tc2', name: 'Battery', step: 'Step 1', type: 'battery'),
    ]);
    expect(find.text('Ping'), findsWidgets);
    expect(find.text('Battery'), findsWidgets);
  });

  testWidgets('테스트 케이스 추가 템플릿 메뉴가 열린다', (tester) async {
    await pumpEditor(tester, []);

    await tester.tap(find.text('테스트 케이스 추가'));
    await tester.pumpAndSettle();

    expect(find.text('ping'), findsOneWidget);
    expect(find.text('battery'), findsOneWidget);
  });
}
