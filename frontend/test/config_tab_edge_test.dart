// frontend/test/config_tab_edge_test.dart
//
// 설정 탭의 미탐지 엣지 케이스. config_tab_widget_test.dart 가 다루지 않는
// "빈/실패/취소/인증" 경로만 확인한다:
// - 빈 목록과 검색 무결과 안내
// - 목록 조회 실패(비401) 시 기존 목록 유지
// - 변이(활성화/삭제/저장) 401 → onUnauthorized 1회 호출
// - 삭제 확인 취소/삭제 실패/저장 실패

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/screens/config_tab.dart';

import 'support/app_dependencies.dart';

const _cfg1Json =
    '{"ID":1,"name":"cfg1","robot_name":"butler","environment":"office"}';

void main() {
  Future<void> pumpConfigTab(
    WidgetTester tester,
    TestDependencies deps, {
    VoidCallback? onUnauthorized,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigTab(
            api: deps.dependencies.api,
            downloader: deps.dependencies.downloader,
            onUnauthorized: onUnauthorized,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('목록이 비어 있으면 등록된 설정이 없습니다 안내가 표시된다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async => http.Response('[]', 200),
    );

    await pumpConfigTab(tester, deps);

    expect(find.text('등록된 설정이 없습니다.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('검색 결과가 없으면 안내로 바뀌고 필터 쿼리가 전달된다', (tester) async {
    var filtered = false;
    final deps = buildTestDependencies(
      respond: (request) async {
        final query = request.url.queryParameters;
        if (query.containsKey('robot_name') ||
            query.containsKey('environment')) {
          filtered = true;
          return http.Response('[]', 200);
        }
        return http.Response('[$_cfg1Json]', 200);
      },
    );

    await pumpConfigTab(tester, deps);
    expect(find.text('cfg1'), findsOneWidget);

    // 좌측 패널의 첫 검색 필드는 로봇명 필터다.
    await tester.enterText(find.byType(TextField).at(0), 'former');
    await tester.pumpAndSettle();

    expect(filtered, isTrue, reason: '검색어는 서버 필터 쿼리로 전달되어야 한다');
    expect(deps.requests.last.url.queryParameters['robot_name'], 'former');
    expect(find.text('cfg1'), findsNothing);
    expect(find.text('등록된 설정이 없습니다.'), findsOneWidget);
  });

  testWidgets('목록 조회가 500 이면 서버 오류 스낵바를 띄우고 기존 목록은 유지한다', (tester) async {
    var failing = false;
    final deps = buildTestDependencies(
      respond: (request) async {
        if (failing) return http.Response('{"error":"boom"}', 500);
        return http.Response('[$_cfg1Json]', 200);
      },
    );

    await pumpConfigTab(tester, deps);
    expect(find.text('cfg1'), findsOneWidget);

    failing = true;
    tester.state<ConfigTabState>(find.byType(ConfigTab)).refresh();
    await tester.pumpAndSettle();

    expect(find.text('서버 오류: 설정 목록 조회 실패'), findsOneWidget);
    expect(
      find.text('cfg1'),
      findsOneWidget,
      reason: '실패한 재조회는 기존 목록을 비우지 않는다',
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
        return http.Response('[$_cfg1Json]', 200);
      },
    );
    var unauthorizedCalls = 0;

    await pumpConfigTab(
      tester,
      deps,
      onUnauthorized: () => unauthorizedCalls++,
    );

    await tester.tap(find.text('활성화').first);
    await tester.pumpAndSettle();

    expect(unauthorizedCalls, 1, reason: '토큰 재입력 경로로 정확히 한 번 넘긴다');
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
        return http.Response('[$_cfg1Json]', 200);
      },
    );
    var unauthorizedCalls = 0;

    await pumpConfigTab(
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
    expect(find.text('cfg1'), findsOneWidget, reason: '실패한 삭제는 항목을 남긴다');
  });

  testWidgets('삭제 확인 다이얼로그에서 취소하면 API 를 호출하지 않고 항목이 유지된다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async => http.Response('[$_cfg1Json]', 200),
    );

    await pumpConfigTab(tester, deps);

    await tester.tap(find.text('삭제').first);
    await tester.pumpAndSettle();
    expect(find.text('정말로 이 설정을 삭제하시겠습니까?'), findsOneWidget);

    await tester.tap(find.text('취소').last);
    await tester.pumpAndSettle();

    expect(
      deps.requests.where((request) => request.method == 'DELETE'),
      isEmpty,
      reason: '취소는 삭제 API 를 호출하지 않는다',
    );
    expect(find.text('cfg1'), findsOneWidget);
  });

  testWidgets('삭제가 실패하면 삭제 실패 메시지를 띄우고 항목을 유지한다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.method == 'DELETE') {
          return http.Response('{"error":"boom"}', 500);
        }
        return http.Response('[$_cfg1Json]', 200);
      },
    );

    await pumpConfigTab(tester, deps);

    await tester.tap(find.text('삭제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(find.text('삭제 실패: 설정 삭제 실패'), findsOneWidget);
    expect(find.text('cfg1'), findsOneWidget);
  });

  testWidgets('저장이 실패하면 오류 메시지를 띄우고 편집 모드를 유지한다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.method == 'PUT') {
          return http.Response('{"error":"boom"}', 500);
        }
        return http.Response('[$_cfg1Json]', 200);
      },
    );

    await pumpConfigTab(tester, deps);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('편집'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.textContaining('저장 실패: 설정 저장 실패'), findsOneWidget);
    expect(
      deps.requests.where((request) => request.method == 'PUT'),
      isNotEmpty,
      reason: '편집 저장은 PUT 으로 전송된다',
    );
    expect(
      find.widgetWithText(ElevatedButton, '저장'),
      findsOneWidget,
      reason: '저장 실패 후에도 편집 모드를 유지한다',
    );
    expect(find.text('편집'), findsNothing);
  });
}
