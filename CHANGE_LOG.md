# CHANGE_LOG

## [Unreleased]

### 추가됨
- **System 1 Fast Router 설정**: 공통 runtime contract v2.4.0의 `SYSTEM1_*` 11개 필드를 Go 프로필/API/백업, 배포 `.env`, Flutter 설정 폼에 반영했다.
  - `SYSTEM1_API_KEY`는 API 응답에서 마스킹하고, 편집 시 기존 키를 보존하며 백업의 secret 포함 옵션을 따르도록 했다.
  - timeout, option count, confidence threshold JSON 유효성 검증과 런타임 manifest field coverage 테스트를 추가했다.
- **LangSmith workspace ID 설정**: 공통 runtime contract v2.3.0을 반영하고, 프로필 모델/API/백업/배포 `.env`와 Flutter 설정 폼에 `LANGSMITH_WORKSPACE_ID` 입력 및 round-trip 지원을 추가했다.

## [0.4.4] - 2026-09-23

### 추가됨
- **공통 runtime contract v2.2.0 반영 (Maestro FleetControl outbound connector)**:
  - `contracts/contract.lock.json`을 `v2.2.0`(checksum `0682a285…`/`954140a7…`)으로 갱신하고 `schemas/schema-lock.json`과 Dart artifact를 재생성.
  - `fleet.*` field 15개를 계약에 맞춰 전 계층에 반영:
    - `database/models/roboclaw_config.go`: DB/API field 및 기본값(`robot_port=50053`, `robot_map_frame_id=map`, `maestro_disconnect_policy=complete`, `fleet_heartbeat_sec=1.0`, `fleet_command_journal_path=/tmp/robo_claw_fleet_commands.sqlite3`).
    - `handler/roboclaw_config.go`: `maestro_disconnect_policy` enum, `robot_port` 범위, `fleet_heartbeat_sec` 음수, `maestro_ip` 설정 시 `robot_id` 필수 검증.
    - `handler/config_files.go`: `.env` 매핑(`MAESTRO_IP`, `ROBOT_PORT`, `ROBOT_ID`, `ROBOT_SITE_ID`, `ROBOT_MAP_ID`, `ROBOT_MAP_VERSION`, `ROBOT_MAP_FRAME_ID`, `MAESTRO_DISCONNECT_POLICY`, `FLEET_HEARTBEAT_SEC`, `FLEET_COMMAND_JOURNAL_PATH`, `RC_SKILLS_GUIDE_FILE`, `FLEET_CONTROL_TLS`, `FLEET_CONTROL_CA_CERT`, `FLEET_CONTROL_CLIENT_CERT`, `FLEET_CONTROL_CLIENT_KEY`).
    - `handler/config_transfer.go`: 백업 export/import round-trip 보존.
    - `frontend/lib/models/config_model.dart` 및 `frontend/lib/widgets/config_fleet_section.dart`, `frontend/lib/screens/config_tab.dart`: 모델/폼/섹션 UI 연결.
  - 계약 기본값과 `RoboClawConfig.toJson()` 전체 field coverage 검증 테스트를 갱신.

## [0.4.3] - 2026-09-10

### 추가됨
- **Go 내장 CLI 커맨드로 계약/보안 검증 통합**:
  - `ai-config-server contract check`: `contract.lock.json`, `schema-lock.json`, Flutter Dart 아티팩트 staleness 무결성 검증.
  - `ai-config-server contract generate [--check]`: Vendored runtime contract로부터 Flutter Dart 모델(`runtime_config_contract.g.dart`) 자동 생성 및 검증.
  - `ai-config-server contract update --from <bundle>`: 릴리스 번들로부터 contract 갱신 및 lock 파일 생성.
  - `ai-config-server secret-scan`: Git 추적 파일 대상 시크릿/토큰 패턴 검사.

### 변경됨
- **Python 3 의존성 완전 제거 및 단일 언어 스택 통일**:
  - `scripts/` 내 5개 파이썬 스크립트(`check-contract-lock.py`, `check-schema-lock.py`, `check-secrets.py`, `generate-contract-artifacts.py`, `update-contract.py`)를 Go 패키지(`internal/contract`, `internal/secretscan`) 및 CLI 커맨드로 전환하고 스크립트 디렉터리 정리.
  - CI 파이프라인(`.gitlab-ci.yml`), Taskfile(`Taskfile.yml`), pre-commit hook(`.githooks/pre-commit`)에서 Python 호출을 Go CLI로 교체하고 `apk add python3` 제거.
  - 백엔드 테스트 커버리지 80.7% 달성.

## [0.4.2] - 2026-06-23

### 변경됨
- **프론트엔드 대시보드 리팩토링 및 위젯 분리**:
  - [dashboard_screen.dart](file:///home/wkqco/Workspace/works/ai-config-server/frontend/lib/screens/dashboard_screen.dart)의 비대한 비즈니스 로직과 UI 코드를 탭 단위로 완전히 분리.
  - 설정(Configs) 관리를 담당하는 [config_tab.dart](file:///home/wkqco/Workspace/works/ai-config-server/frontend/lib/screens/config_tab.dart)와 시나리오(Scenarios) 관리를 담당하는 [scenario_tab.dart](file:///home/wkqco/Workspace/works/ai-config-server/frontend/lib/screens/scenario_tab.dart)를 각각 독립된 `StatefulWidget`으로 추출.
  - [dashboard_screen.dart](file:///home/wkqco/Workspace/works/ai-config-server/frontend/lib/screens/dashboard_screen.dart)는 `NavigationRail`과 `AppBar` 쉘 구성 및 `GlobalKey`를 이용한 새로고침 관리 역할만 수행하도록 간소화(코드 라인 수가 약 2,900라인에서 약 200라인 수준으로 90% 이상 감소).
  - 기존 탭 전환 시 화면 재생성으로 인한 입력 정보 유실 문제를 개선하기 위해 `IndexedStack` 레이아웃 구조를 적용하여 UI 상태 유지 능력 개선.
  - 각 탭 내의 목록 조회 및 검색 영역을 [config_list_panel.dart](file:///home/wkqco/Workspace/works/ai-config-server/frontend/lib/widgets/config_list_panel.dart)와 [scenario_list_panel.dart](file:///home/wkqco/Workspace/works/ai-config-server/frontend/lib/widgets/scenario_list_panel.dart)로 추출하여 모듈화.
  - 설정 폼의 40여 개 필드를 9개의 테마 섹션 위젯으로 쪼개어 [config_form_sections.dart](file:///home/wkqco/Workspace/works/ai-config-server/frontend/lib/widgets/config_form_sections.dart)로 분리하고, 부모 탭 위젯의 복잡성 완화([config_tab.dart](file:///home/wkqco/Workspace/works/ai-config-server/frontend/lib/screens/config_tab.dart) 라인 수가 **1,800라인**에서 **950라인**으로 대폭 감소).

## [0.4.1] - 2026-06-17

### 추가됨
- **시나리오 테스트 케이스 GUI 입력 폼 개선**:
  - 테스트 케이스 시각화 편집용 [TestCaseListEditor](file:///home/seoyc/Workspace/server/ai-config-server/frontend/lib/widgets/test_case_list_editor.dart) 위젯 신규 개발.
  - 드래그 앤 드롭 정렬(`ReorderableListView`), 카드 형태의 테스트 케이스 목록 관리, 유형별 맞춤형 파라미터(`params`) 입력창 지원.
  - GUI 폼 모드와 JSON 텍스트 에디터 모드를 상호 전환할 수 있는 하이브리드 모드 통합 및 상태 동기화 로직 구현 ([dashboard_screen.dart](file:///home/seoyc/Workspace/server/ai-config-server/frontend/lib/screens/dashboard_screen.dart)).

- **CLI 이미지/지도 파일 수신 테스트 신뢰성 개선 (Retry 메커니즘)**:
  - AI 에이전트로부터 이미지 파일명 검출을 시도하는 정규식 패턴(`rxScene`, `rxMap`)을 개선하여 복잡한 영숫자 해시, 타임스탬프, UUID 등 유연한 포맷에 대처 가능하도록 개선.
  - 비동기 이미지 캡처/파일 I/O 지연으로 인한 다운로드 실패(레이스 컨디션) 문제를 보완하기 위해 최대 3회(1.5초 간격) 동안 파일을 재수신하는 `downloadFileWithRetry` 메커니즘을 [tester/handlers.go](file:///home/seoyc/Workspace/ros/robo_claw/robo_claw_cli/tester/handlers.go)에 도입.

- **보고서 이미지 자동 첨부 및 보관 기능 추가**:
  - `TestStepResult` 데이터 구조에 `ImagePath` 필드를 추가하여 획득된 로컬 이미지 경로의 생명주기 관리 연동 ([types.go](file:///home/seoyc/Workspace/ros/robo_claw/robo_claw_cli/tester/types.go)).
  - 카메라 획득(`runCamera`), 카메라/지도 분석 스킬(`runCameraAnalysis`, `runMapAnalysis`) 단계에서 획득되거나 다운로드받은 이미지 파일 바이트 데이터를 로컬 디바이스의 `report_images/` 디렉토리에 물리 파일로 영구 저장하도록 구현 ([handlers.go](file:///home/seoyc/Workspace/ros/robo_claw/robo_claw_cli/tester/handlers.go)).
  - 최종 마크다운 보고서 생성 시, 이미지 데이터를 보유한 테스트 스텝에 한해 표의 상세 내역란에 `<img>` 태그(가로 300px 스펙)를 동적으로 생성하여 첨부하도록 [report.go](file:///home/seoyc/Workspace/ros/robo_claw/robo_claw_cli/tester/report.go)의 보고서 라이터 고도화.

## [0.4.0] - 2026-06-12

### 추가됨
- **테스트 시나리오 웹 관리 및 CLI 연동**:
  - **테스트 시나리오 GORM 모델 (`TestScenario`) 추가**: SQLite DB에 시나리오와 개별 TestCase 목록을 구조화하여 저장할 수 있는 스키마 정의 및 GORM AutoMigrate 연동 ([database/models/test_scenario.go](file:///home/seoyc/Workspace/server/ai-config-server/database/models/test_scenario.go)).
  - **디폴트 시나리오 시드 자동화**: 최초 DB 생성 시 `butler`(office) 및 `former`(factory)를 위한 표준 시나리오 데이터를 자동으로 시드하도록 [database/db.go](file:///home/seoyc/Workspace/server/ai-config-server/database/db.go) 리팩토링.
  - **REST API 구현**:
    - `GET /api/v1/scenarios` : 시나리오 목록 조회
    - `GET /api/v1/scenarios/:id` : 시나리오 상세 조회
    - `POST /api/v1/scenarios` : 신규 시나리오 등록
    - `PUT /api/v1/scenarios/:id` : 시나리오 수정
    - `DELETE /api/v1/scenarios/:id` : 시나리오 삭제
    - `POST /api/v1/scenarios/:id/activate` : 특정 시나리오 활성화
    - `GET /api/v1/scenarios/active` : 특정 로봇/환경의 활성 시나리오 반환 (디바이스/CLI 용)
    - 구현 소스: [handler/test_scenario.go](file:///home/seoyc/Workspace/server/ai-config-server/handler/test_scenario.go), 라우터 연동: [cmd/serve.go](file:///home/seoyc/Workspace/server/ai-config-server/cmd/serve.go).
  - **Flutter Web 대시보드 시나리오 연동**:
    - [dashboard_screen.dart](file:///home/seoyc/Workspace/server/ai-config-server/frontend/lib/screens/dashboard_screen.dart)에 `NavigationRail` 레이아웃을 도입하여 설정 관리와 시나리오 관리를 분리.
    - JSON TestCase를 직접 편집할 수 있는 JSON 텍스트 에디터 UI 및 문법 유효성 검증 제공.
    - 시나리오 목록 카드 [widgets/scenario_card.dart](file:///home/seoyc/Workspace/server/ai-config-server/frontend/lib/widgets/scenario_card.dart) 및 데이터 모델 [models/scenario_model.dart](file:///home/seoyc/Workspace/server/ai-config-server/frontend/lib/models/scenario_model.dart) 구현.
  - **CLI (`robo_claw_cli`) 연동 기능 추가**:
    - [cmd/test.go](file:///home/seoyc/Workspace/ros/robo_claw/robo_claw_cli/cmd/test.go) 내 시나리오 획득 흐름 개선. `--scenario-file` 매개변수가 없을 때, 서버 API(`/api/v1/scenarios/active`)를 호출하여 원격 활성 시나리오를 동기화하고 로컬 캐시 폴더(`~/.robo_claw/config_cache/`)에 `scenario.json` 형태로 캐싱.
    - 서버 동기화 실패 시 로컬 캐시를 로딩하며, 캐시조차 없는 경우 내장 기본 테스트 시나리오로 순차 폴백하도록 고도화.

## [0.3.0] - 2026-06-08

### 추가됨
- **Static Token 기반 API 인증 및 인가**:
  - `admin_token`(대시보드 권한) 및 `device_token`(로봇 디바이스 읽기 권한) 검증 미들웨어([handler/auth.go](file:///home/seoyc/Workspace/server/ai-config-server/handler/auth.go)) 추가.
  - [cmd/serve.go](file:///home/seoyc/Workspace/server/ai-config-server/cmd/serve.go)의 각 API 엔드포인트 그룹(대시보드 CRUD / 디바이스 배포)에 인증 미들웨어 적용.
- **민감 데이터 마스킹 (Data Masking)**:
  - 대시보드 API 응답 시 API Key 등의 자격 증명 정보를 마스킹(`********`)하여 전달하도록 처리 ([handler/roboclaw_config.go](file:///home/seoyc/Workspace/server/ai-config-server/handler/roboclaw_config.go)).
  - 수정 API 호출 시 마스킹된 문자열이 그대로 넘어올 경우 기존 DB의 원본 키를 유지하도록 로직 보완.
- **CORS 제한 미들웨어**:
  - [handler/cors.go](file:///home/seoyc/Workspace/server/ai-config-server/handler/cors.go)에 가볍고 효율적인 CORS 미들웨어를 추가하여, [config.yaml](file:///home/seoyc/Workspace/server/ai-config-server/config.yaml)에 설정된 Origin 목록에 맞춰 크로스 오리진 요청을 안전하게 제어.
- **초경량 인메모리 요청 제한 (Rate Limiting)**:
  - 외부 의존성 없이 IP 기반 토큰 버킷 알고리즘을 바닐라 Go로 직접 구현 ([handler/ratelimit.go](file:///home/seoyc/Workspace/server/ai-config-server/handler/ratelimit.go)).
  - 백그라운드 고루틴을 통해 10분 주기로 1시간 이상 유휴 상태인 IP 버킷 인스턴스를 소거하여 메모리 관리 최적화.
- **SQLite WAL 모드 적용 및 커넥션 풀 튜닝**:
  - [database/db.go](file:///home/seoyc/Workspace/server/ai-config-server/database/db.go)의 SQLite 드라이버 연결부에 WAL(Write-Ahead Logging) 모드 설정 및 `MaxOpenConns(1)` 설정을 추가하여 동시성 DB 락 이슈 예방.
- **Kubernetes 배포 사양 고도화**:
  - [kube/deployment.yaml](file:///home/seoyc/Workspace/server/ai-config-server/kube/deployment.yaml)에 Liveness/Readiness Probe(헬스체크) 및 CPU/Memory 리소스 제한(Requests/Limits) 설정을 보완하여 오작동 및 노드 부하 최소화.
- **환경변수 키 네이밍 리팩토링**:
  - 하이픈이 포함되어 오동작 가능성이 높던 접두사 및 환경변수 키 명칭을 `AI_CONFIG_SERVER_` 규격의 언더스코어로 전면 교체 ([cmd/root.go](file:///home/seoyc/Workspace/server/ai-config-server/cmd/root.go), [Dockerfile](file:///home/seoyc/Workspace/server/ai-config-server/Dockerfile), [README.md](file:///home/seoyc/Workspace/server/ai-config-server/README.md) 등).
- **시드 파일 내장화 (go:embed)**:
  - 호스트의 개발 절대 경로 하드코딩을 제거하고, [database/seeds](file:///home/seoyc/Workspace/server/ai-config-server/database/seeds) 디렉토리를 생성하여 컴파일 시점에 바이너리 내부로 시드 데이터를 안전하게 결합시킴.
- **단위 테스트 코드 작성**:
  - API 헬스체크 및 관리자 인증 미들웨어를 신속하게 자동 검증하기 위한 초경량 통합 테스트 코드 [handler/handler_test.go](file:///home/seoyc/Workspace/server/ai-config-server/handler/handler_test.go) 구현.
- **GORM 기본 트랜잭션 비활성화**:
  - [database/db.go](file:///home/seoyc/Workspace/server/ai-config-server/database/db.go)의 `gorm.Open` 설정 시 `SkipDefaultTransaction: true` 설정을 적용하여 무의미한 I/O 쓰기 대기 및 트랜잭션 오버헤드 최적화.
- **로봇 배포 인메모리 캐싱 (Active Cache)**:
  - 다수 로봇 동시 구동 시 디바이스 활성 설정 및 파일 다운로드 요청에 대해 DB 부하와 연산 비용을 제거하기 위해 [handler/roboclaw_config.go](file:///home/seoyc/Workspace/server/ai-config-server/handler/roboclaw_config.go)에 초경량 `activeCache` 연동. 관리자 제어 시 캐시 무효화(`clearActiveCache()`) 처리.
- **데이터 무결성 검증 (JSON Validation)**:
  - 설정 생성 및 수정 시 `LimitsContent` 및 `OllamaOptionsJson` 필드의 JSON 규격 무결성을 검사하는 `validateJSONFields` 헬퍼 함수를 추가하고, 이를 검증하는 단위 테스트 케이스를 [handler/handler_test.go](file:///home/seoyc/Workspace/server/ai-config-server/handler/handler_test.go)에 작성.

## [0.2.1] - 2026-06-05

### 변경됨
- **쿠버네티스 타임존 동기화**: [deployment.yaml](file:///home/seoyc/Workspace/server/ai-config-server/kube/deployment.yaml) 파일에 호스트의 `/etc/localtime` 볼륨 마운트 설정을 추가하여, 배포된 컨테이너의 로그 시간대가 서버 PC(호스트)의 시간대와 일치하도록 개선.

## [0.2.0] - 2026-06-02

### 추가됨
- **AI 에이전트 GORM 모델 (`RoboClawConfig`)**: 로봇 및 환경별 AI 에이전트 설정(개성, 스킬, 장애 조치 마크다운 파일 및 `.env` 환경변수 정보)을 관리하는 스키마 추가.
- **REST API 구현**:
  - `GET /api/v1/configs` : 설정 목록 조회
  - `GET /api/v1/configs/:id` : 특정 설정 조회
  - `POST /api/v1/configs` : 신규 설정 등록
  - `PUT /api/v1/configs/:id` : 설정 수정
  - `DELETE /api/v1/configs/:id` : 설정 삭제
  - `POST /api/v1/configs/:id/activate` : 특정 로봇/환경에서 사용할 활성(Active) 설정 지정
  - `GET /api/v1/configs/active` : 로봇명/환경별 활성화된 설정 JSON 조회
  - `GET /api/v1/configs/active/files/:filename` : 활성화된 설정의 특정 개별 파일(`.env`, `ROBOT.md`, `SKILLS.md`, `TROUBLESHOOTING.md`, `ROBOT_LIMITS.json`) 물리 텍스트/파일 스트림 다운로드 지원
  - `GET /ping` : 서버 구동 및 접속 상태 테스트용 헬스체크 API
- **데이터베이스 시드(Seed) 기능**: 최초 서버 구동 시, 로컬 `robo_claw` 패키지의 기존 설정 파일들을 스캔하여 자동으로 `butler`(office) 및 `former`(factory) 초기 데이터가 삽입되도록 구현.
- **Flutter Web 대시보드 클라이언트**:
  - `frontend` 디렉토리에 Flutter 3.44.1 기반 웹 프로젝트 생성.
  - 로봇/환경별 설정 필터링, 활성화 제어 및 CRUD UI 구현.
  - 마크다운 개별 탭 텍스트 에디터를 내장하여 웹 대시보드 상에서 직접 설정 콘텐츠 수정 가능.
  - 아코디언/익스팬션 스타일의 직관적인 `.env` 변수 설정 폼 제공.
  - 백엔드 Gin 서버의 `/` 및 `/web` 경로로 정적 리소스 통합 서빙 연동.
  - **설정 파일 내보내기 (Export) 기능**: 상세 설정 화면 우측 상단에 다운로드 버튼(`PopupMenuButton`)을 제공하여 개별 마크다운 파일 및 자동으로 구성된 `.env` 설정 파일을 즉시 로컬 파일로 다운로드할 수 있는 기능 추가.
  - **압축 일괄 내보내기 기능**: `archive` 라이브러리를 임포트하여 전체 설정 파일(`.env`, `ROBOT.md`, `SKILLS.md`, `TROUBLESHOOTING.md`, `ROBOT_LIMITS.json`)들을 브라우저 메모리상에서 단일 zip 파일로 실시간 패킹 및 일괄 다운로드하는 **'모두 받기 (ZIP)'** 항목 신설.
- **서버 에러 핸들링 및 로깅 체계화**:
  - `handler/error.go` 내에 중앙 에러 로깅 및 표준 JSON 응답을 전담하는 `LogAndRespondError` 헬퍼 유틸리티 구현.
  - API 실패 시 콘솔/로그 파일에 에러 세부 스택과 메타데이터(URL, Method 등)를 `LevelError` 수준으로 구조화하여 출력.
  - 클라이언트에게 구조화된 일관성 있는 `APIErrorResponse` 포맷으로 예외 리턴 지원.
  - 모든 비즈니스 API 성공 지점에 정보성 로깅(`LogInfo`)을 연동하여 시스템 가관측성(Observability) 확보.

### 제거됨
- 기존 템플릿에 포함되어 있던 헬로월드(`GET /hello`) 및 예제 코드(`GET/POST/DELETE /examples` 핸들러, `models.Example` 모델 구조체)를 완전히 삭제하여 프로젝트를 청결하게 유지합니다.


