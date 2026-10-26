import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/config_system1_section.dart';

void main() {
  Widget buildSection({bool isEditing = true, bool shadow = false}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConfigSystem1Section(
            isEditing: isEditing,
            router: 'rule',
            onRouterChanged: (_) {},
            shadow: shadow,
            onShadowChanged: (_) {},
            shadowLogCtrl: TextEditingController(),
            scope: 'readonly',
            onScopeChanged: (_) {},
            stepRouting: 'shadow',
            onStepRoutingChanged: (_) {},
            endpointCtrl: TextEditingController(),
            providerCtrl: TextEditingController(text: 'laya'),
            timeoutMsCtrl: TextEditingController(text: '300'),
            confThresholdsJsonCtrl: TextEditingController(text: '{}'),
            skillsCtrl: TextEditingController(),
            maxOptionsCtrl: TextEditingController(text: '12'),
            apiKeyCtrl: TextEditingController(),
          ),
        ),
      ),
    );
  }

  // SYSTEM1_ROUTER 만 필수이고 나머지는 선택 + 기본값을 함께 표시한다.
  const routerLabel = 'System 1 router (SYSTEM1_ROUTER) *';
  const optionalLabels = [
    'Shadow mode (SYSTEM1_SHADOW, 선택, 기본: false)',
    'Shadow log path (SYSTEM1_SHADOW_LOG, 선택, 기본: 없음)',
    'System 1 scope (SYSTEM1_SCOPE, 선택, 기본: readonly)',
    'Step routing (SYSTEM1_STEP_ROUTING, 선택, 기본: shadow)',
    'System 1 endpoint (SYSTEM1_ENDPOINT, 선택, 기본: 없음)',
    'System 1 provider (SYSTEM1_PROVIDER, 선택, 기본: laya)',
    'Timeout ms (SYSTEM1_TIMEOUT_MS, 선택, 기본: 300)',
    'Confidence thresholds JSON (SYSTEM1_CONF_THRESHOLDS_JSON, 선택, 기본: intent별 기본 임계치)',
    'Candidate skills (SYSTEM1_SKILLS, 선택, 기본: 자동 선택)',
    'Max options (SYSTEM1_MAX_OPTIONS, 선택, 기본: 12)',
    'System 1 API Key (SYSTEM1_API_KEY, 선택, 기본: 없음)',
  ];

  testWidgets('System 1 section exposes all contract environment settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSection());
    await tester.pumpAndSettle();

    expect(find.text('System 1 Fast Router'), findsOneWidget);
    expect(find.text(routerLabel), findsOneWidget, reason: routerLabel);
    for (final label in optionalLabels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('SYSTEM1_ROUTER 라벨만 필수이고 나머지는 선택/기본값을 표시한다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSection());
    await tester.pumpAndSettle();

    // 필수 라우터 라벨에는 * 표시가 있고 선택/기본값 표시는 없다.
    final router = tester.widget<Text>(find.text(routerLabel));
    expect(router.data, endsWith('*'));
    expect(router.data, isNot(contains('선택')));
    expect(router.data, isNot(contains('기본')));

    // 나머지 필드 라벨은 선택과 기본값을 함께 표시한다.
    for (final label in optionalLabels) {
      final field = tester.widget<Text>(find.text(label));
      expect(field.data, contains('선택'), reason: label);
      expect(field.data, contains('기본'), reason: label);
      expect(field.data, isNot(endsWith('*')), reason: label);
    }
  });

  testWidgets('System 1 inputs are disabled when the profile is read-only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSection(isEditing: false));
    await tester.pumpAndSettle();

    final endpoint = tester.widget<TextFormField>(
      find.widgetWithText(
        TextFormField,
        'System 1 endpoint (SYSTEM1_ENDPOINT, 선택, 기본: 없음)',
      ),
    );
    expect(endpoint.enabled, isFalse);
    final apiKeyFinder = find.widgetWithText(
      TextFormField,
      'System 1 API Key (SYSTEM1_API_KEY, 선택, 기본: 없음)',
    );
    final apiKey = tester.widget<TextFormField>(apiKeyFinder);
    expect(apiKey.enabled, isFalse);
    final editableText = tester.widget<EditableText>(
      find.descendant(of: apiKeyFinder, matching: find.byType(EditableText)),
    );
    expect(editableText.obscureText, isTrue);
  });

  testWidgets('SYSTEM1_SHADOW_LOG 는 Shadow mode 가 꺼져 있으면 비활성화된다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSection(shadow: false));
    await tester.pumpAndSettle();

    final shadowLog = tester.widget<TextFormField>(
      find.widgetWithText(
        TextFormField,
        'Shadow log path (SYSTEM1_SHADOW_LOG, 선택, 기본: 없음)',
      ),
    );
    expect(shadowLog.enabled, isFalse);
  });

  testWidgets('SYSTEM1_SHADOW_LOG 는 파일 경로만 허용한다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSection(shadow: true));
    await tester.pumpAndSettle();

    final shadowLog = tester.widget<TextFormField>(
      find.widgetWithText(
        TextFormField,
        'Shadow log path (SYSTEM1_SHADOW_LOG, 선택, 기본: 없음)',
      ),
    );
    expect(shadowLog.validator, isNotNull);
    // 켜기/끄기 값은 파일 경로가 아니므로 거부한다.
    expect(shadowLog.validator!('true'), isNotNull);
    expect(shadowLog.validator!('on'), isNotNull);
    // 상대 경로도 거부하고, 절대 경로와 빈 값은 허용한다.
    expect(shadowLog.validator!('system1_shadow.jsonl'), isNotNull);
    expect(
      shadowLog.validator!('/ws/agent_workspace/system1_shadow.jsonl'),
      isNull,
    );
    expect(shadowLog.validator!(''), isNull);
  });

  testWidgets('SYSTEM1_STEP_ROUTING 은 off/shadow/on 드롭다운이다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSection());
    await tester.pumpAndSettle();

    expect(
      find.text('Step routing (SYSTEM1_STEP_ROUTING, 선택, 기본: shadow)'),
      findsOneWidget,
    );

    // DropdownButtonFormField 는 내부 DropdownButton 의 value 로 식별한다.
    final dropdowns = tester
        .widgetList<DropdownButton<String>>(find.byType(DropdownButton<String>))
        .toList();
    final stepRouting = dropdowns.firstWhere(
      (dropdown) => dropdown.value == 'shadow',
    );
    expect(stepRouting.items!.map((item) => item.value).toList(), [
      'off',
      'shadow',
      'on',
    ]);
  });
}
