// frontend/test/dashboard_backup_edge_test.dart
//
// 대시보드 백업(가져오기) 흐름의 미탐지 엣지 케이스:
// - 올바르지 않은 JSON 파일 선택 → 'invalid_json' 검증 실패 스낵바
// - 검증 오류(errors) 목록 표시 + 가져오기 버튼 비활성화
// - 가져오기(import) 실패 → 오류 스낵바 및 다이얼로그 유지
// - 가져오기 성공 → config/scenario 탭 refresh(재조회) 호출

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/features/language/language_controller.dart';
import 'package:frontend/platform/file_picker.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/storage/language_store.dart';

import 'support/app_dependencies.dart';

/// 대시보드 검증은 한국어를 기본값으로 쓴다.
class _FakeLanguageStore implements LanguageStore {
  String? value;

  @override
  String? read() => value;

  @override
  void write(String code) => value = code;

  @override
  void clear() => value = null;
}

const _validBackupJson = '{"version":1,"configs":[],"scenarios":[]}';

const _validValidationJson =
    '{"valid":true,'
    '"summary":{"configs":2,"scenarios":1,"new_configs":2,'
    '"conflicting_configs":0,"new_scenarios":1,"conflicting_scenarios":0},'
    '"warnings":[],"errors":[],"includes_secrets":false}';

const _importResultJson =
    '{"configs":{"created":2,"updated":0,"skipped":0},'
    '"scenarios":{"created":1,"updated":0,"skipped":0}}';

int _countRequests(
  TestDependencies deps,
  bool Function(http.Request request) predicate,
) => deps.requests.where(predicate).length;

void main() {
  Future<void> pumpDashboard(WidgetTester tester, TestDependencies deps) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          themeMode: ThemeMode.dark,
          onThemeModeChanged: () {},
          languageController: LanguageController(store: _FakeLanguageStore()),
          dependencies: deps.dependencies,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startImportFlow(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.save_alt));
    await tester.pumpAndSettle();
    await tester.tap(find.text('백업 파일 가져오기'));
    await tester.pumpAndSettle();
  }

  testWidgets('올바르지 않은 JSON 파일을 선택하면 invalid_json 검증 실패를 알린다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async => http.Response('[]', 200),
      backupFile: PickedBackupFile('broken.json', '{"version": '),
    );

    await pumpDashboard(tester, deps);
    await startImportFlow(tester);

    expect(find.text('백업 검증 실패: invalid_json'), findsOneWidget);
    expect(
      deps.requests.where(
        (request) => request.url.path.endsWith('/transfer/import/validate'),
      ),
      isEmpty,
      reason: 'JSON 파싱 실패는 서버 검증을 호출하지 않는다',
    );
    expect(deps.picker.pickCount, 1);
    expect(find.text('가져오기'), findsNothing);
  });

  testWidgets('검증 오류가 있으면 오류 목록을 보여주고 가져오기를 비활성화한다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/transfer/import/validate')) {
          return http.Response(
            '{"valid":false,'
            '"summary":{"configs":2,"scenarios":1,"new_configs":2,'
            '"conflicting_configs":0,"new_scenarios":1,'
            '"conflicting_scenarios":0},'
            '"warnings":[],'
            '"errors":["config ID 1 is duplicated.","scenario name is empty."],'
            '"includes_secrets":false}',
            200,
          );
        }
        return http.Response('[]', 200);
      },
      backupFile: PickedBackupFile('backup.json', _validBackupJson),
    );

    await pumpDashboard(tester, deps);
    await startImportFlow(tester);

    expect(find.text('• config ID 1 is duplicated.'), findsOneWidget);
    expect(find.text('• scenario name is empty.'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, '가져올 수 없음'),
          )
          .onPressed,
      isNull,
      reason: '검증 실패 문서는 가져올 수 없다',
    );

    await tester.tap(
      find.widgetWithText(ElevatedButton, '가져올 수 없음'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(
      deps.requests.where(
        (request) =>
            request.method == 'POST' &&
            request.url.path.endsWith('/transfer/import'),
      ),
      isEmpty,
    );
  });

  testWidgets('가져오기가 실패하면 오류 스낵바를 띄우고 다이얼로그를 유지한다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/transfer/import/validate')) {
          return http.Response(_validValidationJson, 200);
        }
        if (request.url.path.endsWith('/transfer/import')) {
          return http.Response('{"error":"boom"}', 500);
        }
        return http.Response('[]', 200);
      },
      backupFile: PickedBackupFile('backup.json', _validBackupJson),
    );

    await pumpDashboard(tester, deps);
    await startImportFlow(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, '가져오기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('백업 가져오기 실패'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, '가져오기'),
      findsOneWidget,
      reason: '실패 후 다시 시도할 수 있도록 다이얼로그를 유지한다',
    );
  });

  testWidgets('가져오기에 성공하면 config/scenario 탭을 다시 조회한다', (tester) async {
    final deps = buildTestDependencies(
      respond: (request) async {
        if (request.url.path.endsWith('/transfer/import/validate')) {
          return http.Response(_validValidationJson, 200);
        }
        if (request.url.path.endsWith('/transfer/import')) {
          return http.Response(_importResultJson, 200);
        }
        return http.Response('[]', 200);
      },
      backupFile: PickedBackupFile('backup.json', _validBackupJson),
    );

    await pumpDashboard(tester, deps);

    int countListGets(String pathSuffix) => _countRequests(
      deps,
      (request) =>
          request.method == 'GET' && request.url.path.endsWith(pathSuffix),
    );
    final configsBefore = countListGets('/configs');
    final scenariosBefore = countListGets('/scenarios');

    await startImportFlow(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, '가져오기'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('가져오기 완료: 설정(생성 2, 갱신 0, 건너뜀 0)'),
      findsOneWidget,
    );
    expect(find.text('가져오기'), findsNothing, reason: '성공 후 다이얼로그는 닫힌다');
    expect(
      countListGets('/configs'),
      configsBefore + 1,
      reason: '가져오기 성공 후 설정 탭을 다시 조회한다',
    );
    expect(
      countListGets('/scenarios'),
      scenariosBefore + 1,
      reason: '가져오기 성공 후 시나리오 탭을 다시 조회한다',
    );
  });
}
