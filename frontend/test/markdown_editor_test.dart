// frontend/test/markdown_editor_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/markdown_editor.dart';

void main() {
  testWidgets('마크다운 에디터가 콘텐츠를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownEditorArea(
              isEditing: true,
              soulCtrl: TextEditingController(text: '로봇 소울'),
              skillsCtrl: TextEditingController(),
              troubleCtrl: TextEditingController(),
              limitsCtrl: TextEditingController(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('로봇 소울'), findsOneWidget);
  });
}
