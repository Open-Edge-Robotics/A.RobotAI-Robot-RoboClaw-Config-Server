// frontend/test/config_rag_section_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/config_rag_section.dart';

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
    expect(find.text('3. RAG 및 벡터 DB 설정'), findsOneWidget);
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
