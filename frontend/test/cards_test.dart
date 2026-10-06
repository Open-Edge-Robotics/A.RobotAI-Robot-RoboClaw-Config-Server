// frontend/test/cards_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/config_model.dart';
import 'package:frontend/models/scenario_model.dart';
import 'package:frontend/widgets/config_card.dart';
import 'package:frontend/widgets/scenario_card.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  testWidgets('설정 카드가 이름을 표시한다', (tester) async {
    await pump(
      tester,
      ConfigListItemCard(
        config: RoboClawConfig(
          id: 1,
          name: 'cfg1',
          robotName: 'butler',
          environment: 'office',
        ),
        isSelected: false,
        onTap: () {},
        onActivate: () {},
        onClone: () {},
        onDelete: () {},
      ),
    );
    expect(find.text('cfg1'), findsOneWidget);
  });

  testWidgets('시나리오 카드가 이름을 표시한다', (tester) async {
    await pump(
      tester,
      ScenarioListItemCard(
        scenario: TestScenario(
          id: 1,
          name: 'sc1',
          robotName: 'butler',
          environment: 'office',
          testCases: [],
        ),
        isSelected: false,
        onTap: () {},
        onActivate: () {},
        onClone: () {},
        onDelete: () {},
      ),
    );
    expect(find.text('sc1'), findsOneWidget);
  });
}
