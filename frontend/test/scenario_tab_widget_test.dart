// frontend/test/scenario_tab_widget_test.dart
//
// 시나리오 탭 Widget 테스트. HttpAdminApi 를 Fake 로 주입해 목록 렌더링을 검증한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/api/http_admin_api.dart';
import 'package:frontend/screens/scenario_tab.dart';
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
        if (request.method == 'POST' &&
            request.url.path.endsWith('/scenarios')) {
          return http.Response(
            '{"ID":10,"name":"new-sc","robot_name":"butler","environment":"office","test_cases":[]}',
            201,
          );
        }
        if (request.url.path.endsWith('/clone')) {
          return http.Response(
            '{"ID":3,"name":"sc1_copy","robot_name":"butler","environment":"office","test_cases":[]}',
            201,
          );
        }
        if (request.url.path.endsWith('/scenarios')) {
          return http.Response(
            '[{"ID":1,"name":"sc1","robot_name":"butler","environment":"office","test_cases":[]},'
            '{"ID":2,"name":"sc2","robot_name":"former","environment":"factory","test_cases":[]}]',
            200,
          );
        }
        return http.Response('[]', 200);
      }),
      tokenStore: FakeTokenStore(),
    );
  });

  Future<void> pumpScenarioTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ScenarioTab())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('시나리오 목록이 표시된다', (tester) async {
    await pumpScenarioTab(tester);
    expect(find.text('sc1'), findsOneWidget);
    expect(find.text('sc2'), findsOneWidget);
  });

  testWidgets('시나리오를 선택하면 상세 패널이 열린다', (tester) async {
    await pumpScenarioTab(tester);

    await tester.tap(find.text('sc1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('시나리오 상세'), findsOneWidget);
  });

  testWidgets('편집 모드에서 JSON 텍스트 에디터로 전환한다', (tester) async {
    await pumpScenarioTab(tester);

    await tester.tap(find.text('sc1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('편집'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('JSON 텍스트 에디터'));
    await tester.pumpAndSettle();

    final jsonChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'JSON 텍스트 에디터'),
    );
    expect(jsonChip.selected, isTrue);
  });

  testWidgets('신규 시나리오 저장 시 필수 필드 검증이 동작한다', (tester) async {
    await pumpScenarioTab(tester);

    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('필수 입력입니다'), findsWidgets);
  });

  testWidgets('편집 모드에서 GUI 테스트 케이스 에디터가 표시된다', (tester) async {
    await pumpScenarioTab(tester);

    await tester.tap(find.text('sc1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('편집'));
    await tester.pumpAndSettle();

    expect(find.text('정의된 테스트 케이스가 없습니다.'), findsOneWidget);
  });

  testWidgets('시나리오 활성화 시 성공 메시지가 표시된다', (tester) async {
    await pumpScenarioTab(tester);

    await tester.tap(find.text('활성화').first);
    await tester.pumpAndSettle();

    expect(find.text('시나리오가 성공적으로 활성화되었습니다.'), findsOneWidget);
  });

  // 회귀: 다른 로봇/환경 그룹의 항목까지 활성 상태로 덮어써서
  // 활성화 버튼이 전부 사라지던 버그.
  testWidgets('시나리오 활성화 후 다른 로봇/환경 그룹의 활성화 버튼은 유지된다', (tester) async {
    await pumpScenarioTab(tester);

    expect(find.text('활성화'), findsNWidgets(2));

    // sc1 (butler/office) 활성화
    await tester.tap(find.text('활성화').first);
    await tester.pumpAndSettle();

    // sc1 만 Active 가 되고, sc2 (former/factory) 의 활성화 버튼은 남아야 한다.
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('활성화'), findsOneWidget);
  });

  testWidgets('시나리오 삭제 시 확인 다이얼로그가 표시된다', (tester) async {
    await pumpScenarioTab(tester);

    await tester.tap(find.text('삭제').first);
    await tester.pumpAndSettle();

    expect(find.text('정말로 이 테스트 시나리오를 삭제하시겠습니까?'), findsOneWidget);
  });

  testWidgets('시나리오 복제 시 성공 메시지가 표시된다', (tester) async {
    await pumpScenarioTab(tester);

    await tester.tap(find.text('복제').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('시나리오 복제 완료'), findsOneWidget);
  });

  testWidgets('시나리오 검색 필드가 표시된다', (tester) async {
    await pumpScenarioTab(tester);
    expect(find.text('로봇명 검색'), findsOneWidget);
    expect(find.text('환경 검색'), findsOneWidget);
  });

  testWidgets('시나리오 상세 패널에 편집 버튼이 표시된다', (tester) async {
    await pumpScenarioTab(tester);

    await tester.tap(find.text('sc1'));
    await tester.pumpAndSettle();

    expect(find.text('편집'), findsOneWidget);
  });
}
