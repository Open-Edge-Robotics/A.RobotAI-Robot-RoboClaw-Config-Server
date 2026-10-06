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

- 아직 `database.DB` 전역에 의존하는 코드가 있다.
- 전역 DB 를 교체하는 테스트는 **`t.Parallel()` 을 사용하면 안 된다**.
- 테스트별 고유 인메모리 DB DSN을 사용한다.
- DB를 열면 반드시 `t.Cleanup(func(){ sqlDB.Close() })` 로 정리한다.

### 커버리지 목표

| 단계 | 전역 목표 | 핵심 Service/로직 목표 |
|---|---:|---:|
| 기준선(현재) | 40% | — |
| 1차 | 55% | 80% |
| 2차 | 70% | 80% |
| 안정화 | 80% | 80% |

- 전역 커버리지보다 **변경한 핵심 Service/로직은 80% 이상** 을 우선한다.

---

## 3. 프론트엔드 (Flutter)

### 실행 명령

```bash
task flutter-test  # flutter test
task analyze       # flutter analyze
task test:coverage # 커버리지(lcov)
```

### 테스트 대상 계층

1. **모델** — JSON 직렬화/역직렬화, 기본값.
2. **API Client** — `MockClient`(http)로 URL/헤더/응답/오류 검증.
3. **Controller** — 상태 전이(loading/success/error).
4. **Widget** — 주요 사용자 흐름.

### 브라우저 전용 의존성

- `package:web`(LocalStorage, FilePicker, Download)는 **테스트에서 직접 사용하지 않는다**.
- 반드시 인터페이스로 추상화해 Fake 로 주입한다.

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

`.gitlab-ci.yml` 에서 다음을 **순차**로 실행한다.

1. Format Check (`gofmt -l`, `dart format --set-exit-if-changed`)
2. `go vet ./...`
3. `go test ./...`
4. `flutter analyze`
5. `flutter test`

모두 통과해야 병합할 수 있다.

---

## 5. 커밋 규칙

- 기능을 구현하기 전에 테스트가 실패하는 커밋을 남길 것을 권장한다.
- 커밋 메시지는 무엇을 왜 바꿨는지 명확히 적는다.

예:

```text
test(config): import 가 기존 민감 정보를 보존하는지 검증하는 테스트 추가
feat(config): 백업 import 시 민감 정보 보존 로직 구현
```
