// frontend/test/config_llm_section_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/config_llm_section.dart';

void main() {
  Widget buildSection({String provider = 'azure'}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConfigLlmSection(
            isEditing: true,
            llmProvider: provider,
            llmModelCtrl: TextEditingController(),
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
    expect(find.text('2. LLM 및 클라우드 API 자격 증명'), findsOneWidget);
    expect(find.text('LLM 제공자 (Provider)'), findsOneWidget);
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
}
