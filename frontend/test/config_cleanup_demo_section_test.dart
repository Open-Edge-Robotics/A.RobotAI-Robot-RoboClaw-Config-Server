import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/config_cleanup_demo_section.dart';

void main() {
  testWidgets('CLOi cleanup demo allowlist is editable as JSON', (
    tester,
  ) async {
    final controller = TextEditingController(text: '[22,60]');
    var enabled = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigCleanupDemoSection(
            isEditing: true,
            enabled: enabled,
            onEnabledChanged: (value) => enabled = value,
            motionIdsJsonCtrl: controller,
          ),
        ),
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
}
