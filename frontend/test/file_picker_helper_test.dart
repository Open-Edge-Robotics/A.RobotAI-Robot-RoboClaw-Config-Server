// frontend/test/file_picker_helper_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/platform/file_picker.dart';
import 'package:frontend/services/file_picker_helper.dart';

class FakeFilePicker implements BackupFilePicker {
  PickedBackupFile? result;
  int pickCount = 0;

  @override
  Future<PickedBackupFile?> pickJson() async {
    pickCount++;
    return result;
  }
}

void main() {
  group('parseJsonDocument', () {
    test('올바른 JSON 객체는 Map 으로 변환한다', () {
      final map = FilePickerHelper.parseJsonDocument('{"kind":"x","n":1}');
      expect(map, isNotNull);
      expect(map!['kind'], 'x');
      expect(map['n'], 1);
    });

    test('JSON 배열은 null 을 반환한다', () {
      expect(FilePickerHelper.parseJsonDocument('[1,2,3]'), isNull);
    });

    test('잘못된 JSON 은 null 을 반환한다', () {
      expect(FilePickerHelper.parseJsonDocument('{bad json'), isNull);
    });

    test('빈 문자열은 null 을 반환한다', () {
      expect(FilePickerHelper.parseJsonDocument(''), isNull);
    });
  });

  group('pickJsonFile', () {
    test('주입된 인스턴스로 위임한다', () async {
      final fake = FakeFilePicker()
        ..result = PickedBackupFile('backup.json', '{"kind":"x"}');
      FilePickerHelper.instance = fake;

      final picked = await FilePickerHelper.pickJsonFile();
      expect(fake.pickCount, 1);
      expect(picked, isNotNull);
      expect(picked!.filename, 'backup.json');
      expect(picked.content, '{"kind":"x"}');
    });

    test('취소(null)를 그대로 전달한다', () async {
      final fake = FakeFilePicker()..result = null;
      FilePickerHelper.instance = fake;

      final picked = await FilePickerHelper.pickJsonFile();
      expect(picked, isNull);
    });
  });
}
