// frontend/test/support/localization_audit.dart
//
// 영어 모드에서 화면에 한국어가 남아 있는지 감사하는 테스트 헬퍼.
// 위젯이 실제로 렌더한 문구만 검사하므로, 번역 키가 빠졌거나 `.tr` 을 붙이지
// 않은 자리만 정확히 드러난다.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/utils/localization.dart';

final RegExp _hangul = RegExp(r'[\uAC00-\uD7A3]');

/// 영어 모드로 전환하고, 테스트가 끝나면 한국어로 되돌린다.
void useEnglishLocale() {
  LanguageManager.languageCode = 'en';
  addTearDown(() => LanguageManager.languageCode = 'ko');
}

/// 위젯 트리에 실제로 렌더된 문구 중 한국어가 포함된 것을 모아 정렬해 돌려준다.
List<String> renderedKoreanTexts(WidgetTester tester) {
  final found = <String>{};

  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    final value = widget.data ?? widget.textSpan?.toPlainText();
    if (value != null && _hangul.hasMatch(value)) found.add(value.trim());
  }

  for (final element in find.byType(SelectableText).evaluate()) {
    final widget = element.widget as SelectableText;
    final value = widget.data ?? widget.textSpan?.toPlainText();
    if (value != null && _hangul.hasMatch(value)) found.add(value.trim());
  }

  for (final element in find.byType(Tooltip).evaluate()) {
    final message = (element.widget as Tooltip).message;
    if (message != null && _hangul.hasMatch(message)) found.add(message.trim());
  }

  return found.toList()..sort();
}

/// 영어 모드 화면에 번역되지 않은 한국어가 남아 있지 않은지 검증한다.
///
/// [allow] 에는 로봇/사용자 데이터처럼 번역 대상이 아닌 문구를 넘긴다.
void expectNoKoreanText(
  WidgetTester tester, {
  List<String> allow = const <String>[],
}) {
  final leftovers = renderedKoreanTexts(
    tester,
  ).where((text) => !allow.contains(text)).toList();

  expect(
    leftovers,
    isEmpty,
    reason:
        '영어 모드에서 번역되지 않은 문구가 ${leftovers.length}건 남아 있습니다: '
        '${leftovers.join(' | ')}',
  );
}
