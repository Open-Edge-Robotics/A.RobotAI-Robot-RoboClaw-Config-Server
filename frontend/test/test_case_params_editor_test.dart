// frontend/test/test_case_params_editor_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/scenario_model.dart';
import 'package:frontend/widgets/test_case_params_editor.dart';

void main() {
  Future<void> pumpEditor(WidgetTester tester, TestCase tc) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TestCaseParamsEditor(
            testCase: tc,
            isEditing: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('params 가 있으면 파라미터 에디터를 표시한다', (tester) async {
    final tc = TestCase(
      id: 'tc1',
      name: 'n',
      step: 'Step 1',
      type: 'custom',
      params: {'prompt': 'hello'},
    );
    await pumpEditor(tester, tc);
    expect(find.text('프롬프트 입력 (prompt) *'), findsOneWidget);
  });

  testWidgets('params 가 없으면 안내 메시지를 표시한다', (tester) async {
    final tc = TestCase(id: 'tc1', name: 'n', step: 'Step 1', type: 'ping');
    await pumpEditor(tester, tc);
    expect(find.textContaining('부가 파라미터가 필요하지 않습니다'), findsOneWidget);
  });

  testWidgets('navigation params 를 표시한다', (tester) async {
    final tc = TestCase(
      id: 'tc1',
      name: 'n',
      step: 'Step 1',
      type: 'navigation',
      params: {'mode': 'guardrail'},
    );
    await pumpEditor(tester, tc);
    expect(find.text('주행 모드 (mode)'), findsOneWidget);
  });

  testWidgets('persona params 를 표시한다', (tester) async {
    final tc = TestCase(
      id: 'tc1',
      name: 'n',
      step: 'Step 1',
      type: 'persona',
      params: {'prompt': 'hi'},
    );
    await pumpEditor(tester, tc);
    expect(find.text('LLM 검증 프롬프트 (prompt)'), findsOneWidget);
  });
}
