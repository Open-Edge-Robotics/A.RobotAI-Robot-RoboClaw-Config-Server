# TDD / 테스트 정책 (Testing Policy)

이 프로젝트는 **TDD(Test-Driven Development)** 방식을 지향한다.
새 기능, 버그 수정, API 변경 시 아래 규칙을 지켜 개발한다.

> 모든 AI 에이전트와 개발자는 이 문서를 따라야 한다. 요약본은 저장소 루트의
> `AGENTS.md` 를 참고한다.

---

## 1. 핵심 원칙

1. **먼저 실패하는 테스트를 작성**한다 (Red).
2. **최소한의 구현으로 테스트를 통과**시킨다 (Green).
3. **동작이 유지되는 상태에서 리팩터링**한다 (Refactor).
4. 버그 수정은 **재현 테스트부터** 작성한다.
5. API/스키마 변경은 **Contract(통합) 테스트부터** 작성한다.
6. 새 비즈니스 규칙은 **Service 또는 로직 단위 테스트**를 필수로 한다.

---

## 2. 백엔드 (Go)

### 실행 명령

```bash
task test          # go test ./...
task vet           # go vet ./...
task test:race     # -race 포함
task test:coverage # 커버리지 리포트
```

### 테스트 파일 규칙

- 소스 파일과 같은 패키지에 `_test.go` 로 배치한다.
- 테스트가 아닌 **공용 헬퍼**는 `testutil/` 패키지에 둔다.
  - DB, HTTP 요청, Fixture, 설정 등.
- 외부 라이브러리 assertion 은 필수가 아니다. Go 기본 `testing` 만으로도 가능하다.

### 테스트 이름 규칙

```go
func TestConfigService_Import_OverwritePreservesMissingSecrets(t *testing.T)
func TestHandler_ActivateConfig_DeactivatesOthersInSameRobotEnv(t *testing.T)
```

### Given / When / Then 구조

```go
// Given
existing := ...

// When
result, err := service.Import(...)

// Then
if err != nil { t.Fatalf("unexpected error: %v", err) }
if result != want { t.Errorf(...) }
```

### 병렬 테스트 주의

- `database.Init(dsn)`이 반환한 DB와 `handler.NewHandler(db)`를 테스트별로 소유한다. 전역 DB 교체는 사용하지 않는다.
- `testutil.NewTestDB(t)`는 호출마다 고유 인메모리 DSN을 만들고 정리 함수를 등록한다.
- 독립된 DB·Handler를 사용하는 테스트는 `t.Parallel()`을 사용할 수 있다.
- Gin 모드·환경변수·작업 디렉터리 등 다른 전역 상태를 변경하는 테스트는 직렬로 유지한다.
- 직접 DB를 열면 가능한 빨리 `t.Cleanup`으로 연결 정리를 등록한다.

### 커버리지 게이트

- `task test:coverage`는 백엔드 전체 statement coverage **80% 이상**을 검사한다.
- `task test:coverage:frontend`는 프론트엔드 전체 line coverage **80% 이상**을 검사한다.
- 두 게이트는 `task check`, `task ci`, GitLab CI에서 동일한 임계치를 적용한다.
- 커버리지 보고서가 없거나 측정한 코드가 0줄이면 성공으로 처리하지 않는다.
- 변경한 핵심 Service/로직의 오류·경계값 테스트를 우선하며, 전체 수치만으로 동작 보존을 판단하지 않는다.

---

## 3. 프론트엔드 (Flutter)

### 실행 명령

```bash
task flutter-test           # flutter test
task analyze                # flutter analyze
task test:coverage:frontend  # 커버리지(lcov) 및 80% 게이트
```

### 테스트 대상 계층

1. **모델** — JSON 직렬화/역직렬화, 기본값.
2. **API Client** — `MockClient`(http)로 URL/헤더/응답/오류 검증.
3. **Controller** — 상태 전이(loading/success/error).
4. **Widget** — 주요 사용자 흐름.

### 브라우저 전용 의존성

- `package:web`(LocalStorage, FilePicker, Download)는 **테스트에서 직접 사용하지 않는다**.
- 반드시 인터페이스로 추상화해 Fake 로 주입한다.
- 화면/위젯은 전역 싱글톤을 읽지 않고 생성자로 주입받은 `AppDependencies`(API·TokenStore·FilePicker·FileDownloader)를 사용한다.
- 위젯 테스트는 `HttpAdminApi.instance` 같은 전역을 바꾸지 않고 Fake/MockClient 를 담은 의존성을 직접 주입한다. 기존 static 파사드(`ApiService` 등)는 호환용이며 운영 UI 에서 사용하지 않는다.
- 목록·loading 상태는 Controller 단일 소스이며, dispose 이후 도착한 응답은 notifier/위젯 상태를 갱신하지 않는다.

```dart
abstract class TokenStore {
  String? read();
  void write(String value);
  void clear();
}
```

### 테스트 이름 (한글 설명 권장)

```dart
test('민감 정보가 없는 백업을 덮어쓰면 기존 토큰을 유지한다', () { ... });
```

---

## 4. CI 게이트

`.gitlab-ci.yml`의 백엔드·프론트엔드 job은 독립 실행하며, 각 job 안의 검사는 순차 실행한다.

- 백엔드: secret scan → contract check → Go format check → vet → 테스트 → coverage 80% 게이트.
- 프론트엔드: lockfile 강제 설치 → Dart format check → analyze → 테스트·coverage 80% 게이트.
- Go format check는 위반 파일을 출력하고 실패한다. `testutil/`도 검사 대상이다.
- Flutter 앱의 `frontend/pubspec.lock`을 추적한다. CI에서는 `flutter pub get --enforce-lockfile`로 의존성 drift를 차단한다.
- `task check`는 양쪽 검사에 schema check와 frontend contract 테스트를 추가한 로컬 전체 게이트다.
- 동시성 변경에는 별도로 `task test:race`를 실행한다.

모든 job이 통과해야 병합할 수 있다.

---

## 5. 커밋 규칙

- 기능을 구현하기 전에 테스트가 실패하는 커밋을 남길 것을 권장한다.
- 커밋 메시지는 무엇을 왜 바꿨는지 명확히 적는다.

예:

```text
test(config): import 가 기존 민감 정보를 보존하는지 검증하는 테스트 추가
feat(config): 백업 import 시 민감 정보 보존 로직 구현
```
