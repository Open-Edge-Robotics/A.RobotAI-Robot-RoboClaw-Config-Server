# ── STAGE 1: Flutter Web 빌드 ──
FROM ubuntu:22.04 AS flutter-builder

ENV DEBIAN_FRONTEND=noninteractive

# 필수 도구 설치
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Flutter SDK 고정 (로컬 개발 버전 3.47.0 과 일치시켜 재현성 확보)
# --depth 1 로 shallow clone 하여 빌드 시간 단축
RUN git clone --depth 1 -b 3.47.0 https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

WORKDIR /app

# 캐시 활용을 위한 pubspec 복사 및 의존성 다운로드
COPY frontend/pubspec.yaml frontend/pubspec.lock ./frontend/
WORKDIR /app/frontend
RUN flutter pub get

# 소스코드 전체 복사 후 Web 빌드 실행 (base-href /web/ 적용)
WORKDIR /app
COPY frontend/ ./frontend/
WORKDIR /app/frontend
RUN flutter build web --base-href "/web/" --release


# ── STAGE 2: Go API 백엔드 빌드 ──
FROM golang:1.26-alpine AS go-builder

# SQLite CGO 컴파일을 위해 build-base(gcc 등) 필수 설치
RUN apk add --no-cache git build-base

WORKDIR /app

# Go 모듈 다운로드
COPY go.mod go.sum ./
RUN go mod download

# 소스 전체 복사
COPY . .

# SQLite CGO 빌드를 활성화하여 Go 바이너리 빌드
RUN CGO_ENABLED=1 CGO_CFLAGS="-D_LARGEFILE64_SOURCE" GOOS=linux go build -ldflags="-w -s" -o aics .


# ── STAGE 3: 최종 실행 이미지 (최적화 런타임) ──
FROM alpine:3.20

# CGO 컴파일 바이너리 실행을 위한 gcompat 라이브러리, CA 인증서 및 타임존 데이터(tzdata) 설치
RUN apk add --no-cache ca-certificates gcompat tzdata
ENV TZ=Asia/Seoul

WORKDIR /app

# 빌더 스테이지로부터 실행에 필요한 산출물만 추출 복사
COPY --from=go-builder /app/aics /app/aics
RUN ln -s /app/aics /app/ai-config-server
COPY --from=flutter-builder /app/frontend/build/web /app/frontend/build/web
COPY config.example.yaml /app/config.yaml

# SQLite DB 볼륨 영속화를 위한 데이터 디렉토리 및 비루트 사용자 생성
RUN mkdir -p /app/data \
    && addgroup -S appuser \
    && adduser -S -G appuser appuser \
    && chown -R appuser:appuser /app
ENV AI_CONFIG_SERVER_DATABASE_PATH=/app/data/ai-config-server.db

# 보안 강화: 비루트 사용자로 실행
USER appuser

# 8080 포트 바인딩 및 데이터 볼륨 설정
EXPOSE 8080
VOLUME ["/app/data"]

# 헬스체크: /ping 엔드포인트로 가동 상태 확인
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/ping || exit 1

# 웹 서버 실행
ENTRYPOINT ["/app/aics", "serve"]
