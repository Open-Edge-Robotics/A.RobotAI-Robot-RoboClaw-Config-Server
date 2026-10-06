// frontend/test/scenario_detail_panel_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/scenario_model.dart';
import 'package:frontend/widgets/scenario_detail_panel.dart';

void main() {
  Widget buildPanel({bool isJsonMode = false}) {
    return MaterialApp(
      home: ScenarioDetailPanel(
        formKey: GlobalKey<FormState>(),
        nameController: TextEditingController(text: 'sc1'),
        robotController: TextEditingController(text: 'butler'),
        environmentController: TextEditingController(text: 'office'),
        descriptionController: TextEditingController(),
        scenarioCasesController: TextEditingController(),
        editingTestCases: [],
        selectedScenario: TestScenario(
          id: 1,
          name: 'sc1',
          robotName: 'butler',
          environment: 'office',
          testCases: [],
        ),
        isEditing: true,
        isCreatingNewScenario: false,
        isJsonMode: isJsonMode,
        onBack: () {},
        onStartEditing: () {},
        onSave: () {},
        onCancel: () {},
        onSelectGuiEditor: () {},
        onSelectJsonEditor: () {},
        onTestCasesChanged: (_) {},
        onAddTemplate: (_) {},
      ),
    );
  }

  testWidgets('시나리오 상세 패널이 표시된다', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildPanel());
    expect(find.text('1. 시나리오 정보'), findsOneWidget);
    expect(find.text('sc1'), findsWidgets);
  });

  testWidgets('JSON 모드에서 JSON 에디터가 표시된다', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildPanel(isJsonMode: true));
    expect(find.text('JSON 텍스트 에디터'), findsOneWidget);
  });
}
