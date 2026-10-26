import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/config_cleanup_demo_section.dart';

Widget _host({
  required bool enabled,
  required ValueChanged<bool> onEnabledChanged,
  required TextEditingController controller,
  bool expressionEnabled = false,
  ValueChanged<bool>? onExpressionEnabledChanged,
  bool navigationPoseEnabled = false,
  ValueChanged<bool>? onNavigationPoseEnabledChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ConfigCleanupDemoSection(
        isEditing: true,
        enabled: enabled,
        onEnabledChanged: onEnabledChanged,
        motionIdsJsonCtrl: controller,
        expressionEnabled: expressionEnabled,
        onExpressionEnabledChanged: onExpressionEnabledChanged ?? (_) {},
        navigationPoseEnabled: navigationPoseEnabled,
        onNavigationPoseEnabledChanged:
            onNavigationPoseEnabledChanged ?? (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('CLOi cleanup demo allowlist is editable as JSON', (
    tester,
  ) async {
    final controller = TextEditingController(text: '[22,60]');
    var enabled = true;

    await tester.pumpWidget(
      _host(
        enabled: enabled,
        onEnabledChanged: (value) => enabled = value,
        controller: controller,
      ),
    );

    final field = find.byKey(
      const ValueKey('cloid_cleanup_demo_motion_ids_json'),
    );
    expect(field, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cloid_cleanup_demo_enabled')));
    expect(enabled, isFalse);
    await tester.enterText(field, '[]');
    expect(controller.text, '[]');
    expect(find.textContaining('pre_id'), findsOneWidget);
  });

  testWidgets('CLOi 상황별 표현 모션 스위치를 켜고 끌 수 있다', (tester) async {
    var expressionEnabled = false;

    await tester.pumpWidget(
      _host(
        enabled: true,
        onEnabledChanged: (_) {},
        controller: TextEditingController(text: ''),
        expressionEnabled: expressionEnabled,
        onExpressionEnabledChanged: (value) => expressionEnabled = value,
      ),
    );

    final toggle = find.byKey(const ValueKey('cloid_expression_enabled'));
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    expect(expressionEnabled, isTrue);
  });

  testWidgets('CLOi 섹션 설명에 장비 장애 관련 문구가 남아 있지 않다', (tester) async {
    await tester.pumpWidget(
      _host(
        enabled: true,
        onEnabledChanged: (_) {},
        controller: TextEditingController(text: '[]'),
      ),
    );

    expect(find.textContaining('오류'), findsNothing);
    expect(find.textContaining('2호'), findsNothing);
  });

  testWidgets('CLOi 정리 시연 섹션은 특정 호기를 전제하지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(
        enabled: true,
        onEnabledChanged: (_) {},
        controller: TextEditingController(text: '[]'),
      ),
    );

    expect(find.text('CLOi 정리 시연 설정'), findsOneWidget);
    expect(find.textContaining('1호'), findsNothing);
  });

  testWidgets('CLOi 주행 전 boxing 자세 스위치를 켜고 끌 수 있다', (tester) async {
    var navigationPoseEnabled = false;

    await tester.pumpWidget(
      _host(
        enabled: true,
        onEnabledChanged: (_) {},
        controller: TextEditingController(text: ''),
        navigationPoseEnabled: navigationPoseEnabled,
        onNavigationPoseEnabledChanged: (value) =>
            navigationPoseEnabled = value,
      ),
    );

    final toggle = find.byKey(const ValueKey('cloid_navigation_pose_enabled'));
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    expect(navigationPoseEnabled, isTrue);
  });
}
