// frontend/lib/main.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api/http_admin_api.dart';
import 'app.dart';
import 'features/theme/theme_controller.dart';
import 'platform/web_file_downloader.dart';
import 'platform/web_file_picker.dart';
import 'services/download_helper.dart';
import 'services/file_picker_helper.dart';
import 'storage/web_theme_mode_store.dart';
import 'storage/web_token_store.dart';

void main() {
  // 운영 환경 기본 인스턴스 초기화 (브라우저 구현 주입)
  HttpAdminApi.instance = HttpAdminApi(
    client: http.Client(),
    tokenStore: WebTokenStore(),
  );
  DownloadHelper.instance = WebFileDownloader();
  FilePickerHelper.instance = WebFilePicker();

  // 저장된 사용자 테마를 복원한다. 저장 값이 없으면 라이트 테마.
  final themeController = ThemeController(store: WebThemeModeStore());

  runApp(App(themeController: themeController));
}
