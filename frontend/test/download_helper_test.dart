// frontend/test/download_helper_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/platform/file_downloader.dart';
import 'package:frontend/services/download_helper.dart';

class FakeDownloader implements FileDownloader {
  final List<String> textDownloads = [];
  final List<String> zipDownloads = [];

  @override
  void downloadText(String content, String filename) {
    textDownloads.add(filename);
  }

  @override
  void downloadZip(Map<String, String> files, String zipFilename) {
    zipDownloads.add(zipFilename);
  }
}

void main() {
  test('downloadTextFile 는 주입된 인스턴스로 위임한다', () {
    final fake = FakeDownloader();
    DownloadHelper.instance = fake;

    DownloadHelper.downloadTextFile('content', 'ROBOT.md');
    expect(fake.textDownloads, ['ROBOT.md']);
  });

  test('downloadZipFile 는 주입된 인스턴스로 위임한다', () {
    final fake = FakeDownloader();
    DownloadHelper.instance = fake;

    DownloadHelper.downloadZipFile({'a': '1'}, 'backup.zip');
    expect(fake.zipDownloads, ['backup.zip']);
  });
}
