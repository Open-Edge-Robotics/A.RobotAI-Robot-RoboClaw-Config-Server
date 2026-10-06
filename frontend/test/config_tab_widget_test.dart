// frontend/test/config_tab_widget_test.dart
//
// 설정 탭 Widget 테스트. HttpAdminApi 를 Fake 로 주입해 목록 렌더링을 검증한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/api/http_admin_api.dart';
import 'package:frontend/screens/config_tab.dart';
import 'package:frontend/storage/token_store.dart';

class FakeTokenStore implements TokenStore {
  String? value;
  @override
  String? read() => value;
  @override
  void write(String token) => value = token;
  @override
  void clear() => value = null;
}

void main() {
  setUp(() {
    HttpAdminApi.instance = HttpAdminApi(
      client: MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/configs')) {
          return http.Response(
            '{"ID":10,"name":"new-cfg","robot_name":"butler","environment":"office"}',
            201,
          );
        }
        if (request.url.path.endsWith('/clone')) {
          return http.Response(
            '{"ID":3,"name":"cfg1_copy","robot_name":"butler","environment":"office"}',
            201,
          );
        }
        if (request.url.path.endsWith('/configs')) {
          return http.Response(
            '[{"ID":1,"name":"cfg1","robot_name":"butler","environment":"office"},'
            '{"ID":2,"name":"cfg2","robot_name":"former","environment":"factory"}]',
            200,
          );
        }
        return http.Response('[]', 200);
      }),
      tokenStore: FakeTokenStore(),
    );
  });

  Future<void> pumpConfigTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ConfigTab())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('설정 목록이 표시된다', (tester) async {
    await pumpConfigTab(tester);
    expect(find.text('cfg1'), findsOneWidget);
    expect(find.text('cfg2'), findsOneWidget);
  });

  testWidgets('설정을 선택하면 상세 패널이 열린다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('설정 상세'), findsOneWidget);
  });

  testWidgets('신규 설정 저장 시 필수 필드 검증이 동작한다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('필수 입력입니다'), findsWidgets);
  });

  testWidgets('설정 상세 패널에 폼 섹션이 표시된다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();

    expect(find.text('1. 기본 정보'), findsOneWidget);
    expect(find.text('2. LLM 및 클라우드 API 자격 증명'), findsOneWidget);
  });

  testWidgets('설정 삭제 시 확인 다이얼로그가 표시된다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').first);
    await tester.pumpAndSettle();

    expect(find.text('정말로 이 설정을 삭제하시겠습니까?'), findsOneWidget);
  });

  testWidgets('설정 활성화 시 성공 메시지가 표시된다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('활성화').first);
    await tester.pumpAndSettle();

    expect(find.text('설정이 성공적으로 활성화되었습니다.'), findsOneWidget);
  });

  // 회귀: 다른 로봇/환경 그룹의 항목까지 활성 상태로 덮어써서
  // 활성화 버튼이 전부 사라지던 버그.
  testWidgets('설정 활성화 후 다른 로봇/환경 그룹의 활성화 버튼은 유지된다', (tester) async {
    await pumpConfigTab(tester);

    expect(find.text('활성화'), findsNWidgets(2));

    // cfg1 (butler/office) 활성화
    await tester.tap(find.text('활성화').first);
    await tester.pumpAndSettle();

    // cfg1 만 Active 가 되고, cfg2 (former/factory) 의 활성화 버튼은 남아야 한다.
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('활성화'), findsOneWidget);
  });

  testWidgets('설정 복제 시 성공 메시지가 표시된다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('복제').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('설정이 복제되었습니다'), findsOneWidget);
  });

  testWidgets('신규 설정 저장 시 성공 메시지가 표시된다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'new-cfg');
    await tester.enterText(find.byType(TextFormField).at(1), 'butler');
    await tester.enterText(find.byType(TextFormField).at(2), 'office');
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('성공적으로 저장되었습니다.'), findsOneWidget);
  });

  testWidgets('설정 상세 패널의 마크다운 섹션으로 스크롤한다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('9. 에이전트 마크다운 & 한계 스펙 정의'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('9. 에이전트 마크다운 & 한계 스펙 정의'), findsOneWidget);
  });

  testWidgets('설정 상세에서 System 1 Fast Router 설정을 편집할 수 있다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('System 1 Fast Router'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('System 1 Fast Router'), findsOneWidget);
    expect(find.textContaining('SYSTEM1_ROUTER'), findsOneWidget);
    expect(find.textContaining('SYSTEM1_API_KEY'), findsOneWidget);
  });

  testWidgets('설정 검색 필드가 표시된다', (tester) async {
    await pumpConfigTab(tester);
    expect(find.text('로봇명 검색'), findsOneWidget);
    expect(find.text('환경 검색'), findsOneWidget);
  });

  testWidgets('설정 상세 패널에 편집 버튼이 표시된다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();

    expect(find.text('편집'), findsOneWidget);
  });

  testWidgets('설정 상세 패널의 MCP 섹션으로 스크롤한다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('10. MCP(Model Context Protocol) 서버 연동'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('10. MCP(Model Context Protocol) 서버 연동'), findsOneWidget);
  });

  testWidgets('설정 상세 패널의 HTTP 보안 섹션으로 스크롤한다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('5. HTTP API 보안 설정'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('5. HTTP API 보안 설정'), findsOneWidget);
  });

  testWidgets('설정 상세 패널의 Dashboard 웹 노드 섹션으로 스크롤한다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Dashboard 웹 노드 설정'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Dashboard 웹 노드 설정'), findsOneWidget);
  });

  testWidgets('설정 상세 패널의 RAG 섹션으로 스크롤한다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('3. RAG 및 벡터 DB 설정'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('3. RAG 및 벡터 DB 설정'), findsOneWidget);
  });

  testWidgets('설정 상세 패널의 태스크 큐 섹션으로 스크롤한다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('11. 태스크 큐 / 복합 명령 자동 분해 설정'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('11. 태스크 큐 / 복합 명령 자동 분해 설정'), findsOneWidget);
  });

  testWidgets('설정 상세 패널의 카메라 섹션으로 스크롤한다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('7. 카메라 / 비전 / 센서 설정'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('7. 카메라 / 비전 / 센서 설정'), findsOneWidget);
  });
}
