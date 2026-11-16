// frontend/test/support/app_dependencies.dart
//
// Widget/Controller 테스트용 AppDependencies 조립 헬퍼.
// 운영 조립(main.dart)과 동일하게 HttpAdminApi + MockClient 를 사용하고,
// 다운로드/파일 선택/토큰 접근은 호출을 기록하는 Fake 로 주입한다.

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/api/http_admin_api.dart';
import 'package:frontend/app_dependencies.dart';
import 'package:frontend/platform/file_downloader.dart';
import 'package:frontend/platform/file_picker.dart';
import 'package:frontend/storage/token_store.dart';

/// 텍스트 다운로드 1건의 기록.
class RecordedTextDownload {
  const RecordedTextDownload({required this.content, required this.filename});

  final String content;
  final String filename;
}

/// ZIP 다운로드 1건의 기록.
class RecordedZipDownload {
  const RecordedZipDownload({required this.files, required this.filename});

  final Map<String, String> files;
  final String filename;
}

/// 토큰 접근을 기록하는 테스트용 TokenStore.
class RecordingTokenStore implements TokenStore {
  RecordingTokenStore([this.value]);

  String? value;
  final List<String> writes = [];
  int readCount = 0;
  int clearCount = 0;

  @override
  String? read() {
    readCount++;
    return value;
  }

  @override
  void write(String token) {
    writes.add(token);
    value = token;
  }

  @override
  void clear() {
    clearCount++;
    value = null;
  }
}

/// 다운로드 호출을 기록하는 테스트용 FileDownloader.
class RecordingDownloader implements FileDownloader {
  final List<RecordedTextDownload> textDownloads = [];
  final List<RecordedZipDownload> zipDownloads = [];

  @override
  void downloadText(String content, String filename) {
    textDownloads.add(
      RecordedTextDownload(content: content, filename: filename),
    );
  }

  @override
  void downloadZip(Map<String, String> files, String zipFilename) {
    zipDownloads.add(RecordedZipDownload(files: files, filename: zipFilename));
  }
}

/// 파일 선택 결과를 고정하는 테스트용 BackupFilePicker.
class RecordingFilePicker implements BackupFilePicker {
  RecordingFilePicker([this.nextFile]);

  PickedBackupFile? nextFile;
  int pickCount = 0;

  @override
  Future<PickedBackupFile?> pickJson() async {
    pickCount++;
    return nextFile;
  }
}

/// 기록용 Fake 와 실제 AppDependencies 를 함께 담는 묶음.
class TestDependencies {
  const TestDependencies({
    required this.dependencies,
    required this.api,
    required this.tokenStore,
    required this.picker,
    required this.downloader,
    required this.requests,
  });

  final AppDependencies dependencies;
  final HttpAdminApi api;
  final RecordingTokenStore tokenStore;
  final RecordingFilePicker picker;
  final RecordingDownloader downloader;

  /// MockClient 가 받은 요청 (전송 순서대로).
  final List<http.Request> requests;
}

/// [respond] 로 응답이 결정되는 AppDependencies 를 만든다.
///
/// 전역 `HttpAdminApi.instance` 는 건드리지 않는다.
TestDependencies buildTestDependencies({
  required Future<http.Response> Function(http.Request request) respond,
  String? token,
  PickedBackupFile? backupFile,
}) {
  final requests = <http.Request>[];
  final tokenStore = RecordingTokenStore(token);
  final picker = RecordingFilePicker(backupFile);
  final downloader = RecordingDownloader();
  final api = HttpAdminApi(
    client: MockClient((request) {
      requests.add(request);
      return respond(request);
    }),
    tokenStore: tokenStore,
  );
  return TestDependencies(
    dependencies: AppDependencies(
      api: api,
      tokenStore: tokenStore,
      picker: picker,
      downloader: downloader,
    ),
    api: api,
    tokenStore: tokenStore,
    picker: picker,
    downloader: downloader,
    requests: requests,
  );
}
