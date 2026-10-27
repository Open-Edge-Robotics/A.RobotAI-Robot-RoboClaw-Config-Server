# AI Config Server Configuration Guide

AI Config Server는 RoboClaw의 robot/environment별 runtime profile을 저장하고
배포합니다. 서버 자체 설정과 RoboClaw profile 설정을 구분해야 합니다.

## 서버 자체 설정

`config.example.yaml`을 복사하여 `config.yaml`을 생성하거나 `AI_CONFIG_SERVER_` prefix 환경변수로 설정합니다.
`config.yaml`은 비밀키/민감 정보 보호를 위해 Git 추적에서 제외(`.gitignore`)되어 있습니다.

| 설정 | 용도 |
| --- | --- |
| `server.host`, `server.port` | API/dashboard bind |
| `database.path` | SQLite database 경로 |
| `security.admin_token` | dashboard CRUD 인증 |
| `security.device_token` | 로봇 배포 API 인증 |
| `security.require_auth` | 인증 강제 |
| `security.cors_allowed_origins` | dashboard origin 제한 |
| `mcp.registry_url` | MCP catalog registry |

운영 환경의 token은 `config.yaml`에 직접 저장하지 말고 Secret 또는 환경변수로
주입하세요. admin/device token은 최소 32자 이상 random 값을 사용해야 합니다.

## RoboClaw profile

profile은 다음 식별자로 관리됩니다.

```text
robot_name + environment
```

예시:

butler + office
former + factory
stretch3 + lab

```

동일 robot/environment에서는 하나의 profile만 active 상태가 되어야 합니다.
일반 수정 API는 active 상태를 변경하지 않으며, 별도 activate 작업에서만 변경합니다.

## 권장 profile 작성 순서

1. `name`, `robot_name`, `environment` 입력
2. ROS domain과 agent ID 입력
3. LLM provider/model 입력
4. provider에 필요한 credential 입력
5. RAG와 embedding backend 입력
6. HTTP/gRPC 보안 token 및 CIDR 입력
7. MCP, vision, task 설정 입력
8. soul/skills/troubleshooting/limits 파일 입력
9. 저장
10. profile 활성화
11. RoboClaw에서 `fetch`, `config-doctor`, `launch --dry-run` 실행

## JSON 필드 형식

다음 필드는 JSON array여야 합니다.

```json
http_allowed_cidrs_json
http_allowed_skills_json
http_blocked_skills_json
grpc_target_peers_json
cloid_cleanup_demo_motion_ids_json
mcp_servers_json
```

다음 필드는 JSON object여야 합니다.

```json
limits_content
ollama_options_json
```

예시:

```json
[
  {
    "name": "former",
    "host": "192.168.1.20",
    "port": 50052,
    "capabilities": ["navigate", "inspect"]
  }
]
```

동료 로봇 편집 폼에서 capability를 쉼표로 구분해 설정합니다. CLOi 정리 시연 피어는 역할과 별도로 `cleanup_demo`를 명시해야 하며, `manipulation`으로 등록하지 않습니다. Ollama 옵션과 같이 UI가 별도로 편집하지 않는 기존 JSON 항목은 저장 시 보존됩니다.

CLOi 정리 시연 설정에서 기능을 켜고 허용 모션 ID를 JSON array로 관리합니다. 배포 `.env`에는 `RC_CLOID_CLEANUP_DEMO_ENABLED`와 `RC_CLOID_CLEANUP_DEMO_MOTION_IDS_JSON`으로 출력합니다. 빈 allowlist는 CLOi 1호 승인 기본값 `[22,60]`을 사용하고 `[]`는 시연을 끕니다. 모션 ID는 개체마다 다르므로 다른 호기에서는 해당 로봇 catalog에서 승인된 ID를 직접 지정합니다. catalog `pre_id`가 있는 모션은 선택하지 않고 prerequisite를 자동 실행하지 않습니다. MotionCmd 요청은 모션/정리 완료를 보증하지 않습니다.

## API 사용

### 관리자 API

```http
GET    /api/v1/admin/configs
POST   /api/v1/admin/configs
PUT    /api/v1/admin/configs/:id
PATCH  /api/v1/admin/configs/:id
POST   /api/v1/admin/configs/:id/activate
```

`PUT`와 `PATCH` 모두 부분 update 방식으로 동작하며 생략된 필드는 기존 값이
유지됩니다. active 상태와 DB metadata는 일반 update payload로 변경할 수 없습니다.

### RoboClaw device API

기존 v1 endpoint:

```http
GET /api/v1/configs/active
GET /api/v1/configs/active/files/.env
```

v2 runtime manifest:

```http
GET /api/v2/device/runtime-config?robot_name=butler&environment=office
```

v2 응답은 다음을 포함합니다.

- `schema_version`
- `config_revision`
- `robot_name`
- `environment`
- masked `config`

v2 manifest는 단계적 전환을 위한 canonical contract입니다. 기존 v1 API와
`.env` endpoint는 migration 기간 동안 유지됩니다.

## Contract Release 갱신

공통 contract release bundle을 받은 경우 RoboClaw와 동일하게 다음 명령을 사용합니다.

```bash
task contract-update BUNDLE=/path/to/release-bundle/generated
```

GitLab public release에서 직접 갱신할 때는 서버 CLI를 사용합니다.

```bash
./ai-config-server contract update --version v2.2.0
```

project 기본값은 `wkqco33/rcf-config-contract`이며, 다른 project는
`--project group/project`로 지정합니다. 네트워크가 없는 환경에서는 기존의
`--from` local bundle 방식을 사용합니다.

bundle에는 다음 파일이 있어야 합니다.

```text
runtime-contract.json
runtime-config.schema.json
contract-manifest.json
```

업데이트 후 `contracts/contract.lock.json`이 새 version/checksum으로 갱신되고,
다음 검증과 Dart artifact 생성을 수행합니다.

```bash
task contract-check
task frontend-contract
```

## 검증 규칙

서버는 다음을 저장 전에 검증합니다.

- provider enum
- ROS domain range
- HTTP/gRPC/Dashboard port range
- RAG score range
- task/retry/timeout 음수 여부
- vision 활성화 시 model path
- Maestro FleetControl: `maestro_disconnect_policy` enum, `robot_port` 범위, `fleet_heartbeat_sec` 음수 여부, `maestro_ip` 설정 시 `robot_id` 필수
- System 1: router/scope enum, timeout 및 max option 하한, confidence threshold JSON object와 값(0~1)
- JSON top-level object/array shape

잘못된 설정은 HTTP `400`으로 반환됩니다.

### Maestro FleetControl (contract v2.2.0)

`fleet.*` field는 로봇에서 Maestro FleetControl 서버로 연결하는 outbound
connector 설정입니다. `maestro_ip`가 비어 있으면 connector가 비활성화되고,
`maestro_ip`를 설정하면 `robot_id`가 필수입니다. `.env`로 배포되는 환경변수는
`MAESTRO_IP`, `ROBOT_PORT`, `ROBOT_ID`, `ROBOT_SITE_ID`, `ROBOT_MAP_ID`,
`ROBOT_MAP_VERSION`, `ROBOT_MAP_FRAME_ID`, `MAESTRO_DISCONNECT_POLICY`,
`FLEET_HEARTBEAT_SEC`, `FLEET_COMMAND_JOURNAL_PATH`, `RC_SKILLS_GUIDE_FILE`,
`FLEET_CONTROL_TLS`, `FLEET_CONTROL_CA_CERT`, `FLEET_CONTROL_CLIENT_CERT`,
`FLEET_CONTROL_CLIENT_KEY`입니다. mTLS 인증서 경로는 `FLEET_CONTROL_TLS=true`
일 때만 `.env`에 기록됩니다.

### System 1 Fast Router (contract v2.4.0)

`System 1 Fast Router` 섹션에서 LLM planner 이전의 rule/Laya 라우터, shadow 기록,
허용 scope, endpoint/provider, timeout, confidence threshold, 후보 스킬과 option 수를
설정할 수 있습니다. System 1 API 키는 hosted provider에서 인증이 필요한 경우에만
지정하며 API 응답에서는 마스킹됩니다. 실행 `.env`에는 `SYSTEM1_*` 설정이 포함되고,
`SYSTEM1_CONF_THRESHOLDS_JSON`은 한 줄 JSON 객체로 정규화됩니다.

### CLOiD 상황별 표현 모션 (contract v2.7.0)

`CLOi` 섹션에서 `cloid_expression_enabled`(배포 `.env` `RC_CLOID_EXPRESSION_ENABLED`)를
설정합니다. 기본값은 꺼짐입니다. 켜면 RoboClaw 가 태스크를 마친 뒤 상황(인사·대화·탐색·실패)에
맞는 등록 모션을 한 번 재생합니다. 베이스 주행이 포함된 태스크에서는 재생하지 않습니다.
선택 가능한 모션 ID 는 RoboClaw 코드 상수 allowlist 로 고정되어 있고, 모두 `pre_id` 없는
모션입니다. 표현 모션이 부자연스러운 개체는 이 값을 꺼 두면 됩니다.

### CLOiD 주행 전 boxing 자세 정렬 (contract v2.8.0)

`CLOi` 섹션에서 `cloid_navigation_pose_enabled`(배포 `.env` `RC_CLOID_NAVIGATION_POSE_ENABLED`)를
설정합니다. 기본값은 꺼짐입니다. 켜면 RoboClaw가 베이스가 움직이는 스킬 직전에 CLOiD를
최소 부피(boxing) 자세로 만드는 실행(`cloid.move_boxing`)을 한 번 요청하고, 요청이 실패하면
이동을 거부합니다. cloid 프로필 전용이며 주행 완료 후 상체 자세 복원은 자동으로 수행하지 않습니다.

### 정리 태스크 실험 계측 run log (contract v2.10.0)

`6. 로컬 환경 경로 및 리소스 설정` 섹션의 `cleanup_run_log_path`(배포 `.env`
`RC_CLEANUP_RUN_LOG_PATH`)에 JSONL 경로를 지정합니다. 기본값은 비어 있고, 비어 있으면
기록하지 않습니다. 값을 지정하면 RoboClaw가 `tidy_home` 실행 1회와 정리 위임 결정·결과를
한 줄씩 남겨 성공률·동료 할당·위임 결과·구간별 소요를 측정할 수 있습니다.

- 경로는 로봇 컨테이너가 쓸 수 있는 경로여야 합니다. 예: `/ros2_ws/agent_workspace/cleanup_runs.jsonl`
  (호스트 저장소의 `agent_workspace/` 가 컨테이너에 쓰기 가능으로 마운트되어 있습니다).
- 기록은 append 방식이라 에이전트를 재기동해도 이어집니다. 끄려면 값을 비우고 재배포합니다.
- 집계는 RoboClaw 저장소의 `scripts/cleanup_run_report.py`, 3조건 반복 실행은
  `validation/cleanup-experiment/` 를 사용합니다.

### Dashboard 웹 노드 실행 스위치 (contract v2.11.0)

`Dashboard 웹 노드 설정` 섹션의 `use_dashboard`(배포 `.env` `RC_USE_DASHBOARD`)로 웹 노드
실행 여부를 정합니다. 기본값은 꺼짐입니다. 꺼져 있으면 `dashboard_host`/`dashboard_port`를
지정해도 RoboClaw가 `use_dashboard` launch 인자를 켜지 않아 `robo_claw_dashboard` 노드가
기동하지 않습니다. `.env`에는 스위치가 항상 기록되므로, 노드를 쓰지 않는 프로필은 그대로
꺼 두면 됩니다.

## 운영 확인

서버 상태:

```http
GET /ping
GET /ready
```

`/ping`은 프로세스 응답을 확인하고, `/ready`는 SQLite 연결까지 확인합니다.
Kubernetes readiness/liveness probe는 `/ready`를 사용합니다.

로봇 검증:

```bash
robo_claw_cli fetch butler office
robo_claw_cli config-doctor butler office
robo_claw_cli config-effective butler office
robo_claw_cli launch butler office --dry-run
```

## Secret 주의사항

- active JSON 응답의 credential은 masking됩니다.
- `.env` 다운로드에는 실행에 필요한 secret이 포함될 수 있습니다.
- device cache는 directory `0700`, 파일 `0600`으로 저장해야 합니다.
- backup export에서 secret 포함 옵션은 제한적으로 사용하세요.
- device token 하나로 임의 profile을 조회할 수 있는 구형 배포는 token 회전과
  서버 접근 제한을 우선 적용하세요.

## Profile 변경 체크리스트

- [ ] 대상 robot/environment 확인
- [ ] provider와 credential 확인
- [ ] JSON array/object 형식 확인
- [ ] limits safety schema 확인
- [ ] vision model과 topic 확인
- [ ] gRPC/HTTP token과 HTTP/Dashboard bind 확인
- [ ] profile 저장 후 active 상태 확인
- [ ] 로봇에서 `config-doctor` 통과
- [ ] `launch --dry-run` 검토

## 새 profile 설정 추가 시 변경 위치

공통 runtime 설정의 canonical source는 `rcf-config-contract` 저장소의 GitLab
Release입니다. AI Config Server는 `contracts/contract.lock.json`으로 release를
고정하고 자체 generator를 실행합니다.

```bash
go run . contract check
go run . contract generate --check
task contract-check
task frontend-contract
```

GitLab public release에서 갱신:

```bash
./ai-config-server contract update --version v2.2.0
```

네트워크가 없는 경우 local bundle:

```bash
task contract-update BUNDLE=/path/to/release-bundle/generated
```

서버 schema와 Dart generated file을 직접 수정하지 않습니다. 공통 contract release를
갱신한 뒤 `contracts/`와 lock을 업데이트하고 generator를 실행합니다.

중앙 관리 설정을 추가할 때는 다음 순서를 지킵니다.

1. `rcf-config-contract`의 Registry에 field 추가
2. contract compatibility 검사와 release 생성
3. `./ai-config-server contract update --version v2.x.y`로 lock과 artifact 갱신
4. `database/models/roboclaw_config.go`에 DB/API field 추가
5. `handler/roboclaw_config.go`에 enum/range/dependency/JSON shape 검증 추가
6. `handler/config_files.go`에 `.env` 또는 runtime artifact mapping 추가
7. `frontend/lib/models/config_model.dart`의 constructor/JSON 변환 추가
8. `frontend/lib/screens/config_tab.dart` 및 해당 section widget에 입력·저장 연결
9. `go run . contract generate`와 `task frontend-contract` 실행
10. 관련 RoboClaw consumer/launch mapping과 문서 갱신

다음 테스트를 함께 추가해야 합니다.

- backend create/update validation
- v2 manifest response
- Flutter model round-trip
- CLI decode 및 launch argument mapping
- simulation forwarding

RoboClaw와 AI Config Server를 같은 경로에 둘 필요는 없습니다. 공통 release
artifact와 lock checksum만 일치하면 각 저장소에서 독립적으로 검증할 수 있습니다.

로봇별 topic/URDF/manipulation 설정은 중앙 profile이 아니라
`robo_claw/src/robo_claw_bringup/config/<robot>_config.yaml`에 추가합니다.
호스트 경로, ROS distro, DDS, Docker mount는 `.env`, `rc.sh`, Docker launcher에
추가하며 DB 모델에는 넣지 않습니다.
