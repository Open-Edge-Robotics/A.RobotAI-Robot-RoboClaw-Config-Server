// frontend/test/localization_coverage_test.dart
//
// 한국어 문구가 번역 경로를 벗어나지 않는지 소스를 스캔해 검증한다.
// 위젯 테스트로 화면을 띄우지 않아도 되는 규칙만 담당한다.
//
// 규칙
// 1. `.tr` 이 붙은 한국어 문구는 번역 표에 키가 있어야 한다.
// 2. 라벨/힌트/설명 계열 named 인자에 넘기는 한국어 문구도 번역 표에 키가 있어야
//    한다(이 저장소의 섹션 위젯은 헬퍼 내부에서 `.tr` 을 적용한다).
// 3. `Text('...')` 처럼 위젯에 직접 넘기는 한국어 문구는 `.tr` 이 필요하다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/utils/localization.dart';

final RegExp _hangul = RegExp(r'[\uAC00-\uD7A3]');

/// 리터럴 하나를 나타낸다. 인접한 리터럴은 Dart 가 컴파일 시 이어 붙이므로
/// 스캔에서도 하나로 합쳐서 다룬다.
class _Literal {
  _Literal(this.value, this.offset, this.end, this.line);

  String value;
  int offset;
  int end;
  final int line;

  String get display =>
      value.length <= 70 ? value : '${value.substring(0, 70)}...';
}

const Set<String> _translatedNamedArgs = {
  'label',
  'labelText',
  'hintText',
  'helperText',
  'desc',
  'title',
  'subtitle',
  'message',
  'tooltip',
  'semanticLabel',
};

/// 번역 표에 있어야 하는데 없는 키와, `.tr` 을 빠뜨린 문구를 모은다.
List<String> findLocalizationGaps(Map<String, String> sourceByPath) {
  final problems = <String>[];

  for (final entry in sourceByPath.entries) {
    final path = entry.key;
    final source = entry.value;
    final literals = _scanLiterals(source);

    for (final literal in literals) {
      final text = literal.value;
      if (!_hangul.hasMatch(text)) continue;

      final after = source.substring(literal.end);
      final before = source.substring(0, literal.offset);
      final lineText = _lineText(source, literal.line);
      if (lineText.trimLeft().startsWith('//')) continue;

      // 보간이 들어간 문구는 번역 키가 될 수 없으므로 내부 리터럴만 검사한다.
      if (text.contains(r'${')) {
        for (final inner in RegExp(r'"([^"\n]*)"').allMatches(text)) {
          final innerText = inner.group(1)!;
          if (!_hangul.hasMatch(innerText)) continue;
          if (LanguageManager.hasTranslation(innerText)) continue;
          problems.add('$path:${literal.line} 번역 키 없음 (보간 내부): \'$innerText\'');
        }
        continue;
      }

      final hasTr = RegExp(r'^\s*\.tr\b').hasMatch(after);
      final tail = before.length <= 60
          ? before
          : before.substring(before.length - 60);
      final namedArgName = RegExp(r'(\w+)\s*:\s*$').firstMatch(tail)?.group(1);
      final constructorName = RegExp(
        r'([A-Za-z_]\w*)\(\s*$',
      ).firstMatch(tail)?.group(1);
      final directWidgetArg =
          constructorName == 'Text' ||
          constructorName == 'SelectableText' ||
          constructorName == 'RichText';
      // 헬퍼 위젯의 첫 위치 인자도 번역 대상이다(예: ConfigSectionHeader('...')).
      final helperPositionalArg =
          constructorName != null &&
          !directWidgetArg &&
          constructorName.isNotEmpty &&
          RegExp(r'^[A-Z_]').hasMatch(constructorName);

      final needsKey =
          hasTr ||
          (namedArgName != null &&
              _translatedNamedArgs.contains(namedArgName)) ||
          helperPositionalArg;

      if (needsKey) {
        if (!LanguageManager.hasTranslation(text)) {
          problems.add(
            '$path:${literal.line} 번역 키 없음 (${hasTr ? '.tr' : namedArgName ?? constructorName}): '
            "'${literal.display}'",
          );
        }
        continue;
      }

      if (directWidgetArg) {
        problems.add('$path:${literal.line} .tr 누락: \'${literal.display}\'');
      }
    }
  }

  return problems;
}

int _lineAt(String source, int line) {
  var current = 1;
  var index = 0;
  while (current < line) {
    final next = source.indexOf('\n', index);
    if (next < 0) break;
    index = next + 1;
    current++;
  }
  return index;
}

String _lineText(String source, int line) {
  final start = _lineAt(source, line);
  final end = source.indexOf('\n', start);
  return end < 0 ? source.substring(start) : source.substring(start, end);
}

List<_Literal> _scanLiterals(String source) {
  final pattern = RegExp(
    r"'([^'\n]*)'"
    r'|"([^"\n]*)"',
  );
  final found = <_Literal>[];
  for (final match in pattern.allMatches(source)) {
    final value = _unescape(match.group(1) ?? match.group(2) ?? '');
    final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
    final literal = _Literal(value, match.start, match.end, line);

    // 직전 리터럴과 공백만으로 붙어 있으면 Dart 가 이어 붙이므로 합친다.
    if (found.isNotEmpty) {
      final previous = found.last;
      final between = source.substring(previous.end, literal.offset);
      if (between.trim().isEmpty && !between.contains('\n\n')) {
        previous.value = previous.value + literal.value;
        previous.end = literal.end;
        continue;
      }
    }
    found.add(literal);
  }
  return found;
}

String _unescape(String value) {
  return value
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\t', '\t')
      .replaceAll(r"\'", "'")
      .replaceAll(r'\"', '"')
      .replaceAll(r'\\', r'\');
}

void main() {
  test('소스의 한국어 문구는 모두 번역 경로를 지난다', () {
    final sources = <String, String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('utils/localization.dart')) continue;
      if (!entity.path.contains('widgets/') &&
          !entity.path.contains('screens/')) {
        continue;
      }
      sources[entity.path] = entity.readAsStringSync();
    }

    expect(sources, isNotEmpty);

    final problems = findLocalizationGaps(sources);
    expect(
      problems,
      isEmpty,
      reason: '번역이 빠진 문구가 ${problems.length}건 있습니다:\n${problems.join('\n')}',
    );
  });

  test('번역 표의 값에는 한국어가 남지 않는다', () {
    final leftovers = <String>[];
    for (final entry in LanguageManager.allTranslations.entries) {
      if (_hangul.hasMatch(entry.value)) {
        leftovers.add('${entry.key} -> ${entry.value}');
      }
    }
    expect(leftovers, isEmpty, reason: '영어 번역에 한국어가 남았습니다: $leftovers');
  });
}
