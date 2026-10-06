// frontend/lib/platform/web_file_downloader.dart
//
// 브라우저 Blob/ObjectURL 기반 FileDownloader 구현.
// package:web 에 대한 의존은 이 파일에만 국한한다.

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:web/web.dart' as web;
import '../services/logger.dart';
import 'file_downloader.dart';

class WebFileDownloader implements FileDownloader {
  @override
  void downloadText(String content, String filename) {
    AppLogger.info('Triggering browser download for file: $filename');
    try {
      final bytes = utf8.encode(content);
      final blob = web.Blob(
        [Uint8List.fromList(bytes).toJS].toJS,
        web.BlobPropertyBag(type: 'text/plain;charset=utf-8'),
      );
      _triggerDownload(blob, filename);
      AppLogger.info('Successfully triggered download for $filename');
    } catch (e, stack) {
      AppLogger.error('Failed to download file $filename', e, stack);
    }
  }

  @override
  void downloadZip(Map<String, String> files, String zipFilename) {
    AppLogger.info('Triggering browser download for zip file: $zipFilename');
    try {
      final archive = Archive();
      files.forEach((filename, content) {
        final bytes = utf8.encode(content);
        archive.addFile(ArchiveFile(filename, bytes.length, bytes));
      });
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        throw Exception('Zip encoding failed (returned null)');
      }
      final blob = web.Blob(
        [Uint8List.fromList(zipBytes).toJS].toJS,
        web.BlobPropertyBag(type: 'application/zip'),
      );
      _triggerDownload(blob, zipFilename);
      AppLogger.info('Successfully triggered zip download for $zipFilename');
    } catch (e, stack) {
      AppLogger.error('Failed to download zip file $zipFilename', e, stack);
    }
  }

  void _triggerDownload(web.Blob blob, String filename) {
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;

    web.document.body!.appendChild(anchor);
    anchor.click();
    web.document.body!.removeChild(anchor);
    web.URL.revokeObjectURL(url);
  }
}
