// frontend/test/tab_loading_lifecycle_test.dart
//
// Config/Scenario 탭의 목록 로딩 렌더링과 위젯 dispose 안전성 테스트.
// - Controller 의 loading 상태가 notifier 를 통해 즉시 렌더링되어야 한다.
// - 탭이 사라진 뒤 늦게 도착한 API 응답이 위젯 오류를 만들면 안 된다.

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/screens/config_tab.dart';
import 'package:frontend/screens/scenario_tab.dart';

import 'support/app_dependencies.dart';

const _cfg1Json =
    '{"ID":1,"name":"cfg1","robot_name":"butler","environment":"office"}';
const _cfg2Json =
    '{"ID":2,"name":"cfg2","robot_name":"former","environment":"factory"}';
const _sc1Json =
    '{"ID":1,"name":"sc1","robot_name":"butler","environment":"office","test_cases":[]}';
const _sc2Json =
    '{"ID":2,"name":"sc2","robot_name":"former","environment":"factory","test_cases":[]}';

void _useWideView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpConfigTab(WidgetTester tester, TestDependencies deps) async {
  _useWideView(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConfigTab(
          api: deps.dependencies.api,
          downloader: deps.dependencies.downloader,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpScenarioTab(
  WidgetTester tester,
  TestDependencies deps,
) async {
  _useWideView(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ScenarioTab(api: deps.dependencies.api)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _disposeTab(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('ConfigTab.refresh 는 응답 전에 즉시 로딩 스피너를 표시한다', (tester) async {
    final refreshGate = Completer<void>();
    var fetchCount = 0;
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/configs')) {
          fetchCount++;
          if (fetchCount > 1) await refreshGate.future;
          return http.Response('[$_cfg1Json,$_cfg2Json]', 200);
        }
        return http.Response('[]', 200);
      },
    );

    await _pumpConfigTab(tester, deps);
    expect(find.text('cfg1'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    tester.state<ConfigTabState>(find.byType(ConfigTab)).refresh();
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
      reason: '재조회를 시작하면 대기 중인 로딩 상태가 즉시 렌더링되어야 한다',
    );

    refreshGate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('cfg1'), findsOneWidget);
  });

  testWidgets('ScenarioTab.refresh 는 응답 전에 즉시 로딩 스피너를 표시한다', (tester) async {
    final refreshGate = Completer<void>();
    var fetchCount = 0;
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/scenarios')) {
          fetchCount++;
          if (fetchCount > 1) await refreshGate.future;
          return http.Response('[$_sc1Json,$_sc2Json]', 200);
        }
        return http.Response('[]', 200);
      },
    );

    await _pumpScenarioTab(tester, deps);
    expect(find.text('sc1'), findsOneWidget);

    tester.state<ScenarioTabState>(find.byType(ScenarioTab)).refresh();
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
      reason: '재조회를 시작하면 대기 중인 로딩 상태가 즉시 렌더링되어야 한다',
    );

    refreshGate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('sc1'), findsOneWidget);
  });

  testWidgets('ConfigTab 이 로딩 중 dispose 되면 늦은 응답에도 위젯 오류가 없다', (tester) async {
    final gate = Completer<void>();
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/configs')) {
          await gate.future;
          return http.Response('[$_cfg1Json]', 200);
        }
        return http.Response('[]', 200);
      },
    );

    _useWideView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigTab(
            api: deps.dependencies.api,
            downloader: deps.dependencies.downloader,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await _disposeTab(tester);
    gate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ConfigTab 이 활성화 요청 중 dispose 되면 늦은 응답에도 위젯 오류가 없다', (
    tester,
  ) async {
    final activateGate = Completer<void>();
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/activate')) {
          await activateGate.future;
          return http.Response('', 200);
        }
        if (request.url.path.endsWith('/configs')) {
          return http.Response('[$_cfg1Json]', 200);
        }
        return http.Response('[]', 200);
      },
    );

    await _pumpConfigTab(tester, deps);
    await tester.tap(find.text('활성화').first);
    await tester.pump();

    await _disposeTab(tester);
    activateGate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ScenarioTab 이 복제 요청 중 dispose 되면 늦은 응답에도 위젯 오류가 없다', (
    tester,
  ) async {
    final cloneGate = Completer<void>();
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/clone')) {
          await cloneGate.future;
          return http.Response(
            '{"ID":3,"name":"sc1_copy","robot_name":"butler",'
            '"environment":"office","test_cases":[]}',
            201,
          );
        }
        if (request.url.path.endsWith('/scenarios')) {
          return http.Response('[$_sc1Json]', 200);
        }
        return http.Response('[]', 200);
      },
    );

    await _pumpScenarioTab(tester, deps);
    await tester.tap(find.text('복제').first);
    await tester.pump();

    await _disposeTab(tester);
    cloneGate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ConfigTab 은 저장 요청 중 저장 버튼을 비활성화한다', (tester) async {
    final saveGate = Completer<void>();
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/configs')) {
          await saveGate.future;
          return http.Response(
            '{"ID":10,"name":"new-cfg","robot_name":"butler",'
            '"environment":"office"}',
            201,
          );
        }
        if (request.url.path.endsWith('/configs')) {
          return http.Response('[$_cfg1Json]', 200);
        }
        return http.Response('[]', 200);
      },
    );

    await _pumpConfigTab(tester, deps);
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'new-cfg');
    await tester.enterText(find.byType(TextFormField).at(1), 'butler');
    await tester.enterText(find.byType(TextFormField).at(2), 'office');

    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pump();

    final saveFinder = find.widgetWithText(ElevatedButton, '저장');
    expect(
      tester.widget<ElevatedButton>(saveFinder).onPressed,
      isNull,
      reason: '저장 요청이 끝날 때까지 중복 제출을 막는다',
    );

    await tester.tap(saveFinder, warnIfMissed: false);
    await tester.pump();
    expect(
      deps.requests.where(
        (r) => r.method == 'POST' && r.url.path.endsWith('/configs'),
      ),
      hasLength(1),
      reason: '비활성 버튼은 API 를 다시 호출하지 않는다',
    );

    saveGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('성공적으로 저장되었습니다.'), findsOneWidget);
  });

  testWidgets('ScenarioTab 은 활성화 요청 중 재호출로 API 를 중복 호출하지 않는다', (tester) async {
    final activateGate = Completer<void>();
    var activateCalls = 0;
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/activate')) {
          activateCalls++;
          await activateGate.future;
          return http.Response('', 200);
        }
        if (request.url.path.endsWith('/scenarios')) {
          return http.Response('[$_sc1Json,$_sc2Json]', 200);
        }
        return http.Response('[]', 200);
      },
    );

    await _pumpScenarioTab(tester, deps);
    await tester.tap(find.text('활성화').first);
    await tester.pump();
    await tester.tap(find.text('활성화').first);
    await tester.pump();

    expect(activateCalls, 1, reason: '변이 중 재호출은 무시된다');

    activateGate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
