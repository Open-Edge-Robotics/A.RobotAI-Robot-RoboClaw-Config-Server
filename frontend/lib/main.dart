// frontend/lib/main.dart

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'api/http_admin_api.dart';
import 'app.dart';
import 'app_dependencies.dart';
import 'features/language/language_controller.dart';
import 'features/theme/theme_controller.dart';
import 'platform/web_file_downloader.dart';
import 'platform/web_file_picker.dart';
import 'services/download_helper.dart';
import 'services/file_picker_helper.dart';
import 'storage/web_language_store.dart';
import 'storage/web_theme_mode_store.dart';
import 'storage/web_token_store.dart';

void main() {
  // 운영 인스턴스는 여기서 한 번만 만들고, UI 에는 AppDependencies 로 전달한다.
  final tokenStore = WebTokenStore();
  final client = http.Client();
  final api = HttpAdminApi(client: client, tokenStore: tokenStore);
  final picker = WebFilePicker();
  final downloader = WebFileDownloader();

  // 저장된 사용자 테마를 복원한다. 저장 값이 없으면 라이트 테마.
  final themeController = ThemeController(store: WebThemeModeStore());

  // 저장된 사용자 언어를 복원한다. 저장 값이 없으면 한국어.
  final languageController = LanguageController(store: WebLanguageStore());

  // 하위 호환용: 기존 static 파사드(ApiService/DownloadHelper/FilePickerHelper)만
  // 이 전역 인스턴스를 읽는다. 운영 UI 는 dependencies 만 사용한다.
  HttpAdminApi.instance = api;
  DownloadHelper.instance = downloader;
  FilePickerHelper.instance = picker;

  runApp(
    App(
      themeController: themeController,
      languageController: languageController,
      dependencies: AppDependencies(
        api: api,
        tokenStore: tokenStore,
        picker: picker,
        downloader: downloader,
      ),
    ),
  );
}
