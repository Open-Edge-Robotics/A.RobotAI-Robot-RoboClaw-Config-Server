// frontend/lib/platform/file_downloader.dart
//
// 파일 다운로드 추상화.
// 브라우저 구현(WebFileDownloader)과 테스트용 Fake 를 교체 주입할 수 있게 한다.

abstract interface class FileDownloader {
  /// 텍스트 파일을 브라우저 다운로드로 저장한다.
  void downloadText(String content, String filename);

  /// 여러 파일을 zip 으로 묶어 다운로드한다.
  void downloadZip(Map<String, String> files, String zipFilename);
}
