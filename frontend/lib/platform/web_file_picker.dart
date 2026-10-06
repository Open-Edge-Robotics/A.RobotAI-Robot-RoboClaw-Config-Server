// frontend/lib/platform/web_file_picker.dart
//
// 브라우저 <input type="file"> 기반 BackupFilePicker 구현.
// package:web 에 대한 의존은 이 파일에만 국한한다.

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../services/logger.dart';
import 'file_picker.dart';

class WebFilePicker implements BackupFilePicker {
  @override
  Future<PickedBackupFile?> pickJson() {
    final completer = Completer<PickedBackupFile?>();
    try {
      final input = web.document.createElement('input') as web.HTMLInputElement
        ..type = 'file'
        ..accept = '.json,application/json';

      input.onchange = ((web.Event event) {
        final files = input.files;
        if (files == null || files.length == 0) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        final file = files.item(0);
        if (file == null) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        _readFile(file)
            .then((content) {
              if (!completer.isCompleted) {
                completer.complete(PickedBackupFile(file.name, content));
              }
            })
            .catchError((Object e, StackTrace st) {
              AppLogger.error('Failed to read picked file', e, st);
              if (!completer.isCompleted) completer.complete(null);
            });
      }).toJS;

      input.oncancel = ((web.Event event) {
        if (!completer.isCompleted) completer.complete(null);
      }).toJS;

      input.click();
    } catch (e, stack) {
      AppLogger.error('Failed to open file picker', e, stack);
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future;
  }

  Future<String> _readFile(web.File file) {
    final completer = Completer<String>();
    final reader = web.FileReader();

    reader.onload = ((web.ProgressEvent event) {
      final result = reader.result;
      final text = result.dartify()?.toString() ?? '';
      completer.complete(text);
    }).toJS;

    reader.onerror = ((web.ProgressEvent event) {
      completer.completeError('File read error');
    }).toJS;

    reader.readAsText(file);
    return completer.future;
  }
}
