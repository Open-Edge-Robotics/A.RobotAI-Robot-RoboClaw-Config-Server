// frontend/test/activation_test.dart
//
// 활성화 그룹 규칙(applyGroupActivation)의 진리표 단위 테스트.
// 서버 ActivateConfig 와 동일하게 "같은 로봇/환경만" 비활성화하고
// 다른 그룹의 활성 상태는 그대로 유지해야 한다.

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/activation.dart';

class _Item {
  _Item(this.id, this.robot, this.env, {this.isActive = false});

  final int? id;
  final String robot;
  final String env;
  bool isActive;
}

/// 같은 로봇/환경에 중복 Active 가 섞여 있는 실제 데이터를 흉내낸다.
List<_Item> _items() => [
  _Item(1, 'butler', 'office'), // 같은 그룹, 비활성
  _Item(2, 'butler', 'office'), // 활성화 대상
  _Item(3, 'butler', 'office', isActive: true), // 같은 그룹, 중복 활성
  _Item(4, 'former', 'factory', isActive: true), // 다른 로봇/환경, 활성 → 유지
  _Item(5, 'former', 'factory'), // 다른 로봇/환경, 비활성 → 유지
  _Item(6, 'butler', 'factory'), // 같은 로봇, 다른 환경 → 유지
];

bool _apply(List<_Item> items, int id) => applyGroupActivation(
  items,
  activatedId: id,
  idOf: (item) => item.id,
  robotOf: (item) => item.robot,
  environmentOf: (item) => item.env,
  setActive: (item, isActive) => item.isActive = isActive,
);

void main() {
  group('applyGroupActivation', () {
    test('대상만 활성화하고 같은 로봇/환경의 다른 항목은 비활성화한다', () {
      final items = _items();
      final found = _apply(items, 2);

      expect(found, isTrue);
      expect(items[0].isActive, isFalse);
      expect(items[1].isActive, isTrue);
      expect(items[2].isActive, isFalse, reason: '같은 그룹의 중복 Active 도 해제');
    });

    test('다른 로봇/환경 그룹의 활성 상태는 변경하지 않는다', () {
      final items = _items();
      _apply(items, 2);

      expect(items[3].isActive, isTrue, reason: '다른 그룹의 활성은 유지');
      expect(items[4].isActive, isFalse, reason: '다른 그룹의 비활성은 유지');
      expect(items[5].isActive, isFalse, reason: '같은 로봇/다른 환경도 유지');
    });

    test('대상이 목록에 없으면 아무것도 변경하지 않는다', () {
      final items = _items();
      final found = _apply(items, 999);

      expect(found, isFalse);
      expect(items.map((e) => e.isActive), [
        false,
        false,
        true,
        true,
        false,
        false,
      ]);
    });

    test('빈 목록에서도 안전하다', () {
      expect(_apply([], 1), isFalse);
    });
  });
}
