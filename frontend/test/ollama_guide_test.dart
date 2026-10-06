// frontend/test/ollama_guide_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/ollama_guide.dart';

void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    required bool isEditing,
    required VoidCallback onApply,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OllamaGuidePanel(
            isEditing: isEditing,
            onApplyTemplate: onApply,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Ollama 가이드 패널이 표시된다', (tester) async {
    await pumpPanel(tester, isEditing: true, onApply: () {});
    expect(find.text('Ollama 옵션 JSON 가이드'), findsOneWidget);
    expect(find.text('기본 템플릿 입력'), findsOneWidget);
  });

  testWidgets('편집 모드에서 템플릿 적용 버튼이 동작한다', (tester) async {
    var applied = false;
    await pumpPanel(tester, isEditing: true, onApply: () => applied = true);

    await tester.tap(find.text('기본 템플릿 입력'));
    expect(applied, isTrue);
  });

  testWidgets('비편집 모드에서는 템플릿 적용 버튼이 비활성화된다', (tester) async {
    await pumpPanel(tester, isEditing: false, onApply: () {});

    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '기본 템플릿 입력'),
    );
    expect(button.onPressed, isNull);
  });
}
