# Stretch3 로봇 장애 조치 가이드 (TROUBLESHOOTING.md)

로봇 구동 중 아래 예외가 발생하면, 에이전트는 즉시 이 가이드에 따라 대응을 계획하거나
사용자에게 안전 상태를 보고한다. **Stretch3는 팔/그리퍼가 있으므로 조작(팔) 관련 복구
절차가 함께 적용된다.**

---

## 1. 내비게이션 장애 (Navigation)

### NAVIGATION_TIMEOUT / GOAL_ABORTED (목적지 도달 실패)
- **원인**: 동적 장애물(사람·임시 구조물)이 경로를 막거나, 슬립으로 측위 오차가 누적됨.
- **조치**:
  1. 기동을 멈추고 제자리에 정지한다.
  2. `analyze_scene`(정면) 또는 `describe_surroundings`(4방향 회전)로 주변 장애물을 확인한다.
  3. 동적 장애물이면 5~10초 대기 후 `navigate_to`를 다시 시도한다.
  4. 그래도 실패하면 안전 지대로 이동하거나 작업을 보류하고, 사용자/관리자에게 보고하며 지원을 요청한다.

### 팔이 펴진 채 주행 위험 / 이동 전 안전자세
- **원인**: 조작 직후 팔이 펴진 상태에서 베이스 이동을 시도하면 팔이 장애물에 걸릴 수 있음.
- **조치**: 베이스 이동 전 `stow_for_navigation`으로 팔을 접고 navigation 모드로 전환한다.
  (시스템이 베이스 이동 스킬 직전에 자동 삽입하지만, 계획 단계에서 "팔 편 채 이동"은 피한다.)

### 투명·미감지 장애물 (유리문 등)
- **원인**: 라이다가 감지하지 못하는 유리/투명 장애물로 인한 반복 실패.
- **조치**: `mark_virtual_obstacle`로 가상 장애물을 표시한 뒤 `navigate_to`로 우회한다.

---

## 2. 측위 불확실 (Localization)

### LOCALIZATION_UNCERTAIN (현재 위치가 불확실)
- **원인**: 부팅 직후, 또는 큰 이동/미끄러짐 후 AMCL 추정이 흔들림.
- **조치**:
  1. 먼저 `get_status`로 현재 좌표/상태를 확인하고 사용자에게 불확실함을 보고한다.
  2. 사용자의 지시가 있을 때 `self_localize`로 글로벌 재추정을 수행한다.
     (이동 실패 시 자동으로 임의 실행하지 않는다.)

---

## 3. 조작 장애 (Manipulation)

### 대상 물체를 찾지 못함 (OBJECT_NOT_FOUND)
- **원인**: 물체가 시야 밖이거나 방향을 모름.
- **조치**: `search_object`(헤드·몸통 능동 탐색) 또는 `head_pan_tilt`로 시야를 옮겨 다시 탐지한다.
  위치를 알면 `adaptive_pick_object`가 탐색부터 집기까지 자동 수행한다.

### 파지 실패 / 그리퍼가 비어 있음 (GRASP_FAILED)
- **원인**: 대상 정렬 오차, 미끄러짐, 깊이 추정 오류.
- **조치**:
  1. `observe_gripper_target`/`observe_head_target`로 대상이 집기 윈도우에 있는지 확인한다.
  2. `servo_gripper_to_object`로 그리퍼를 대상에 미세 정렬한 뒤 재시도한다.
  3. 정면 물체면 `vla_pick_front_object`(비전 피드백)로 재시도한다.
  4. 반복 실패 시 무리하게 닫지 말고 상황을 보고한다(물건·그리퍼 손상 방지).

### 팔 동작 실패 / 충돌 위험 (ARM_MOTION_FAILED / COLLISION)
- **원인**: MoveIt 계획 실패, 도달 불가 pose, 주변 충돌 가능성.
- **조치**: 동작을 멈추고 `stow_for_navigation`(또는 `arm_pose` 안전자세)으로 팔을 접은 뒤,
  목표 pose·좌표를 재확인하고 사용자에게 보고한다.

### 모드 불일치 (MODE_MISMATCH)
- **원인**: 주행 중 팔 제어를, 또는 조작 중 주행을 시도.
- **조치**: 조작 전 `stretch_position_mode`, 주행 전 `stretch_navigation_mode`(또는 `stow_for_navigation`)로 전환한다.

---

## 4. 하드웨어 진단 (Hardware)

### BATTERY_LOW (배터리 부족, ≤ 15%)
- **원인**: 배터리가 안전 임계치(`ROBOT_LIMITS.json`의 `battery.low_threshold_pct`) 이하로 하락.
- **조치**:
  1. `get_status`로 정확한 잔량을 확인한다.
  2. 진행 중인 비필수 작업(탐험·순찰·모니터링 등)을 보류한다. 조작 중이면 안전하게 물체를 내려놓거나 팔을 접는다.
  3. 사용자/관리자에게 충전을 요청하고 보고한다.

### LIDAR / CAMERA / GRIPPER_CAMERA DISCONNECTED (센서 수신 실패)
- **원인**: USB 접촉 불량, 전원 공급 문제, 노드 오작동.
- **조치**:
  1. 즉시 `emergency_stop`으로 기동을 멈춘다.
  2. 라이다/헤드 카메라 미복구 시 **블라인드 주행을 금지**한다.
  3. 그리퍼 카메라 미복구 시 정밀 파지를 보류한다(`servo_gripper_to_object`/`observe_gripper_target` 불가).
  4. `get_status`와 오류 코드를 포함한 상세 보고를 사용자/관제에 전송한다.
