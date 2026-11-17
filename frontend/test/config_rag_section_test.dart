// frontend/test/config_rag_section_test.dart

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/config_rag_section.dart';

import 'support/localization_audit.dart';

void main() {
  Widget buildSection({bool enableRag = true}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConfigRagSection(
            isEditing: true,
            enableRag: enableRag,
            onEnableRagChanged: (_) {},
            embeddingModelCtrl: TextEditingController(),
            embeddingProviderCtrl: TextEditingController(),
            embeddingBaseUrlCtrl: TextEditingController(),
            embeddingApiKeyCtrl: TextEditingController(),
            vectorBackendCtrl: TextEditingController(),
            qdrantUrlCtrl: TextEditingController(),
            qdrantCollCtrl: TextEditingController(),
            qdrantApiKeyCtrl: TextEditingController(),
            qdrantTimeoutSecCtrl: TextEditingController(),
            ragTopKCtrl: TextEditingController(),
            ragScoreThresholdCtrl: TextEditingController(),
            ragLocalMirror: true,
            onRagLocalMirrorChanged: (_) {},
            memoryDirCtrl: TextEditingController(),
          ),
        ),
      ),
    );
  }

  testWidgets('RAG 섹션 헤더가 표시된다', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSection());
    expect(find.text('RAG 및 벡터 DB 설정'), findsOneWidget);
  });

  testWidgets('영어 모드에서 RAG 섹션에 한국어 문구가 남지 않는다', (tester) async {
    // 위젯은 언어 변경 시 스스로 리빌드되지 않으므로 pump 전에 영어로 전환한다.
    useEnglishLocale();
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSection());
    await tester.pumpAndSettle();

    expectNoKoreanText(tester);
  });

  testWidgets('RAG 활성화 시 임베딩 필드가 표시된다', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSection(enableRag: true));
    expect(
      find.text('임베딩 Provider (예: openai, azure, ollama)'),
      findsOneWidget,
    );
  });
}
