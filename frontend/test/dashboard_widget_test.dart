// frontend/test/dashboard_widget_test.dart
//
// 대시보드 Widget 테스트. 전역 인스턴스(HttpAdminApi/FilePicker/Downloader)를
// Fake 로 주입해 브라우저/네트워크 없이 UI 흐름을 검증한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/api/http_admin_api.dart';
import 'package:frontend/platform/file_downloader.dart';
import 'package:frontend/platform/file_picker.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/services/download_helper.dart';
import 'package:frontend/services/file_picker_helper.dart';
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

class FakeFilePicker implements BackupFilePicker {
  @override
  Future<PickedBackupFile?> pickJson() async => null;
}

class FakeDownloader implements FileDownloader {
  @override
  void downloadText(String content, String filename) {}
  @override
  void downloadZip(Map<String, String> files, String zipFilename) {}
}

void main() {
  setUp(() {
    HttpAdminApi.instance = HttpAdminApi(
      client: MockClient((request) async => http.Response('[]', 200)),
      tokenStore: FakeTokenStore(),
    );
    FilePickerHelper.instance = FakeFilePicker();
    DownloadHelper.instance = FakeDownloader();
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    // AppBar 타이틀(버전 배지 포함)이 넘치지 않도록 넓은 뷰포트 사용
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          themeMode: ThemeMode.dark,
          onThemeModeChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('대시보드에 백업 메뉴가 표시된다', (tester) async {
    await pumpDashboard(tester);
    expect(find.byIcon(Icons.save_alt), findsOneWidget);
  });

  testWidgets('백업 메뉴에서 내보내기 다이얼로그를 연다', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.byIcon(Icons.save_alt));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 설정 내보내기'));
    await tester.pumpAndSettle();

    expect(find.text('API Key와 토큰 포함'), findsOneWidget);
    expect(find.text('내보내기'), findsOneWidget);
  });

  testWidgets('민감 정보 포함 체크 시 경고가 표시된다', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.byIcon(Icons.save_alt));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 설정 내보내기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('API Key와 토큰 포함'));
    await tester.pumpAndSettle();

    expect(find.textContaining('평문으로 포함됩니다'), findsOneWidget);
  });

  testWidgets('관리자 토큰 다이얼로그를 연다', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.byIcon(Icons.vpn_key));
    await tester.pumpAndSettle();

    expect(find.text('관리자 인증 토큰 입력'), findsOneWidget);
    expect(find.text('저장 및 적용'), findsOneWidget);
  });

  testWidgets('언어 토글 버튼이 표시된다', (tester) async {
    await pumpDashboard(tester);
    expect(find.text('KO'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
  });

  testWidgets('내비게이션 레일로 시나리오 탭으로 전환한다', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.text('시나리오').first);
    await tester.pumpAndSettle();

    expect(find.text('테스트 시나리오 목록'), findsOneWidget);
  });

  testWidgets('새로고침 버튼과 다크모드 토글 버튼이 표시된다', (tester) async {
    await pumpDashboard(tester);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byIcon(Icons.light_mode), findsOneWidget);
  });

  testWidgets('초기 401 인증 실패 시 토큰 다이얼로그가 하나만 열리고 토큰 저장 후 닫힌다', (tester) async {
    bool hasToken = false;
    HttpAdminApi.instance = HttpAdminApi(
      client: MockClient((request) async {
        if (!hasToken) {
          return http.Response('{"error":"unauthorized"}', 401);
        }
        return http.Response('[]', 200);
      }),
      tokenStore: FakeTokenStore(),
    );

    await pumpDashboard(tester);

    // 토큰 다이얼로그가 정확히 1개만 표시되어야 함
    expect(find.text('관리자 인증 토큰 입력'), findsOneWidget);

    // 다이얼로그 내 토큰 입력
    final dialogFinder = find.byType(AlertDialog);
    final tokenField = find.descendant(
      of: dialogFinder,
      matching: find.byType(TextField),
    );
    await tester.enterText(tokenField, 'valid-admin-token');
    hasToken = true;

    // 저장 및 적용 클릭
    await tester.tap(find.text('저장 및 적용'));
    await tester.pumpAndSettle();

    // 다이얼로그가 완전히 닫히고 화면에 남아있지 않아야 함
    expect(find.text('관리자 인증 토큰 입력'), findsNothing);
  });

  testWidgets('토큰 다이얼로그에서 취소를 누르면 닫히고 다시 열 수 있다', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.byIcon(Icons.vpn_key));
    await tester.pumpAndSettle();
    expect(find.text('관리자 인증 토큰 입력'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('관리자 인증 토큰 입력'), findsNothing);

    await tester.tap(find.byIcon(Icons.vpn_key));
    await tester.pumpAndSettle();
    expect(find.text('관리자 인증 토큰 입력'), findsOneWidget);
  });

  testWidgets('토큰 다이얼로그에서 토큰 소거를 누르면 토큰이 제거되고 닫힌다', (tester) async {
    final tokenStore = FakeTokenStore()..write('existing-token');
    HttpAdminApi.instance = HttpAdminApi(
      client: MockClient((request) async => http.Response('[]', 200)),
      tokenStore: tokenStore,
    );

    await pumpDashboard(tester);

    await tester.tap(find.byIcon(Icons.vpn_key));
    await tester.pumpAndSettle();
    expect(find.text('관리자 인증 토큰 입력'), findsOneWidget);

    await tester.tap(find.text('토큰 소거'));
    await tester.pumpAndSettle();
    expect(find.text('관리자 인증 토큰 입력'), findsNothing);
    expect(tokenStore.read(), isNull);
  });
}
