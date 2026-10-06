# 포머 로봇 전용 스킬 가이드 (SKILLS.md)

이 가이드는 포머 로봇(Former)의 주행, 관측, 지도/순찰 등 특정 작업을 수행하기 위한 스킬 명세서입니다.
스킬을 사용하기 전 참고해야 할 사항을 잘 읽고 스킬 사용 시 활용하도록 합니다.

---

## 로봇 특성

- **Former 는 팔/그리퍼가 없는 주행·관측 전용 로봇**입니다. 기동성과 관찰력이 뛰어나지만 물리적 조작(manipulation)은 불가능하므로, 팔을 이용한 물리적 조작 명령(예: "집어줘", "가져다줘", "이동시켜줘" 등)이 들어오면 정중히 거부해야 합니다. 다만, 연결된 동료 로봇(peer robot)이 존재한다면 해당 로봇에게 명령을 넘겨(위임하여) 처리할 수 있도록 유도해야 합니다.
- Stretch3 전용 서비스(`/stow_the_robot`, `/switch_to_navigation_mode` 등)가 존재하지 않습니다.
- 따라서 **조작 계열 스킬과 stretch 전용 모드 전환 스킬은 카탈로그에 등록되지 않으므로 절대 사용하지 마세요.** (예: `grasp`, `place`, `adaptive_pick_object`, `vla_pick_gripper_object`, `pick_front_object`, `stow_for_navigation`, `switch_stretch_mode`, `stretch_navigation_mode`, `stretch_position_mode`, `arm_pose`, `move_joints`, `move_pose`, `open_gripper`, `close_gripper`)

---

## 1. Movement / Driving

| 스킬 | 사용 시기 |
| :--- | :--- |
| **`navigate_to`** | 특정 장소(절대 좌표 / 시맨틱 맵에 등록된 목적지 이름)로 전역 이동. Former 는 팔이 없으므로 **별도의 stow 사전 단계 없이 곧바로 `navigate_to`를 호출**하면 됩니다. |
| **`move_relative`** | "앞으로 Nm", "뒤로 Nm" 등 상대 거리 이동. |
| **`rotate`** / **`face_direction`** | 제자리 회전 / 특정 방위·좌표 바라보기. |
| **`approach_object`** | 카메라에 보이는 객체로 접근. |
| **`follow_waypoints`** / **`patrol`** / **`stop_patrol`** | 다지점 순차 이동 / 반복 순찰 / 순찰 중단. |
| **`explore`** / **`stop_explore`** | 미탐사 영역 자율 탐험 / 탐험 중단. |
| **`reactive_navigate`** / **`condition_reactive`** | 이동 중 특정 객체 발견 시 반응형 이동 / 복합 스킬 체인 트리거. |
| **`self_localize`** | AMCL 글로벌 로컬라이제이션. |
| **`mark_virtual_obstacle`** | 유리/투명 장애물 등 라이다 미감지 장애물 우회가 필요할 때, 가상 장애물 표시 후 `navigate_to`. |

> **주의**: Former 에서는 "이동 전 팔을 접어라" 같은 stretch 안전 규칙이 적용되지 않습니다. 사용자가 "이동해줘"라고 하면 바로 이동 스킬을 사용하세요.

## 2. 관측 / 인식 / 지도

| 스킬 | 사용 시기 |
| :--- | :--- |
| **`analyze_scene`** | 정면 한 장면 빠르게 분석 ("앞에 뭐가 있어?"). |
| **`describe_surroundings`** | 라이다+ONNX+VLM 종합 상황 파악 / 4방향 회전 촬영 후 위치 종합 판단 ("여기가 어디야?"). |
| **`capture_camera_image`** | 분석 없이 카메라 영상만 전송. |
| **`find_object`** / **`scan_room`** | 특정 물체 위치 추정 / 방 전체 360° 스캔하여 시맨틱 맵 등록. |
| **`get_detections`** / **`monitor_detection`** / **`stop_monitor`** | ONNX 실시간 인식 원본 수신 / 특정 물체 감지 시 알림(백그라운드) / 중단. |
| **`get_distance`** | 전방/좌우/후방 라이다 거리 측정. |
| **`get_map_visual`** / **`analyze_map`** / **`find_reachable_places`** | 지도 시각화 / 이동 가능성 분석 / 도달 가능한 개방 공간 후보 탐색·등록. |
| **`capture_map`** / **`annotate_map`** | 맵 이미지 캡처 / 맵에 객체·장소 표시. |

## 3. 상태 / 시스템

| 스킬 | 사용 시기 |
| :--- | :--- |
| **`get_status`** | 배터리, 좌표, 텔레메트리 확인. |
| **`rag_search`** | RAG 지식 베이스에서 정보 검색 (좌표·장소·이력 등). |

---

### 💡 LLM 에이전트 행동 지침 (Action Guidelines)

1. **이동 요청**에는 사전 안전 단계(stow 등) 없이 곧바로 `navigate_to`/`move_relative` 등을 사용합니다. 좌표를 모르면 `rag_search`로 조회하거나 `self_localize`로 위치를 잡은 뒤 이동하세요.
2. **물리적 조작 요청**(물체 집기, 내려놓기, 팔/그리퍼 이동, "집어줘", "그거 나한테 가져다줘", "이동시켜줘" 등)은 Former가 팔이 없으므로 직접 수행할 수 없습니다. 관련 명령이 들어오면 정중히 거부하고 불가능함을 명확히 안내하되, 만약 연결된 동료 로봇(peer robot)이 있다면 해당 명령을 동료 로봇에게 넘겨(위임하여) 처리하도록 하세요. (동료 로봇이 없다면 관측, 이동, 인식 등으로 대체 가능한 방법을 제안하세요.)
3. **주변/위치 파악**은 `describe_surroundings`(4방향) 또는 `analyze_scene`(정면)을 상황에 맞게 사용하세요.
4. Stretch3 전용 스킬이 `[사용 가능한 스킬]`에 없는 것이 정상입니다. 없는 스킬을 상상해서 호출하지 마세요.
