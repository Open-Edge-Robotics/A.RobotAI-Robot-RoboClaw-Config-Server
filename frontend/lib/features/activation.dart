// frontend/lib/features/activation.dart
//
// 로봇/환경 그룹 단위 활성화 규칙.
//
// 서버의 ActivateConfig 핸들러는 "같은 robot_name + environment" 의 항목만
// 비활성화하고 대상만 활성화한다. 다른 그룹의 활성 상태는 건드리지 않는다.
// 이 함수는 그 규칙과 동일하게 클라이언트 로컬 목록을 갱신한다.
//
// ConfigController 와 ScenarioController 가 같은 규칙을 공유하도록 분리했다.
// (같은 불리언 식을 각 컨트롤러에 복붙했을 때 한쪽만 고쳐지는 재발을 막는다.)

/// [items] 안에서 [activatedId] 를 가진 항목만 활성화하고,
/// 그 항목과 같은 [robotOf]/[environmentOf] 그룹의 다른 항목은 비활성화한다.
///
/// 다른 로봇/환경 그룹의 활성 상태는 **그대로 유지**한다.
/// [activatedId] 를 가진 항목이 [items] 에 없으면 아무것도 변경하지 않고
/// `false` 를 반환한다(필터로 목록에 없는 경우 등).
bool applyGroupActivation<T>(
  List<T> items, {
  required int activatedId,
  required int? Function(T item) idOf,
  required String Function(T item) robotOf,
  required String Function(T item) environmentOf,
  required void Function(T item, bool isActive) setActive,
}) {
  final targetIndex = items.indexWhere((item) => idOf(item) == activatedId);
  if (targetIndex < 0) return false;

  final target = items[targetIndex];
  final robot = robotOf(target);
  final environment = environmentOf(target);

  for (final item in items) {
    final sameGroup =
        robotOf(item) == robot && environmentOf(item) == environment;
    // 다른 그룹은 기존 활성 상태를 유지한다.
    if (!sameGroup) continue;
    setActive(item, idOf(item) == activatedId);
  }
  return true;
}
