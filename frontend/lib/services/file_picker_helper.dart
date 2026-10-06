// frontend/lib/services/file_picker_helper.dart
//
// 백업 JSON 파일 선택 헬퍼. 브라우저 구현(WebFilePicker)은 main.dart 에서
// FilePickerHelper.instance 로 주입한다. 이 파일은 package:web 을 import 하지
// 않아 VM 테스트에서 안전하게 사용할 수 있다.

import 'dart:convert';
import '../platform/file_picker.dart';

/// 하위 호환용 별칭.
typedef FilePickerResult = PickedBackupFile;

class FilePickerHelper {
  /// 전역 파일 선택기 인스턴스. main() 에서 WebFilePicker 로 초기화한다.
  /// 테스트에서는 Fake 로 교체한다.
  static BackupFilePicker instance = _NoopFilePicker();

  static Future<PickedBackupFile?> pickJsonFile() => instance.pickJson();

  /// 선택된 파일 내용이 올바른 JSON 객체인지 검사하고 Map 으로 변환한다.
  static Map<String, dynamic>? parseJsonDocument(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// 기본 인스턴스가 초기화되기 전에 접근될 때 사용하는 무동작 구현.
class _NoopFilePicker implements BackupFilePicker {
  @override
  Future<PickedBackupFile?> pickJson() async => null;
}
