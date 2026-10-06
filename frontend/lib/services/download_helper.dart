// frontend/lib/services/download_helper.dart
//
// 파일 다운로드 헬퍼. 브라우저 구현(WebFileDownloader)은 main.dart 에서
// DownloadHelper.instance 로 주입한다. 이 파일은 package:web 을 import 하지 않아
// VM 테스트에서 안전하게 사용할 수 있다.

import '../platform/file_downloader.dart';

class DownloadHelper {
  /// 전역 다운로더 인스턴스. main() 에서 WebFileDownloader 로 초기화한다.
  /// 테스트에서는 Fake 로 교체한다.
  static FileDownloader instance = _NoopDownloader();

  static void downloadTextFile(String content, String filename) =>
      instance.downloadText(content, filename);

  static void downloadZipFile(Map<String, String> files, String zipFilename) =>
      instance.downloadZip(files, zipFilename);
}

/// 기본 인스턴스가 초기화되기 전에 접근될 때 사용하는 무동작 구현.
class _NoopDownloader implements FileDownloader {
  @override
  void downloadText(String content, String filename) {}

  @override
  void downloadZip(Map<String, String> files, String zipFilename) {}
}
