// frontend/test/config_llm_section_test.dart

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/config_llm_section.dart';

import 'support/localization_audit.dart';

void main() {
  Widget buildSection({
    String provider = 'azure',
    bool toolCalling = true,
    ValueChanged<bool>? onToolCallingChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConfigLlmSection(
            isEditing: true,
            llmProvider: provider,
            llmModelCtrl: TextEditingController(),
            llmToolCalling: toolCalling,
            onLlmToolCallingChanged: onToolCallingChanged ?? (_) {},
            azureEndpointCtrl: TextEditingController(),
            azureApiKeyCtrl: TextEditingController(),
            openaiApiKeyCtrl: TextEditingController(),
            anthropicApiKeyCtrl: TextEditingController(),
            ollamaBaseUrlCtrl: TextEditingController(),
            ollamaNumCtxCtrl: TextEditingController(),
            ollamaTemperatureCtrl: TextEditingController(),
            ollamaRepeatPenaltyCtrl: TextEditingController(),
            ollamaRepeatLastNCtrl: TextEditingController(),
            ollamaSeedCtrl: TextEditingController(),
            ollamaNumPredictCtrl: TextEditingController(),
            ollamaTopKCtrl: TextEditingController(),
            ollamaTopPCtrl: TextEditingController(),
            ollamaMinPCtrl: TextEditingController(),
            ollamaThink: 'unset',
            onOllamaThinkChanged: (_) {},
            onProviderChanged: (_) {},
            onApplyOllamaTemplate: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('LLM 섹션 헤더와 제공자 필드가 표시된다', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSection());
    expect(find.text('LLM 및 클라우드 API 자격 증명'), findsOneWidget);
    expect(find.text('LLM 제공자 (Provider)'), findsOneWidget);
  });

  testWidgets('영어 모드에서 LLM 섹션에 한국어 문구가 남지 않는다', (tester) async {
    // 위젯은 언어 변경 시 스스로 리빌드되지 않으므로 pump 전에 영어로 전환한다.
    useEnglishLocale();
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSection());
    await tester.pumpAndSettle();

    expectNoKoreanText(tester);
  });

  testWidgets('ollama 제공자 선택 시 Ollama 필드가 표시된다', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSection(provider: 'ollama'));
    expect(
      find.text('Ollama Base URL (예: http://localhost:11434)'),
      findsOneWidget,
    );
  });

  testWidgets('스킬 선택 도구 호출 스위치가 상태를 반영하고 변경을 전달한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    bool? changed;
    await tester.pumpWidget(
      buildSection(toolCalling: true, onToolCallingChanged: (v) => changed = v),
    );

    final title = '스킬 선택에 네이티브 도구 호출 사용 (RC_LLM_TOOL_CALLING)';
    expect(find.text(title), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );

    await tester.tap(find.text(title));
    await tester.pump();
    expect(changed, isFalse);
  });
}
