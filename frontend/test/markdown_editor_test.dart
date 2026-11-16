// frontend/test/markdown_editor_test.dart

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/markdown_editor.dart';

import 'support/localization_audit.dart';

void main() {
  Future<void> pump(WidgetTester tester, {String soulText = ''}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownEditorArea(
              isEditing: true,
              soulCtrl: TextEditingController(text: soulText),
              skillsCtrl: TextEditingController(),
              troubleCtrl: TextEditingController(),
              limitsCtrl: TextEditingController(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('마크다운 에디터가 콘텐츠를 표시한다', (tester) async {
    await pump(tester, soulText: '로봇 소울');

    expect(find.text('로봇 소울'), findsOneWidget);
  });

  testWidgets('영어 모드에서는 마크다운 에디터에 한국어가 남지 않는다', (tester) async {
    useEnglishLocale();
    await pump(tester);

    expectNoKoreanText(tester);
  });
}
