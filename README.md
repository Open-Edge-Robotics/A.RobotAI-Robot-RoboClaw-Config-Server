# AI Config Server

로봇 구동(Bringup) 환경 및 AI 에이전트 실행에 필요한 설정(개성, 스킬 가이드, 장애 조치, 하드웨어 제약 설정)과 환경 변수(.env) 및 테스트 시나리오를 로봇 및 구동 환경별로 관리하고 배포하는 설정 서버 및 대시보드 클라이언트입니다.

---

## 주요 기능 및 구성

- **설정 및 테스트 시나리오 관리 대시보드 (Flutter Web)**:
  - 로봇/환경별 설정을 웹 인터페이스를 통해 CRUD 관리할 수 있습니다.
  - 테스트 시나리오와 개별 테스트 케이스들을 GUI 기반의 폼 에디터(드래그 앤 드롭 순서 정렬 및 유형별 동적 매개변수 입력 폼 포함) 또는 하이브리드 형식의 JSON 텍스트 에디터를 통해 간편하게 편집·활성화할 수 있습니다.
  - Static Admin Token 보안이 설정된 경우 우측 상단 열쇠 아이콘을 눌러 인증 토큰을 설정·보존(LocalStorage)할 수 있습니다.
- **설정 및 시나리오 배포 API (Go & Gin)**: 로봇 디바이스 구동 시점에 동적으로 설정 값 및 관련 설정 파일(.env, 마크다운, JSON)과 활성화된 테스트 시나리오를 다운로드할 수 있습니다.
- **보안 및 트래픽 제어**:
  - **민감 데이터 마스킹 (Data Masking)**: API Key 등의 민감 정보를 조회 API 응답 시 마스킹(`********`)하여 반환합니다. 수정 API 호출 시 마스킹된 문자열이 그대로 전달되면 DB의 원본 값을 유지합니다.
  - **초경량 요청 제한 (Rate Limiting)**: 외부 의존성 없이 IP 기반의 토큰 버킷 알고리즘을 활용한 Rate Limiter를 적용하여 비정상적인 트래픽 폭주로부터 서버를 보호합니다.
  - **CORS 제한**: 설정된 오리진(Origin) 목록에 맞춘 효율적인 CORS 제어 미들웨어가 내장되어 안전하게 외부 요청을 제어합니다.
- **성능 최적화 및 안정성**:
  - **인메모리 캐싱 (Active Cache)**: 다수의 로봇이 동시에 설정을 요청할 때 발생하는 DB 부하를 예방하기 위해 디바이스용 배포 API에 대해 초경량 캐시(`activeCache`)를 연동하고, 설정 변경 시 즉시 캐시를 무효화합니다.
  - **SQLite 성능 튜닝**: WAL(Write-Ahead Logging) 모드를 적용하고 커넥션 풀을 1개로 제어하여 동시성 DB 락(Lock) 이슈를 예방하였습니다. 또한 GORM 기본 트랜잭션을 비활성화하여 오버헤드를 줄였습니다.
  - **설정 취약점 경고**: 서버 시작 시 관리자/디바이스 토큰이 기본값(Insecure Defaults)으로 비어있거나 CORS 설정이 취약한 경우 콘솔에 1회 보안 경고 배너를 출력합니다.
- **SQLite 영속화**: 단일 SQLite 데이터베이스 파일(`ai-config-server.db`)을 사용하며, 최초 구동 시 기본 시드 데이터가 자동 생성됩니다.
  - 개발자의 절대 경로 하드코딩 없이 바이너리 빌드에 시드 데이터를 포함하는 `go:embed` 방식을 적용하였습니다.
- **이식용 백업 내보내기/가져오기**: 설정 프로필과 테스트 시나리오 전체를 단일 JSON 파일로 내보내거나 가져와 다른 서버로 손쉽게 이전할 수 있습니다.
  - 민감 정보(API Key, 토큰, MCP 서버 설정)는 기본적으로 제외되며, 필요 시 옵션으로 포함할 수 있습니다.
  - 가져오기 시 충돌 처리 정책(건너뛰기/덮어쓰기/복사본 생성)과 활성 상태 정책(전체 비활성/내보낸 상태 유지/기존 상태 유지)을 선택할 수 있습니다.

---

## 빌드 및 실행 방법

이 프로젝트는 빌드 및 관리를 위해 [Taskfile](https://taskfile.dev)을 사용합니다. 사전에 `task` CLI를 설치해야 합니다.

### Task 설치

| 환경/도구        | 명령                                                         |
| ---------------- | ------------------------------------------------------------ |
| macOS (Homebrew) | `brew install go-task/tap/go-task`                           |
| Linux            | `sh -c "$(curl --location https://taskfile.dev/install.sh)"` |
| Windows (Scoop)  | `scoop install task`                                         |
| Node.js (npm)    | `npm install -g @go-task/cli`                                |
| Go 설치 환경     | `go install github.com/go-task/task/v3/cmd/task@latest`      |

설치 확인: `task --version`

> [!TIP]
> **전역 설치 없이 실행하기 (Node.js 환경)**:
> 시스템에 `task`를 설치하지 않고 일회성으로 가동하려면 `npx @go-task/cli <태스크명>` (예: `npx @go-task/cli deps`) 명령어로 대체하여 실행할 수 있습니다.

### 1. Taskfile을 이용한 빌드 및 실행

사용 가능한 작업 목록은 `task` (또는 `task --list`)로 확인할 수 있습니다.

- **의존성 설치**:
  ```bash
  task deps
  ```
- **프론트엔드 및 백엔드 통합 빌드**:
  ```bash
  task build
  ```
- **서버 실행**:
  ```bash
  task run
  ```
- **빌드 산출물 및 캐시 정리**:
  ```bash
  task clean
  ```

### 2. 수동 빌드 및 실행

#### 프론트엔드 (Flutter Web) 빌드

대시보드의 SPA 라우팅 경로 제공을 위해 `--base-href "/web/"` 옵션을 지정하여 빌드해야 합니다.

```bash
cd frontend
flutter pub get
flutter build web --base-href "/web/" --release
```

#### 백엔드 (Go Server) 빌드 및 실행

```bash
# 빌드
go build -o aics .

# 서버 실행 (serve 서브커맨드 사용)
./aics serve
```

- 기본 포트인 `http://localhost:8080`에 접속하면 `/web/` 대시보드로 자동 리다이렉트됩니다.
- CLI 명령어 목록:
  - `serve`: HTTP API 및 대시보드 서버를 시작합니다.
  - `version`: 서버 바이너리의 버전을 출력합니다.
  - `completion`: 셸 컴플리션 스크립트를 생성합니다.

### 3. Docker 기반 빌드 및 실행

Docker 멀티 스테이지 빌드를 통해 컴파일 환경 없이 구동할 수 있습니다. 빌드 시 최종 Alpine 스테이지에 `tzdata`가 추가 설치되고 `Asia/Seoul` 시간대로 자동 동기화됩니다.

- **이미지 빌드**:
  ```bash
  task docker-build
  ```
- **컨테이너 실행 (볼륨 마운트 및 포트 바인딩)**:
  ```bash
  task docker-run
  ```
  작업 디렉토리 하위의 `data/` 디렉토리를 컨테이너 내부의 `/app/data`로 볼륨 마운트하여 SQLite 데이터베이스를 보존합니다.
- **컨테이너 정지 및 리소스 삭제**:
  ```bash
  task docker-stop
  ```

### 4. 단위 테스트 실행

서버 백엔드의 인증 미들웨어, Rate Limit, 데이터 마스킹, JSON 유효성 검증 등의 비즈니스 로직을 검증하기 위한 테스트를 실행할 수 있습니다.

```bash
go test ./...
```

---

## 설정 정보 (`config.yaml` / 환경변수)

RoboClaw profile 작성과 로봇 실행 절차는 [docs/CONFIGURATION_GUIDE.md](docs/CONFIGURATION_GUIDE.md)를 참고하세요.

공통 runtime contract의 version/checksum과 Dart artifact 생성 절차도 해당
configuration guide 및 `contracts/contract.lock.json`을 확인하세요.

`config.example.yaml`을 복사하여 `config.yaml`을 생성하거나 환경변수를 사용하여 서버 설정을 구성할 수 있습니다. (`config.yaml`은 민감 정보 보호를 위해 `.gitignore`에 등록되어 있습니다.) 시스템 환경변수가 우선 적용되며, 접두사는 `AI_CONFIG_SERVER_`입니다.

| 설정 키                         | 환경변수명                                       | 기본값                | 설명                                   |
| ------------------------------- | ------------------------------------------------ | --------------------- | -------------------------------------- |
| `server.host`                   | `AI_CONFIG_SERVER_SERVER_HOST`                   | `0.0.0.0`             | 서버 바인딩 호스트                     |
| `server.port`                   | `AI_CONFIG_SERVER_SERVER_PORT`                   | `8080`                | 서버 포트                              |
| `log.level`                     | `AI_CONFIG_SERVER_LOG_LEVEL`                     | `info`                | 로그 출력 레벨                         |
| `database.path`                 | `AI_CONFIG_SERVER_DATABASE_PATH`                 | `ai-config-server.db` | SQLite 파일 경로                       |
| `security.admin_token`          | `AI_CONFIG_SERVER_SECURITY_ADMIN_TOKEN`          | `""`                  | 대시보드/시나리오 편집용 관리자 토큰   |
| `security.device_token`         | `AI_CONFIG_SERVER_SECURITY_DEVICE_TOKEN`         | `""`                  | 로봇 디바이스 배포 API 전용 토큰       |
| `security.require_auth`         | `AI_CONFIG_SERVER_SECURITY_REQUIRE_AUTH`         | `true`                | 운영 환경 인증 강제 (비활성화 금지)    |
| `security.cors_allowed_origins` | `AI_CONFIG_SERVER_SECURITY_CORS_ALLOWED_ORIGINS` | `[]`                  | HTTPS CORS 허용 오리진 목록 (`*` 금지) |

---

## SQLite 초기 데이터 구성 (Seed)

최초 실행 시 `ai-config-server.db` 파일이 생성되면서 아래 경로의 로컬 설정 파일 내용을 탐색하여 자동으로 시드 데이터를 채웁니다.

- **설정 및 시나리오 시드**:
  - `butler` (사무실 환경) 및 `former` (공장 환경) 로봇 설정 프로필 자동 인입.
  - `butler`, `former`, `default`(공통 기본형) 3종의 기본 자동화 테스트 시나리오가 활성화된 상태로 자동 등록됩니다.

---

## API 규격 및 인증

모든 REST API 경로는 `/api/v1` 접두사를 사용합니다. 운영 서버에서는 최소 32자 이상의 관리자/디바이스 토큰을 반드시 설정해야 하며, HTTP 요청 헤더에 **`Authorization: Bearer <토큰>`** 규격을 포함해야 합니다. 토큰 또는 HTTPS CORS Origin이 누락되면 서버가 시작되지 않습니다.

### 1. 설정 관리 API (대시보드용, `admin_token` 필요)

- **목록 조회**: `GET /api/v1/configs` (필터: `robot_name`, `environment`)
- **상세 조회**: `GET /api/v1/configs/:id`
- **설정 파일 조회**: `GET /api/v1/configs/:id/files/:filename` (특정 설정 프로필에 포함된 개별 설정 파일의 원본 콘텐츠 획득)
- **설정 생성**: `POST /api/v1/configs`
  - _`LimitsContent` 및 `OllamaOptionsJson` 필드는 자동으로 JSON 무결성 유효성 검증을 거칩니다._
- **설정 수정**: `PUT /api/v1/configs/:id`
  - _자격 증명 등의 민감 데이터는 `********`로 마스킹되어 있어, 수정 시 해당 마스크 값이 전송되면 DB의 기존 원본 값을 안전하게 유지합니다._
- **설정 삭제**: `DELETE /api/v1/configs/:id`
- **설정 복제**: `POST /api/v1/configs/:id/clone`
- **설정 활성화**: `POST /api/v1/configs/:id/activate`

### 이식용 백업 API (대시보드용, `admin_token` 필요)

- **백업 내보내기**: `GET /api/v1/admin/transfer/export` (쿼리: `include_secrets`, `include_configs`, `include_scenarios`) 또는 `POST /api/v1/admin/transfer/export`
  - 설정 프로필과 테스트 시나리오를 이식용 JSON 파일로 내보냅니다.
  - `include_secrets=true` 시 API Key/토큰/MCP 서버 설정이 평문으로 포함됩니다.
- **백업 검증**: `POST /api/v1/admin/transfer/import/validate`
  - 업로드 전 스키마 버전, 필수 필드, 중첩 JSON 무결성, 기존 데이터와의 충돌 여부를 검사합니다.
- **백업 가져오기**: `POST /api/v1/admin/transfer/import`
  - 본문: `{"document": {...}, "options": {"conflict_policy": "skip|overwrite|copy", "activation_policy": "inactive|preserve|keep_existing"}}`
  - 전체를 하나의 트랜잭션으로 처리하므로 중간 실패 시 전체가 롤백됩니다.

### 2. 테스트 시나리오 API (`admin_token` 필요)

- **목록 조회**: `GET /api/v1/scenarios` (필터: `robot_name`, `environment`)
- **상세 조회**: `GET /api/v1/scenarios/:id`
- **시나리오 생성**: `POST /api/v1/scenarios`
- **시나리오 수정**: `PUT /api/v1/scenarios/:id`
- **시나리오 삭제**: `DELETE /api/v1/scenarios/:id`
- **시나리오 복제**: `POST /api/v1/scenarios/:id/clone`
- **시나리오 활성화**: `POST /api/v1/scenarios/:id/activate`

### 3. 로봇 디바이스 연동용 API (`device_token` 또는 `admin_token` 필요)

- **활성 설정 조회**: `GET /api/v1/configs/active`
- **설정 파일 다운로드**: `GET /api/v1/configs/active/files/:filename` (예: `.env`, `ROBOT.md` 등)
- **활성 테스트 시나리오 조회**: `GET /api/v1/scenarios/active`

### 4. 버전 관리 runtime manifest

- **v2 runtime 설정 조회**: `GET /api/v2/device/runtime-config?robot_name=butler&environment=office`
- 응답은 `schema_version`, `config_revision`, 대상 robot/environment, `config` envelope를 포함합니다.
- 기존 v1 JSON 및 `.env` API는 단계적 전환 기간 동안 유지됩니다.
- v2 schema는 [schemas/robo-claw-runtime-config-v2.schema.json](schemas/robo-claw-runtime-config-v2.schema.json)에 있습니다.

### 5. 헬스체크 API

- **상태 확인**: `GET /ping` (서버 가동 및 데이터베이스 접속 상태 테스트용, 인증 비필요)
- **준비 상태**: `GET /ready` (서버와 SQLite 데이터베이스 연결 상태 확인, 인증 비필요)

### API 트래픽 제어 (Rate Limiting)

- 인메모리 Rate Limiter 한도를 초과하는 요청에 대해서는 `429 Too Many Requests` 상태 코드가 반환됩니다.

---

## Kubernetes 배포

Kubernetes 환경에서의 안정적인 가동을 위해 [kube/deployment.yaml](file:///home/seoyc/Workspace/server/ai-config-server/kube/deployment.yaml) 배포 사양이 제공됩니다.

- **타임존 동기화**: 호스트 머신의 `/etc/localtime`을 컨테이너 내부에 볼륨 마운트하여 서버 로그 시간대를 호스트 컴퓨터 시간대에 맞춥니다.
- **헬스체크 (Probe)**: `/ping` 엔드포인트를 기반으로 Liveness Probe 및 Readiness Probe를 구성하여 파드(Pod) 자가 복구를 지원합니다.
- **자원 할당 제한**: CPU 및 메모리의 최소 요구(Requests)와 최대 제한(Limits)이 명시되어 리소스 누수로 인한 클러스터 노드 다운을 원천 차단합니다.
