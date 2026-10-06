// frontend/test/list_panels_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/config_model.dart';
import 'package:frontend/models/scenario_model.dart';
import 'package:frontend/widgets/config_list_panel.dart';
import 'package:frontend/widgets/scenario_list_panel.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  testWidgets('설정 목록 패널이 항목을 표시한다', (tester) async {
    await pump(
      tester,
      ConfigListPanel(
        configs: [
          RoboClawConfig(
            id: 1,
            name: 'cfg1',
            robotName: 'butler',
            environment: 'office',
          ),
        ],
        isLoading: false,
        selectedConfig: null,
        onConfigSelected: (_) {},
        onConfigActivated: (_) {},
        onConfigCloned: (_) {},
        onConfigDeleted: (_) {},
        onSearchRobotChanged: (_) {},
        onSearchEnvChanged: (_) {},
        onAddPressed: () {},
      ),
    );
    expect(find.text('cfg1'), findsOneWidget);
  });

  testWidgets('시나리오 목록 패널이 항목을 표시한다', (tester) async {
    await pump(
      tester,
      ScenarioListPanel(
        scenarios: [
          TestScenario(
            id: 1,
            name: 'sc1',
            robotName: 'butler',
            environment: 'office',
            testCases: [],
          ),
        ],
        isLoadingScenarios: false,
        selectedScenario: null,
        onScenarioSelected: (_) {},
        onScenarioActivated: (_) {},
        onScenarioCloned: (_) {},
        onScenarioDeleted: (_) {},
        onSearchRobotChanged: (_) {},
        onSearchEnvChanged: (_) {},
        onAddPressed: () {},
      ),
    );
    expect(find.text('sc1'), findsOneWidget);
  });
}
