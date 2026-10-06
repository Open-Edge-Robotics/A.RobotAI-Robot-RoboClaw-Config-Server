// frontend/lib/platform/file_picker.dart
//
// 백업 JSON 파일 선택 추상화.
// 브라우저 구현(WebFilePicker)과 테스트용 Fake 를 교체 주입할 수 있게 한다.

/// 선택된 백업 파일.
class PickedBackupFile {
  final String filename;
  final String content;

  PickedBackupFile(this.filename, this.content);
}

abstract interface class BackupFilePicker {
  /// 사용자에게 JSON 파일 선택을 요청한다. 취소하면 null.
  Future<PickedBackupFile?> pickJson();
}
