// frontend/test/scenario_tab_edge_test.dart
//
// 시나리오 탭의 미탐지 엣지 케이스. scenario_tab_widget_test.dart 가 다루지 않는
// "빈/검증/취소/인증" 경로만 확인한다:
// - 빈 목록 안내
// - 테스트 케이스 없음(GUI) / 잘못된 JSON(JSON 모드) 저장 거부
// - 변이(활성화/삭제/저장) 401 → onUnauthorized 1회 호출
// - 삭제 확인 취소

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/screens/scenario_tab.dart';

import 'support/app_dependencies.dart';

const _sc1Json =
    '{"ID":1,"name":"sc1","robot_name":"butler","environment":"office","test_cases":[]}';

void main() {
  Future<void> pumpScenarioTab(
    WidgetTester tester,
    TestDependencies deps, {
    VoidCallback? onUnauthorized,
  }) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScenarioTab(
            api: deps.dependencies.api,
            onUnauthorized: onUnauthorized,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectFirstScenarioAndEdit(WidgetTester tester) async {
    await tester.tap(find.text('sc1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('편집'));
    await tester.pumpAndSettle();
  }

  testWidgets('목록이 비어 있으면 등록된 시나리오가 없습니다 안내가 표시된다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async => http.Response('[]', 200),
    );

    await pumpScenarioTab(tester, deps);

    expect(find.text('등록된 시나리오가 없습니다.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('GUI 편집 모드에서 테스트 케이스가 없으면 저장이 거부된다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async => http.Response('[$_sc1Json]', 200),
    );

    await pumpScenarioTab(tester, deps);
    await selectFirstScenarioAndEdit(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('최소 하나 이상의 테스트 케이스가 필요합니다.'), findsOneWidget);
    expect(
      deps.requests.where((request) => request.method == 'PUT'),
      isEmpty,
      reason: '테스트 케이스가 없으면 저장 API 를 호출하지 않는다',
    );
  });

  // 관측된 현재 동작: JSON 에디터 필드의 validator 가 먼저 파싱을 시도하므로
  // 인라인 'JSON 파싱 에러: ...' 가 표시되고 저장 API 는 호출되지 않는다.
  // (탭의 Test Cases JSON 형식 오류 스낵바는 이 경로에서 도달하지 않는다.)
  testWidgets('JSON 모드에 잘못된 JSON 을 넣고 저장하면 인라인 파싱 오류를 알리고 API 를 호출하지 않는다', (
    tester,
  ) async {
    final deps = buildTestDependencies(
      respond: (request) async => http.Response('[$_sc1Json]', 200),
    );

    await pumpScenarioTab(tester, deps);
    await selectFirstScenarioAndEdit(tester);
    await tester.tap(find.text('JSON 텍스트 에디터'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, '{"not":"a list"');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.textContaining('JSON 파싱 에러'), findsOneWidget);
    expect(find.textContaining('Test Cases JSON 형식이 올바르지 않습니다'), findsNothing);
    expect(
      deps.requests.where((request) => request.method == 'PUT'),
      isEmpty,
      reason: '파싱 실패 시 저장 API 를 호출하지 않는다',
    );
  });

  testWidgets('활성화가 401 이면 인증 오류를 알리고 onUnauthorized 를 한 번 호출한다', (
    tester,
  ) async {
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/activate')) {
          return http.Response('{"error":"unauthorized"}', 401);
        }
        return http.Response('[$_sc1Json]', 200);
      },
    );
    var unauthorizedCalls = 0;

    await pumpScenarioTab(
      tester,
      deps,
      onUnauthorized: () => unauthorizedCalls++,
    );

    await tester.tap(find.text('활성화').first);
    await tester.pumpAndSettle();

    expect(unauthorizedCalls, 1);
    expect(find.text('인증 오류: 올바르지 않거나 만료된 관리자 토큰입니다.'), findsOneWidget);
    expect(find.textContaining('활성화 실패'), findsNothing);
  });

  testWidgets('삭제가 401 이면 인증 오류를 알리고 onUnauthorized 를 한 번 호출한다', (
    tester,
  ) async {
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.method == 'DELETE') {
          return http.Response('{"error":"unauthorized"}', 401);
        }
        return http.Response('[$_sc1Json]', 200);
      },
    );
    var unauthorizedCalls = 0;

    await pumpScenarioTab(
      tester,
      deps,
      onUnauthorized: () => unauthorizedCalls++,
    );

    await tester.tap(find.text('삭제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(unauthorizedCalls, 1);
    expect(find.text('인증 오류: 올바르지 않거나 만료된 관리자 토큰입니다.'), findsOneWidget);
    expect(find.text('sc1'), findsOneWidget, reason: '실패한 삭제는 항목을 남긴다');
  });

  testWidgets('삭제 확인 다이얼로그에서 취소하면 API 를 호출하지 않고 항목이 유지된다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async => http.Response('[$_sc1Json]', 200),
    );

    await pumpScenarioTab(tester, deps);

    await tester.tap(find.text('삭제').first);
    await tester.pumpAndSettle();
    expect(find.text('정말로 이 테스트 시나리오를 삭제하시겠습니까?'), findsOneWidget);

    await tester.tap(find.text('취소').last);
    await tester.pumpAndSettle();

    expect(
      deps.requests.where((request) => request.method == 'DELETE'),
      isEmpty,
      reason: '취소는 삭제 API 를 호출하지 않는다',
    );
    expect(find.text('sc1'), findsOneWidget);
  });

  testWidgets('저장이 401 이면 인증 오류를 알리고 onUnauthorized 를 한 번 호출한다', (
    tester,
  ) async {
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.method == 'PUT') {
          return http.Response('{"error":"unauthorized"}', 401);
        }
        return http.Response('[$_sc1Json]', 200);
      },
    );
    var unauthorizedCalls = 0;

    await pumpScenarioTab(
      tester,
      deps,
      onUnauthorized: () => unauthorizedCalls++,
    );
    await selectFirstScenarioAndEdit(tester);
    await tester.tap(find.text('JSON 텍스트 에디터'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).last,
      '[{"id":"tc1","name":"ping","type":"ping"}]',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(
      deps.requests.where((request) => request.method == 'PUT'),
      isNotEmpty,
      reason: '유효한 테스트 케이스는 저장 API 로 전송된다',
    );
    expect(unauthorizedCalls, 1);
    expect(find.text('인증 오류: 올바르지 않거나 만료된 관리자 토큰입니다.'), findsOneWidget);
  });
}
