// frontend/test/config_tab_widget_test.dart
//
// 설정 탭 Widget 테스트. HttpAdminApi 를 Fake 로 주입해 목록 렌더링을 검증한다.

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/features/configs/config_form_mapper.dart';
import 'package:frontend/models/config_model.dart';
import 'package:frontend/screens/config_tab.dart';

import 'support/app_dependencies.dart';
import 'support/localization_audit.dart';

void main() {
  late TestDependencies deps;

  setUp(() {
    deps = buildTestDependencies(
      respond: (request) async {
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
      },
    );
  });

  Future<void> pumpConfigTab(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

    expect(find.text('프로필 기본 정보'), findsOneWidget);
    expect(find.text('LLM 및 클라우드 API 자격 증명'), findsOneWidget);
  });

  testWidgets('설정 폼이 환경별 그룹으로 나뉘고 그룹 바로가기로 이동한다', (tester) async {
    await pumpConfigTab(tester);
    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();

    expect(find.text('AI 모델·지식'), findsOneWidget);
    expect(find.text('로봇 기능·센서'), findsOneWidget);
    expect(find.text('외부 연동'), findsOneWidget);
    expect(find.text('서버·보안·관측'), findsOneWidget);

    await tester.tap(find.text('5. 외부 연동'));
    await tester.pumpAndSettle();

    final groupTop = tester.getTopLeft(find.text('외부 연동')).dy;
    expect(groupTop, lessThan(800));
  });

  testWidgets('좁은 화면에서 설정 필드가 가로로 넘치지 않는다', (tester) async {
    await pumpConfigTab(tester, size: const Size(390, 844));
    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
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
      find.text('에이전트 문서 및 한계 설정'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('에이전트 문서 및 한계 설정'), findsOneWidget);
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
      find.text('MCP 서버 연동'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('MCP 서버 연동'), findsOneWidget);
  });

  testWidgets('설정 상세 패널의 HTTP 보안 섹션으로 스크롤한다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('HTTP API 보안 설정'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('HTTP API 보안 설정'), findsOneWidget);
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
      find.text('RAG 및 벡터 DB 설정'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('RAG 및 벡터 DB 설정'), findsOneWidget);
  });

  testWidgets('설정 상세 패널의 태스크 큐 섹션으로 스크롤한다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('태스크 큐·명령 자동 분해'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('태스크 큐·명령 자동 분해'), findsOneWidget);
  });

  testWidgets('설정 상세 패널의 카메라 섹션으로 스크롤한다', (tester) async {
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('카메라·비전·센서'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('카메라·비전·센서'), findsOneWidget);
  });

  // characterization: 프로필을 선택해 아무것도 수정하지 않고 저장해도
  // 순수 매핑과 동일한 payload 가 전송되어야 한다. 문서화된 정규화
  // (agent_id trim, System1 기본값, Ollama known 옵션 재직렬화) 외에는
  // 어떤 필드도 기본값으로 덮이지 않는다.
  testWidgets('설정을 선택해 편집 없이 저장해도 payload 가 보존된다', (tester) async {
    final originalJson = _sentinelConfigJson();
    deps = buildTestDependencies(
      respond: (request) async {
        if (request.method == 'PUT') {
          return http.Response(jsonEncode(originalJson), 200);
        }
        return http.Response(jsonEncode([originalJson]), 200);
      },
    );
    await pumpConfigTab(tester);

    await tester.tap(find.text('roundtrip-cfg'));
    await tester.pumpAndSettle();

    // 키 오타/오배선이면 이 표본 값이 렌더링되지 않는다.
    expect(find.text('sentinel_skills_guide_file'), findsOneWidget);
    expect(find.text('sentinel_http_control_token'), findsOneWidget);
    expect(find.text('sentinel_system1_api_key'), findsOneWidget);

    await tester.tap(find.text('편집'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pumpAndSettle();

    final put = deps.requests.lastWhere((request) => request.method == 'PUT');
    final original = RoboClawConfig.fromJson(originalJson);
    final expected = ConfigFormMapper.toConfig(
      ConfigFormMapper.fromConfig(original),
      id: original.id,
      isActive: original.isActive,
    );
    expect(jsonDecode(put.body), expected.toJson());
  });

  // 유효한 설정을 렌더링하면 17개 섹션이 모두 만들어져야 한다.
  // 섹션/필드 키 오타는 ConfigFormFields 접근자에서 ArgumentError 로 드러난다.
  testWidgets('유효한 설정에서 17개 섹션이 모두 렌더링된다', (tester) async {
    final originalJson = _sentinelConfigJson();
    deps = buildTestDependencies(
      respond: (request) async {
        return http.Response(jsonEncode([originalJson]), 200);
      },
    );
    await pumpConfigTab(tester);

    await tester.tap(find.text('roundtrip-cfg'));
    await tester.pumpAndSettle();

    for (final title in _sectionTitles) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
  });

  testWidgets('영어 모드에서는 설정 상세 폼과 내보내기 메뉴에 한국어가 남지 않는다', (tester) async {
    useEnglishLocale();
    await pumpConfigTab(tester);

    await tester.tap(find.text('cfg1'));
    await tester.pumpAndSettle();
    expectNoKoreanText(tester);

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();
    expect(find.text('Download All (ZIP)'), findsOneWidget);
    expectNoKoreanText(tester);
  });
}

const _sectionTitles = [
  '프로필 기본 정보',
  'LLM 및 클라우드 API 자격 증명',
  'RAG 및 벡터 DB 설정',
  '메신저 및 통신 데몬',
  'CLOi 정리 시연 설정',
  'HTTP API 보안 설정',
  'Dashboard 웹 노드 설정',
  '로컬 경로 및 리소스',
  '카메라·비전·센서',
  '스킬 자가학습',
  '에이전트 문서 및 한계 설정',
  'MCP 서버 연동',
  '태스크 큐·명령 자동 분해',
  'LangSmith 트레이싱 / 모니터링',
  'Langfuse 트레이싱 / 모니터링',
  'System 1 Fast Router',
  'Maestro FleetControl 연동',
];

/// 모든 모델 필드에 서로 다른 sentinel 값을 채우고, contract 제약(enum/min/max,
/// JSON 문자열)을 만족하도록 조정한 설정 JSON.
Map<String, dynamic> _sentinelConfigJson() {
  final defaults = RoboClawConfig(
    name: '',
    robotName: '',
    environment: '',
  ).toJson();
  final json = <String, dynamic>{};
  for (final entry in defaults.entries) {
    if (entry.key == 'is_active' || entry.key == 'ollama_options_json') {
      continue;
    }
    json[entry.key] = switch (entry.value) {
      bool value => !value,
      int _ => 7,
      double _ => 0.25,
      String _ => 'sentinel_${entry.key}',
      final other => other,
    };
  }
  json['ID'] = 7;
  json['name'] = 'roundtrip-cfg';
  json['robot_name'] = 'butler';
  json['environment'] = 'office';
  json['is_active'] = true;
  json['agent_id'] = '  Former0047  ';
  json['system1_shadow_log'] = '/tmp/sentinel-shadow.jsonl';
  json['ros_domain_id'] = 12;
  json['http_port'] = 18080;
  json['grpc_port'] = 15052;
  json['grpc_target_port'] = 15051;
  json['dashboard_port'] = 19090;
  json['robot_port'] = 15053;
  json['system1_timeout_ms'] = 250.0;
  json['system1_max_options'] = 5;
  json['llm_provider'] = 'ollama';
  json['rag_vector_backend'] = 'qdrant';
  json['system1_router'] = 'laya';
  json['system1_step_routing'] = 'off';
  json['system1_scope'] = 'navigation';
  json['maestro_disconnect_policy'] = 'stop';
  json['http_allowed_cidrs_json'] = '["10.0.0.0/8"]';
  json['mcp_servers_json'] = '[]';
  json['system1_conf_thresholds_json'] = '{"skill":0.8}';
  json['ollama_options_json'] =
      '{"num_ctx":2048,"temperature":0.2,"think":"low","stop":["User:"]}';
  return json;
}
