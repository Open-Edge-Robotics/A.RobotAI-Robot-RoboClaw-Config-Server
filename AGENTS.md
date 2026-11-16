# AGENTS.md — AI 에이전트를 위한 프로젝트 안내

이 문서는 이 저장소에서 작업하는 **모든 AI 에이전트와 개발자**를 위한 안내다.
코드를 변경하기 전에 반드시 읽어야 한다.

---

## 1. 프로젝트 개요

- **AI Config Server**: 로봇 구동 환경 및 AI 에이전트 설정을 관리·배포하는 서버 + 대시보드.
- 백엔드: **Go + Gin + GORM + SQLite**
- 프론트엔드: **Flutter Web**
- 관리/배포: **Taskfile**(`task`), **Docker**

### 주요 기능

- 로봇/환경별 설정 프로필(`RoboClawConfig`) CRUD, 활성화, 복제
- 테스트 시나리오(`TestScenario`) CRUD, 활성화, 복제
- 로봇 디바이스용 설정 파일(`.env`, Markdown, JSON) 배포
- 이식용 백업 내보내기/가져오기 (`/api/v1/admin/transfer/*`)
- 민감 정보 마스킹, Rate Limit, CORS, 관리자/디바이스 토큰 인증
- SQLite 영속화 + WAL + 시드 데이터(`go:embed`)

---

## 2. 개발 워크플로우

### 반드시 지킬 것: TDD

> 규칙 전체는 **`docs/testing.md`** 를 읽어라. 아래는 핵심 요약.

1. **먼저 실패하는 테스트 작성 → 최소 구현 → 통과 → 리팩터링.**
2. 버그 수정은 재현 테스트부터.
3. API/스키마 변경은 통합(Contract) 테스트부터.
4. 새 비즈니스 규칙은 Service/로직 단위 테스트 필수.

### 검증 명령

```bash
task check          # 전체 검증 (fmt-check, vet, test, analyze, flutter-test) 순차 실행
task test           # go test ./...
task vet            # go vet ./...
task analyze        # flutter analyze
task flutter-test   # flutter test
task test:coverage  # 커버리지
```

**작업이 끝나면 반드시 `task check` 가 모두 통과하는지 확인**한다.

### CI

- 이 프로젝트는 **GitLab** 에서 관리된다. CI 는 저장소 루트의 **`.gitlab-ci.yml`** 를 사용한다.
- MR/기본 브랜치에서 포맷 검사 → vet → 테스트 → 빌드가 순차 실행된다.
- 로컬에서 `task ci` 로 동일한 순서를 재현할 수 있다.

---

## 3. 아키텍처와 테스트 가능 구조

### 현재 구조 (개선 진행 중)

```
cmd/        CLI 명령 (serve 등) — DB·서버 수명 소유, graceful shutdown
config/     설정 바인딩
database/   GORM 열기/마이그레이션/시드 (전역 없음, 호출자가 DB 소유)
handler/    Gin 라우터·미들웨어·HTTP 파싱/응답
service/    runtime 검증·배포 경로 기본값·백업 DTO/검증/적용/트랜잭션
frontend/   Flutter Web (AppDependencies 로 API/Store/파일I/O 주입)
```

> wcli 는 공개 모듈(`github.com/wkqco33/wcli`)로 의존한다. 저장소 내 소스는 두지 않는다.

### 목표 구조

```
cmd/            조립·수명 소유만
handler/        HTTP 계층 (파싱/응답만, 정책은 service 호출)
service/        비즈니스 규칙 (runtime 검증, 배포 기본값, 백업 transfer)
repository/     영속성 인터페이스/구현 (필요한 경계에만)
testutil/       테스트 공용 헬퍼 (DB, HTTP, Fixture)
frontend/lib/api/        주입 가능한 API Client + 중립 ApiException
frontend/lib/features/   기능별 Controller/순수 변환
frontend/lib/widgets/    섹션·폼 위젯 (controller 소유는 ConfigFormFields)
```

### 의존 방향 (궁극 목표)

```
HTTP(handler) → Service → Repository
```

---

## 4. 핵심 테스트 제약 (아직 개선 중)

### 백엔드: 명시적 DB 및 서버 상태 주입

- `database.Init(dsn) (*gorm.DB, error)`는 성공한 DB를 반환하며 전역 DB를 두지 않는다.
- 운영 조립 지점이 DB 연결을 소유하고 닫는다. Handler는 전달받은 DB를 닫지 않는다.
- `handler.NewRouter(cfg, db)`가 서버별 Handler·배포 캐시·rate limiter를 구성한다.
- 테스트는 `NewHandler(db)`와 고유 인메모리 SQLite DSN을 사용하고 `t.Cleanup`으로 DB를 정리한다.
- 독립된 DB·Handler를 사용하는 테스트는 병렬 실행할 수 있다. 다른 전역 설정이나 작업 디렉터리를 변경하는 테스트는 직렬로 유지한다.

### 프론트엔드: 정적 ApiService

- `ApiService`가 `static` 메서드 + `package:web`(LocalStorage)를 직접 사용한다.
- 테스트가 어려우므로 **인스턴스 기반 `ApiClient` + `TokenStore`/`FilePicker`/`Downloader` 추상화**로 전환하는 것이 우선 과제다.
- 테스트에서 `package:web`을 직접 사용하지 않도록 Fake 를 주입한다.

---

## 5. 진행 중인 개선 로드맵

> 다른 에이전트가 작업할 때 여기서 이어받는다.

### 우선순위

1. [x] **`database.DB` 전역 제거** — Handler 생성자로 `*gorm.DB` 주입.
   - `database.Init(dsn) (*gorm.DB, error)`와 `handler.NewRouter(cfg, db)`로 운영·테스트 조립을 명시한다.
   - 서버별 배포 캐시·rate limiter를 사용한다. 캐시 무효화 세대로 오래된 조회의 재삽입을 차단한다.
   - `serve`는 SIGINT/SIGTERM에 graceful shutdown하고, 종료 타임아웃·리스너 오류를 테스트로 고정한다.
   - 남은 자원 작업: Handler 쿼리 외 외부 I/O(GitLab release 조회 등)의 deadline 정리.
2. [x] **Router Factory** — `handler.NewRouter(cfg, db)`로 라우트 중앙화(통합 테스트 가능).
3. [~] **Service 계층 분리** — `service/runtime_validation.go`(runtime 검증)·`service/butler_path_defaults.go`(배포 경로 기본값)·`service/transfer/`(백업 DTO·변환·검증·적용·트랜잭션)로 이동했다. Handler의 기존 타입·함수는 호환 래퍼로 유지한다.
   - `handler/config_transfer.go`는 HTTP 파싱/응답·문서 타입·오류 문구 분기만 담당한다.
   - 남은 작업: Config/Scenario CRUD 규칙(활성 배타성·병합·복제)의 Service 이동.
4. [x] **프론트엔드 API 주입 가능화** — `AdminApi` 인터페이스 + `HttpAdminApi`(http.Client/TokenStore/요청 timeout 주입) 분리 완료.
   - `api/admin_api.dart`, `api/http_admin_api.dart` 추가. `ApiService` 는 얇은 파사드로 전환.
   - `storage/token_store.dart`(인터페이스) + `storage/web_token_store.dart`(브라우저 구현).
   - `platform/file_picker.dart`/`file_downloader.dart`(인터페이스) + web 구현 분리.
   - `main.dart` 에서 운영 인스턴스 구성. `test/api_service_test.dart` 로 MockClient/Fake 검증.
   - 테마 영속화: `storage/theme_mode_store.dart`(인터페이스) + `storage/web_theme_mode_store.dart`(브라우저 구현), `features/theme/theme_controller.dart`, 앱 루트 `app.dart`. 기본 테마는 라이트.
5. [~] **Controller 분리** — `BackupController`(features/backup) 분리·테스트·대시보드 연결 완료. `ScenarioController`(features/scenarios) 분리·테스트·CRUD 전체 이관 완료. `ConfigController`(features/configs) 분리·테스트·CRUD 이관 완료. `ThemeController`(features/theme) 추가.
   - 폼 분리: 순수 변환 `ConfigDraft`/`ConfigFormMapper`, controller 소유권 `ConfigFormFields`, 섹션 렌더링 `ConfigEditorForm`으로 나눠 `config_tab.dart`는 선택·편집 흐름만 담당한다.
   - 목록·loading 상태는 Controller 단일 소스이며 `ListenableBuilder`로 렌더린다. dispose 이후 응답은 알림/`setState`하지 않는다.
   - 남은 작업: Widget 테스트 추가 확충 (에러/엣지 케이스).
6. [x] **커버리지 강화** — Go·Flutter 전체 커버리지 80% 게이트를 로컬 `task check`와 CI에 적용한다. 실제 수치는 실행한 보고서로 확인한다.
7. [x] **CLI 통합 및 Python 의존성 제거** — `scripts/` 파이썬 스크립트를 Go 내장 CLI(`aics contract [check|generate|update]`, `secret-scan`)로 통합 완료. CI/로컬 개발 환경의 Python 3 의존성 완전 제거.
8. [x] **언어 설정 영속화** — `LanguageStore`(인터페이스) + `WebLanguageStore`(localStorage) + `LanguageController`를 테마와 동일한 주입 패턴으로 추가해 새로고침 후에도 선택이 유지된다. 기존 `LanguageManager`/`String.tr`는 전역 어댑터로 호환 유지.
   - 남은 작업: 영어 레이아웃(고정폭 패널) 오버플로 점검, 지원 로케일 확장.

### 주의사항

- wcli 는 공개 모듈(`github.com/wkqco33/wcli`)로 의존한다. **저장소 내 소스/서브모듈을 두지 않는다.**
- 백업 스키마(가져오기/내보내기)는 버전이 바뀌면 **기존 파일 호환성을 반드시 테스트**로 보호한다.
- 민감 정보 마스킹/보존 규칙을 변경할 때는 기존 토큰 보존 테스트를 함께 갱신한다.

---

## 6. 유용한 정보

### API 접두사

- 관리자 API: `/api/v1/admin/...`
- 디바이스 API: `/api/v1/configs/active`, `/api/v1/scenarios/active`
- 백업: `/api/v1/admin/transfer/export`, `/transfer/import/validate`, `/transfer/import`

### 인증

- `Authorization: Bearer <token>` 헤더 사용.
- 설정 파일: `config.yaml` 또는 환경변수(`AI_CONFIG_SERVER_` 접두사).

### 빌드/실행

```bash
task deps
task build        # build-web + build-server
task run          # ./aics serve
task docker-build
task docker-run
```

### 테스트 실행 명령 모음

```bash
task test           # Go 단위 테스트
task flutter-test   # Flutter 테스트
task test:coverage  # 커버리지
task check           # 전체 게이트
```

## 7. Shared Configuration Contract

공통 runtime 설정의 source of truth는 `rcf-config-contract` GitLab Release다.
이 저장소는 `contracts/contract.lock.json`의 version과 checksum을 pin하고, 자체
vendored contract에서 Dart/schema artifact를 생성한다.

### 생성과 검증

```bash
go run . contract check
go run . contract generate --check
go run . contract update --from /path/to/release-bundle/generated
go run . contract generate --check
task contract-check
task frontend-contract
```

생성 파일은 직접 수정하지 않는다.

- `frontend/lib/models/runtime_config_contract.g.dart`
- `schemas/robo-claw-runtime-config-v2.schema.json`

공통 설정을 추가하거나 변경할 때는 contract 저장소에서 release를 만든 뒤 다음
순서로 이 저장소를 갱신한다.

```bash
go run . contract check
go run . contract update --from /path/to/release-bundle/generated
go run . contract generate
task contract-check
task frontend-contract
task check
```

### Profile과 Contract 구분

- runtime contract: 공통 type/default/secret/env/API/ROS mapping
- profile DB: robot/environment별 실제 값
- robot YAML: 특정 로봇의 hardware/topic/manipulation 값
- server config: AI Config Server 자체 host/DB/auth 설정

runtime contract field를 DB model이나 Flutter model에 수동으로만 추가하지 않는다.
Registry release와 generated contract test를 함께 갱신해야 한다.

### Secret 규칙

- contract artifact에 실제 credential을 저장하지 않는다.
- `secret: true` field의 default는 빈 값만 허용한다.
- API JSON response는 masking 상태를 유지한다.
- `.env`는 실행에 필요한 secret 전달 경로이므로 cache/file 권한을 확인한다.

### 독립 저장소 원칙

AI Config Server는 RoboClaw sibling 경로를 참조하지 않는다. `contracts/`와 lock만
사용해 schema/Dart generation과 contract 검증이 가능해야 한다.
