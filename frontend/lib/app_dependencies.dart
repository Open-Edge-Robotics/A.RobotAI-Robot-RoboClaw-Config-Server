// frontend/lib/app_dependencies.dart
//
// 운영 조립(main.dart)이 한 번 만들어 App 에 넘기는 의존성 묶음.
// Widget 은 전역 인스턴스 대신 이 묶음(또는 그 안의 개별 의존성)만 사용한다.

import 'api/admin_api.dart';
import 'platform/file_downloader.dart';
import 'platform/file_picker.dart';
import 'storage/token_store.dart';

class AppDependencies {
  final AdminApi api;
  final TokenStore tokenStore;
  final BackupFilePicker picker;
  final FileDownloader downloader;

  const AppDependencies({
    required this.api,
    required this.tokenStore,
    required this.picker,
    required this.downloader,
  });
}
