# System 1 라우팅 설정 정리 및 AI Config Server 변경 요청 (2026-10-24)

robo-claw의 System 1 Fast Router 설정 중 **라우터 선택(`SYSTEM1_ROUTER`)**, **비교 기록(`SYSTEM1_SHADOW`, `SYSTEM1_SHADOW_LOG`)**, **하위 단계 라우팅(`SYSTEM1_STEP_ROUTING`)**의 역할을 정리하고, AI Config Server 웹 설정(System 1 Fast Router 섹션)에 필요한 변경을 요청합니다.

- robo-claw 소스: `~/workspace-OpenEdgeRobotics/A.RobotAI-Robot-RoboClaw`
- 관련 문서: `docs/SYSTEM1_FAST_ROUTER.md`, `docs/SYSTEM1_ELIGIBILITY_GATE.md`

## 1. 세 설정의 역할

| 설정 | 질문 | 값 | 기본값 | 적용 대상 |
|---|---|---|---|---|
| `SYSTEM1_ROUTER` | **어떤 라우터가** 판단하나? | `rule` / `laya` | `rule` | 모든 사전 라우팅 |
| `SYSTEM1_STEP_ROUTING` | 복합 명령을 **분해한 단계에도** 라우터를 쓰나? | `off` / `shadow` / `on` | `shadow` | 복합 명령의 하위 단계 |
| `SYSTEM1_SHADOW` | 선택되지 **않은** 라우터의 판단도 **비교용으로 기록**하나? | `true` / `false` | `false` | 라우터가 호출될 때마다 |
| `SYSTEM1_SHADOW_LOG` | 위 비교 기록을 저장할 **파일 경로** | 파일 경로(예: `/ws/agent_workspace/system1_shadow.jsonl`) | 없음(노드 로그에만 남김) | `SYSTEM1_SHADOW=true`일 때만 사용 |

### 1.1 `SYSTEM1_ROUTER` — 누가 판단하나

LLM을 부르기 전에 명령을 먼저 판단하는 라우터를 고릅니다. 둘 중 **하나만** 판단합니다(배타 선택).

- `rule`: 기존 규칙(정규식) 라우터. "앞으로 2미터"(`move_relative`), 컵 집기 같은 지름길을 씁니다.
- `laya`: Laya(System 1) 모델. 인사, 인자 없는 조회 스킬(`get_status` 등)을 직접 처리합니다. Laya 서버 장애 시 해당 요청만 자동으로 `rule`이 처리합니다.

### 1.2 `SYSTEM1_STEP_ROUTING` — 분해된 단계에도 쓰나

"카메라 이미지 보내고 분석해줘" 같은 복합 명령은 TaskDecomposer가 여러 단계로 나눕니다. 이 설정은 그 **각 단계**를 어떻게 처리할지 정합니다. 단계마다 Eligibility Gate가 "혼자 완결되는 단계인지"를 판정합니다. 이전 결과를 가리키거나("촬영한", "찾은"), 조건이 있거나("~면"), 아직 복합이면 탈락시킵니다.

| 값 | 동작 |
|---|---|
| `off` | 모든 단계를 LLM이 처리합니다(예전 동작). |
| `shadow` | 단계마다 판정과 "켰다면 했을 처리"를 **로그로만** 남기고, 실행은 LLM이 합니다. 동작 변화가 없습니다. |
| `on` | 관문을 통과하고 라우터가 Direct_Skill / Simple_Reply를 고른 단계는 **LLM 없이 처리**합니다. 나머지는 LLM이 처리합니다. |

Yes/No가 아니라 3가지 값입니다. 켜기 전에 기록으로 확인하는 `shadow` 단계를 두기 위해서입니다.

### 1.3 `SYSTEM1_SHADOW` / `SYSTEM1_SHADOW_LOG` — 비교 기록

라우터가 판단할 때마다, **선택되지 않은 다른 라우터**도 백그라운드로 돌려 결과를 비교 기록합니다. 실행에는 영향이 없습니다.

| `SYSTEM1_ROUTER` | 실제 판단 | 비교용으로 함께 돌리는 라우터 |
|---|---|---|
| `rule` | 규칙 | Laya (`SYSTEM1_ENDPOINT` 필요. 없으면 경고 후 비교 기록 꺼짐) |
| `laya` | Laya | 규칙 |

- 기록 위치: 노드 로그 `System1 shadow: {"primary": ..., "shadow": ..., "agree": true|false}`. `SYSTEM1_SHADOW_LOG`에 경로가 있으면 같은 내용을 JSONL 파일에도 한 줄씩 추가합니다.
- `SYSTEM1_STEP_ROUTING`이 `shadow`/`on`이면 분해된 단계에서도 라우터가 호출되므로, 그 단계들도 비교 기록에 함께 남습니다.

### 1.4 `SYSTEM1_SHADOW`와 `SYSTEM1_STEP_ROUTING=shadow`의 차이

이름에 둘 다 "shadow"가 들어가지만 기록하는 대상이 다릅니다. 둘 다 켜도 됩니다.

| | `SYSTEM1_SHADOW=true` | `SYSTEM1_STEP_ROUTING=shadow` |
|---|---|---|
| 비교 대상 | **rule ↔ laya**(두 라우터의 판단) | **라우터로 처리 ↔ LLM으로 처리**(단계를 라우터에 맡겼다면) |
| 적용 대상 | 라우터가 호출되는 모든 명령 | 복합 명령의 하위 단계 |
| 로그 | `System1 shadow: {...}` (+ `SYSTEM1_SHADOW_LOG` 파일) | `System1 step gate: {...}` (노드 로그만) |
| 실행 영향 | 없음 | 없음(`on`일 때만 실행 방식이 바뀜) |

### 1.5 권장 조합

| 목적 | `SYSTEM1_ROUTER` | `SYSTEM1_STEP_ROUTING` | `SYSTEM1_SHADOW` |
|---|---|---|---|
| 현재 운영 안정(Laya 사용, 단계는 확인만) | `laya` | `shadow` | `true` |
| 단계까지 빠른 경로 사용 | `laya` | `on` | `true`(전환 초기) |
| Laya를 끄고 규칙으로 롤백 | `rule` | `shadow` 또는 `off` | `false` |
| 복합 명령을 예전처럼 처리 | (무관) | `off` | (무관) |

## 2. 현재 설정 화면 점검 (CLOiD Robot 01, 2026-10-24 스크린샷)

| 항목 | 현재 값 | 문제 | 조치 |
|---|---|---|---|
| Shadow log path (`SYSTEM1_SHADOW_LOG`) | `true` | **켜기/끄기 값이 아니라 파일 경로 칸입니다.** 지금은 로봇이 작업 디렉터리에 `true`라는 파일을 만들어 기록합니다. | 경로를 넣습니다(예: `/ws/agent_workspace/system1_shadow.jsonl`). 파일로 남길 필요가 없으면 비웁니다. |
| Shadow mode (`SYSTEM1_SHADOW`) | 켬 | 문제없음 | — |
| Timeout ms | `2000` | 실측 p95는 약 120~200ms(네트워크 포함)입니다. 동작에는 문제없지만 Laya가 멈추면 요청마다 최대 2초를 기다립니다. | 그림자 기록이 안정되면 `300`~`500`으로 줄이는 것을 권장합니다. |
| Confidence thresholds JSON | `needs_motion` 키 포함 | 최신 기본값과 같습니다. | — |
| Step routing (`SYSTEM1_STEP_ROUTING`) | (필드 없음) | 웹에서 설정할 수 없습니다. 로봇은 기본값 `shadow`로 동작합니다. | 3.1 필드 추가 |

## 3. 변경 요청 (AI Config Server)

### 3.1 [필수] `SYSTEM1_STEP_ROUTING` 필드 추가

| 항목 | 내용 |
|---|---|
| 위치 | System 1 Fast Router 섹션, `System 1 scope` 아래 |
| 형식 | 드롭다운(단일 선택): `off` / `shadow` / `on` |
| 기본값 | `shadow` |
| 라벨(KO) | `Step routing (SYSTEM1_STEP_ROUTING, 선택, 기본: shadow)` |
| 라벨(EN) | `Step routing (SYSTEM1_STEP_ROUTING, optional, default: shadow)` |
| 도움말(KO) | `복합 명령을 분해한 하위 단계에도 사전 라우터를 적용합니다. off: 모든 단계 LLM, shadow: 판정만 기록, on: 혼자 완결되는 단계를 직접 처리.` |
| `.env` 출력 | `SYSTEM1_STEP_ROUTING=<값>`. 값이 비어 있으면 출력하지 않습니다(로봇 기본값 `shadow` 적용). |
| 검증 | `off`, `shadow`, `on` 외의 값은 저장하지 않습니다. 로봇은 잘못된 값을 경고 후 `shadow`로 처리합니다. |

### 3.2 [권장] Shadow log path 입력 개선

| 항목 | 내용 |
|---|---|
| placeholder | `/ws/agent_workspace/system1_shadow.jsonl` |
| 도움말(KO) | `Shadow mode가 켜져 있을 때 비교 기록을 저장할 파일 경로입니다. 비우면 노드 로그에만 남습니다.` |
| 검증 | `true`, `false`, `on`, `off`, `yes`, `no`처럼 켜기/끄기 값으로 보이는 입력은 저장하지 않고 "파일 경로를 입력하세요"를 표시합니다. 절대 경로(`/`로 시작)만 허용하는 것을 권장합니다. |
| 표시 | Shadow mode가 꺼져 있으면 비활성(회색)으로 표시합니다. |

### 3.3 [권장] Shadow mode 도움말 보완

`SYSTEM1_STEP_ROUTING=shadow`와 혼동하지 않도록 Shadow mode 토글에 다음 도움말을 붙입니다.

- KO: `선택되지 않은 라우터(rule ↔ laya)의 판단도 백그라운드로 실행해 비교 기록합니다. 실행에는 영향이 없습니다. rule 모드에서는 System 1 endpoint가 필요합니다.`
- EN: `Also runs the router that is not selected (rule ↔ laya) in the background and records both decisions for comparison. Does not affect execution. Requires the System 1 endpoint in rule mode.`

### 3.4 확인 방법

변경 후 로봇을 다시 기동하면 robo-claw 로그에 다음이 보여야 합니다.

```text
System1 router: router=laya shadow=True scope=readonly endpoint=http://192.168.50.212:8000 local_server=False
System1 step routing: mode=shadow
```

복합 명령을 보내면 단계마다 `System1 step gate: {...}`가 남습니다. `SYSTEM1_SHADOW_LOG`에 경로를 넣었다면 그 파일에 `System1 shadow` 기록이 한 줄씩 쌓입니다.

## 4. 참고 — robo-claw 쪽 처리 (변경 불필요)

- 세 설정 모두 에이전트가 기동할 때 환경변수로 한 번 읽습니다. 바꾼 뒤에는 로봇을 다시 기동해야 반영됩니다.
- 값의 대소문자는 구분하지 않습니다(`ON`, `Shadow` 모두 인식).
- 단계 판정 로그(`System1 step gate`)는 노드 로그에만 남고 `SYSTEM1_SHADOW_LOG` 파일에는 기록하지 않습니다. 파일로도 남겨야 하면 robo-claw 쪽에서 추가하겠습니다.
