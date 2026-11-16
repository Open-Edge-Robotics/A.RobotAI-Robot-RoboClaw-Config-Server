// frontend/test/config_sections_test.dart

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/config_langsmith_section.dart';
import 'package:frontend/widgets/config_learning_section.dart';
import 'package:frontend/widgets/config_markdown_section.dart';

import 'support/localization_audit.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('마크다운 섹션 헤더가 표시된다', (tester) async {
    await pump(
      tester,
      ConfigMarkdownSection(
        isEditing: true,
        soulCtrl: TextEditingController(),
        skillsCtrl: TextEditingController(),
        troubleCtrl: TextEditingController(),
        limitsCtrl: TextEditingController(),
      ),
    );
    expect(find.text('9. 에이전트 마크다운 & 한계 스펙 정의'), findsOneWidget);
  });

  testWidgets('학습 섹션 헤더가 표시된다', (tester) async {
    await pump(
      tester,
      ConfigLearningSection(
        isEditing: true,
        enableSkillLearning: true,
        onEnableSkillLearningChanged: (_) {},
        skillLearningSuccessSampleRateCtrl: TextEditingController(),
        skillLearningReflectIntervalSecCtrl: TextEditingController(),
      ),
    );
    expect(find.text('8. 스킬 자가학습 설정 (RAG)'), findsOneWidget);
  });

  testWidgets('LangSmith 섹션 헤더가 표시된다', (tester) async {
    await pump(
      tester,
      ConfigLangsmithSection(
        isEditing: true,
        langsmithTracing: true,
        onLangsmithTracingChanged: (_) {},
        langsmithApiKeyCtrl: TextEditingController(),
        langsmithWorkspaceIdCtrl: TextEditingController(),
        langsmithProjectCtrl: TextEditingController(),
        langsmithEndpointCtrl: TextEditingController(),
      ),
    );
    expect(find.text('LangSmith 트레이싱 / 모니터링'), findsOneWidget);
    expect(find.text('Workspace ID (LANGSMITH_WORKSPACE_ID)'), findsOneWidget);
  });

  testWidgets('영어 모드에서는 마크다운/학습/LangSmith 섹션에 한국어가 남지 않는다', (tester) async {
    useEnglishLocale();

    await pump(
      tester,
      ConfigMarkdownSection(
        isEditing: true,
        soulCtrl: TextEditingController(),
        skillsCtrl: TextEditingController(),
        troubleCtrl: TextEditingController(),
        limitsCtrl: TextEditingController(),
      ),
    );
    expectNoKoreanText(tester);

    await pump(
      tester,
      ConfigLearningSection(
        isEditing: true,
        enableSkillLearning: true,
        onEnableSkillLearningChanged: (_) {},
        skillLearningSuccessSampleRateCtrl: TextEditingController(),
        skillLearningReflectIntervalSecCtrl: TextEditingController(),
      ),
    );
    expectNoKoreanText(tester);

    await pump(
      tester,
      ConfigLangsmithSection(
        isEditing: true,
        langsmithTracing: true,
        onLangsmithTracingChanged: (_) {},
        langsmithApiKeyCtrl: TextEditingController(),
        langsmithWorkspaceIdCtrl: TextEditingController(),
        langsmithProjectCtrl: TextEditingController(),
        langsmithEndpointCtrl: TextEditingController(),
      ),
    );
    expectNoKoreanText(tester);
  });
}
