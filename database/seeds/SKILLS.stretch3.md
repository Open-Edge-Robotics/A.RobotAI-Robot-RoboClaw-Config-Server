# Stretch3 로봇 전용 스킬 가이드 (SKILLS.md)

이 가이드는 Stretch3 로봇의 주행·관측·**물체 조작(pick & place)** 작업을 위한 스킬 명세서입니다.
스킬을 사용하기 전 참고사항을 잘 읽고 활용하세요.

---

## 로봇 특성

- **Stretch3 는 모바일 베이스 + 신축형 팔 + 그리퍼 + 팬틸트 헤드 카메라를 갖춘 모바일 매니퓰레이터**입니다. 주행·관측뿐 아니라 **물체를 직접 집고 내려놓을 수 있습니다.**
- **팔이 몸통 오른쪽에 달려 있어**, 정면 물체를 잡으려면 베이스를 약 90° 회전해 오른쪽 팔 작업축을 물체 방향에 맞춰야 합니다(고수준 pick 스킬이 자동 처리).
- **이동(베이스 주행) 전에는 팔을 접어야(stow) 안전**합니다. 시스템이 베이스 이동 스킬 직전에 `stow_for_navigation`을 **자동 삽입**하므로, 보통은 직접 stow를 넣지 않아도 됩니다. 팔이 펴진 채 주행하도록 계획하지 마세요.
- 두 가지 제어 모드가 있습니다: **navigation 모드**(주행) / **position 모드**(팔·그리퍼 제어). 조작 전에는 position 모드, 주행 전에는 navigation 모드가 필요하며 stow/모드 전환 스킬이 이를 처리합니다.

---

## 0. W2 2층(w2_2f) 운용 컨텍스트

- 현재 운용 지도는 **`w2_2f`**(W2 건물 2층)이며 좌표계는 `map` 프레임입니다.
- 시맨틱 맵에 등록된 장소는 **이름으로 바로 `navigate_to`** 할 수 있습니다. 이름/좌표를 모르면 `rag_search`로 조회하거나 `find_reachable_places`로 도달 가능한 지점을 탐색·등록하세요.
- 이 지도 밖(다른 층·건물)으로의 이동은 지원하지 않습니다. 범위를 벗어난 목적지 요청은 정중히 거부하고 사용자에게 알립니다.

---

## 1. 이동 / 주행

| 스킬 | 사용 시기 |
| :--- | :--- |
| **`navigate_to`** | 특정 장소(절대 좌표 / 시맨틱 맵 등록 목적지 이름)로 전역 이동. 이동 스킬 직전에 `stow_for_navigation`이 **자동 삽입**됩니다. |
| **`move_relative`** | "앞으로 Nm", "뒤로 Nm" 등 상대 거리 이동. |
| **`rotate`** / **`face_direction`** | 제자리 회전 / 특정 방위·좌표 바라보기. |
| **`approach_object`** | 카메라에 보이는 객체로 접근. |
| **`follow_waypoints`** / **`patrol`** / **`stop_patrol`** | 다지점 순차 이동 / 반복 순찰 / 순찰 중단. |
| **`explore`** / **`stop_explore`** | 미탐사 영역 자율 탐험 / 탐험 중단. |
| **`reactive_navigate`** / **`condition_reactive`** | 이동 중 특정 객체 발견 시 반응형 이동 / 복합 스킬 체인 트리거. |
| **`self_localize`** | 부팅 직후·이동 후·위치 불확실 시 AMCL 글로벌 로컬라이제이션. |
| **`mark_virtual_obstacle`** | 유리/투명 장애물 등 라이다 미감지 장애물 우회가 필요할 때, 표시 후 `navigate_to`. |
| **`stow_for_navigation`** | 팔·그리퍼를 베이스 안으로 접고 navigation 모드로 전환. 주행 전 안전 확보(대개 자동). |
| **`stretch_navigation_mode`** / **`stretch_position_mode`** / **`switch_stretch_mode`** | 주행용 / 팔 제어용 모드 전환. |

> **주의(Former와 반대)**: Stretch3는 팔이 있으므로 **주행 전 stow가 필수**입니다. 직접 넣지 않아도 시스템이 베이스 이동 직전에 넣지만, "팔 편 상태로 이동"은 계획하지 마세요.

## 2. 관측 / 인식 / 지도

| 스킬 | 사용 시기 |
| :--- | :--- |
| **`analyze_scene`** | 정면 한 장면 빠르게 분석 ("앞에 뭐가 있어?"). |
| **`describe_surroundings`** | 라이다+ONNX+VLM 종합 상황 파악 / 4방향 회전 촬영 후 주변 상황 종합. 처음 보는 공간의 사물·환경 파악에 사용. (**기억된 장소명 판별**은 좌표로 비교하는 `identify_location`을 먼저 쓰세요.) |
| **`head_pan_tilt`** | 헤드 카메라의 좌우(pan)/상하(tilt) 시선 제어. 사전 자세(`search_head_down` 등) 또는 각도 지정. 베이스를 돌리지 않고 시야를 옮길 때. |
| **`capture_camera_image`** | 분석 없이 카메라 영상만 전송. |
| **`find_object`** / **`search_object`** / **`scan_room`** | 물체 위치 추정 / 헤드·몸통 스윕으로 능동 탐색 / 방 360° 스캔 후 시맨틱 맵 등록. |
| **`get_detections`** / **`monitor_detection`** / **`stop_monitor`** | ONNX 실시간 인식 / 특정 물체 감지 알림(백그라운드) / 중단. |
| **`get_distance`** | 전방/좌우/후방 라이다 거리 측정. |
| **`get_map_visual`** / **`analyze_map`** / **`find_reachable_places`** | 지도 시각화 / 이동 가능성 분석 / 도달 가능 지점 후보 탐색·등록. |
| **`capture_map`** / **`annotate_map`** | 맵 이미지 캡처 / 맵에 객체·장소 표시. |

## 3. 조작 / 그리퍼 (Manipulation)

**정면 물체를 집을 때는 고수준 pick 스킬을 먼저 쓰세요.** 저수준(`arm_pose`/`move_joints`/`move_pose`)은
세밀 제어가 꼭 필요할 때만 사용합니다.

| 스킬 | 사용 시기 |
| :--- | :--- |
| **`adaptive_pick_object`** | **최상위 pick 스킬.** 물체 방향을 모를 때: `search_object`로 능동 탐색 → 몸통 정렬 → 집기까지 자동. "저기 있는 X 집어줘"에 우선 사용. |
| **`pick_front_object`** | 정면에 보이는 물체를 집기(합성). stow → 베이스 90° 회전(오른쪽 팔 작업축 정렬) → 오른쪽 구역 집기. |
| **`vla_pick_front_object`** | 정면 물체를 **비전 피드백**으로 집기. 그리퍼 카메라 RGB-D 관측·보정 후 안전 조건 충족 시에만 그립. |
| **`vla_pick_gripper_object`** | 이미 그리퍼 카메라에 보이는 물체를 회전 없이 미세보정 후 집기. |
| **`prepare_right_side_pick`** / **`align_right_arm_to_front`** / **`pick_from_right_side_zone`** | (수동 시퀀스) 집기 준비자세 / 정면 물체용 회전 정렬 / 오른쪽 구역에 놓인 물체 집기. |
| **`place`** | 목표 pose(또는 target_object 표면)에 물체를 내려놓기. |
| **`open_gripper`** / **`close_gripper`** | 그리퍼 열기 / 닫기. |
| **`observe_head_target`** / **`observe_gripper_target`** / **`servo_gripper_to_object`** | 헤드/그리퍼 카메라로 대상 관측(3D 좌표·정렬 상태) / 그리퍼를 대상에 서보 정렬. 집기 실패 진단·보정용. |
| **`arm_pose`** / **`move_joints`** / **`move_pose`** | (저수준) 팔을 named pose로 / 조인트 값으로 / end-effector를 목표 pose(base_link: x=앞·y=왼쪽·z=위)로 이동. |

> **집기 흐름 권장**: (위치 모름) `adaptive_pick_object` · (정면 보임) `pick_front_object`/`vla_pick_front_object` → 필요 시 `observe_*`/`servo_gripper_to_object`로 보정 → `place`. 집기 전 position 모드, 이동 시 stow는 시스템이 처리합니다.

## 4. 상태 / 시스템 / 위치 기억

| 스킬 | 사용 시기 |
| :--- | :--- |
| **`get_status`** | 배터리, 좌표, 텔레메트리 등 **로봇의 현재 상태** 확인. (장소 이름 판별·저장 위치 조회에는 쓰지 마세요.) |
| **`rag_search`** | RAG 지식에서 **이름 → 정보(좌표·이력) 정방향 검색**. "충전대 위치 알려줘", "거실 어디 있어"처럼 **장소명이 포함된 위치·좌표 질의**에 사용. |
| **`rag_add`** | 지식·위치 **저장**. "현재 위치를 `<장소>`로 기억/저장/등록"에 사용 (metadata.location_name="`<장소>`"). **좌표를 몰라도** 저장하면 현재 위치 좌표로 자동 보완됩니다. |
| **`identify_location`** | **좌표 → 이름 역조회**. 현재(또는 지정 x, y) 지점이 기억된 어떤 장소인지 판별. "여기 어디야", "지금 있는 곳 이름이 뭐야"처럼 **장소명 없이 현재 지점의 이름**을 물을 때. |

## 5. 협업 / 위임 (Cooperation)

Stretch3는 조작이 가능하므로, 다른 로봇(예: Former)이 못 하는 **물체 조작을 위임받아** 수행할 수 있습니다.
반대로 Stretch3가 하기 어려운 작업(장거리 순찰 등)은 동료에게 위임할 수 있습니다.

| 스킬 | 사용 시기 |
| :--- | :--- |
| **`list_peer_robots`** / **`query_peer_capabilities`** | 연결된 동료 로봇과 능력 확인. |
| **`delegate_task`** | 특정 작업 1건을 동료 로봇에게 위임. |
| **`coordinate_peer_task`** | 여러 단계·로봇이 얽힌 작업을 조율. |
| **`call_peer_robot`** / **`broadcast_to_peers`** / **`query_peer_status`** | 특정 동료 호출 / 전체 공지 / 상태 조회. |

---

## 위치·장소 요청 라우팅 (중요)

임의의 장소명(거실, 키친, 충전대, 회의실 2, 창고 등)이 들어간 요청은 아래 규칙으로 스킬을 고릅니다.

| 사용자 의도 | 예시 | 스킬 |
| :--- | :--- | :--- |
| 장소로 이동 | "충전대로 이동", "거실 가줘", "x=3.9, y=0.8 로 가" | `navigate_to`(target_name 또는 x, y) |
| 현재 위치를 이름으로 저장 | "현재 위치를 충전대로 기억", "여기를 거실로 저장" | `rag_add`(location_name="`<장소>`", 좌표는 자동 보완) |
| **장소명 → 좌표/위치 (정방향)** | "충전대 좌표 알려줘", "거실 어디 있어", "키친 위치가 뭐야" | **`rag_search`(query="`<장소>`")** |
| **현재 지점 → 이름 (역방향)** | "여기 어디야", "현재 위치 이름이 뭐야", "이 좌표는 어디야" | **`identify_location`** |

원칙:
- 장소명이 들어간 "위치/좌표" 질문의 기본은 **`rag_search`(정방향)** 입니다. `identify_location`·`get_status`·`analyze_scene`으로 보내지 마세요.
- 장소명 없이 "여기/현재/이 좌표"처럼 지금 지점의 이름을 물을 때만 **`identify_location`(역방향)** 입니다.
- 저장된 위치를 다루는 질문에 `analyze_scene`(주변 사물 관찰)·`get_status`(로봇 상태)를 쓰지 않습니다.
- 좌표를 모른 채 위치를 저장해도 됩니다 — `rag_add`가 현재 위치 좌표로 자동 보완합니다.

---

### 💡 LLM 에이전트 행동 지침 (Action Guidelines)

1. **이동 요청**에는 `navigate_to`/`move_relative` 등을 사용하세요. **주행 전 stow는 시스템이 자동 처리**하므로 직접 넣지 않아도 되지만, 팔을 편 채로 주행하는 계획은 세우지 마세요. 좌표를 모르면 `rag_search`로 조회합니다. (`self_localize`는 사용자의 명시적 지시가 있을 때만.)
2. **물체 조작 요청**("집어줘", "가져다줘", "내려놔", "옮겨줘" 등)은 Stretch3가 직접 수행합니다. 정면/미지 위치 물체는 고수준 pick 스킬(`adaptive_pick_object`·`pick_front_object`·`vla_pick_front_object`)을 우선 쓰고, 필요 시 `observe_*`/`servo_gripper_to_object`로 보정한 뒤 `place`로 마무리하세요. 저수준 팔 제어(`arm_pose`/`move_joints`/`move_pose`)는 꼭 필요할 때만.
3. **위치 기억·조회**는 위 "위치·장소 요청 라우팅" 표를 그대로 따르세요: "…로 기억/저장" → `rag_add`, "`<장소>` 위치/좌표"(정방향) → `rag_search`, "여기/현재 위치 이름"(역방향) → `identify_location`. 저장된 위치 질의에 `get_status`·`analyze_scene`을 쓰지 마세요.
4. **주변/환경 파악**(장소명 판별이 아니라 눈앞의 사물·상황)은 `describe_surroundings`(4방향)·`analyze_scene`(정면)·`head_pan_tilt`(시선 이동)를 상황에 맞게 사용하세요.
5. 목표 달성에 필요한 **최소한의 스킬만** 순서대로 계획하세요. 확실하지 않으면 먼저 관측(`analyze_scene`/`search_object`/`observe_*`)으로 상황을 파악한 뒤 행동합니다. 등록되지 않은 스킬을 상상해서 호출하지 마세요.
