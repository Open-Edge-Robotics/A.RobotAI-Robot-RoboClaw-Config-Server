# AI Config Server

A configuration server and dashboard client that manages and deploys configurations (personality, skill guides, failover options, hardware constraint configurations), environment variables (`.env`), and test scenarios required for robot bringup environments and AI agent execution, organized by robot and runtime environment.

---

## Key Features and Components

- **Configuration & Test Scenario Management Dashboard (Flutter Web)**:
  - Supports CRUD management of configurations for each robot/environment through a web interface.
  - Allows easy editing and activation of test scenarios and individual test cases using a GUI-based form editor (including drag-and-drop reordering and dynamic parameter input forms based on test case types) or a hybrid JSON text editor.
  - If a Static Admin Token is configured, users can authenticate by clicking the key icon on the top right, with the authentication token preserved in LocalStorage.
- **Configuration & Scenario Deployment API (Go & Gin)**: Dynamic downloading of configurations, configuration files (`.env`, Markdown, JSON), and active test scenarios during robot device startup.
- **Security & Traffic Control**:
  - **Data Masking**: Masks sensitive data (such as API keys) with `********` in retrieval API responses. If a masked string is received in an update API request, the server maintains the original value in the database.
  - **Rate Limiting**: Utilizes an IP-based token bucket rate limiter without external dependencies to protect the server from traffic spikes.
  - **CORS Restrictions**: Features a built-in CORS middleware to safely restrict cross-origin requests based on the configured origins in `config.yaml`.
- **Performance Optimization & Reliability**:
  - **Active Cache (In-Memory Caching)**: Prevents DB load from frequent robot device configuration requests by caching the configurations in memory (`activeCache`). The cache is immediately invalidated upon configuration changes.
  - **SQLite Performance Tuning**: Configures WAL (Write-Ahead Logging) mode and restricts the connection pool (max open connections set to 1) to prevent concurrent DB lock issues. GORM default transactions are also skipped to reduce I/O overhead.
  - **Insecure Defaults Warning**: Prints a prominent security warning banner on startup if security tokens are empty or CORS configuration is insecure.
- **SQLite Persistence**: Employs a single SQLite database file (`ai-config-server.db`), with default seed data automatically generated upon first run.
  - Integrates seed files into the binary at compile time via `go:embed`, removing hardcoded absolute host paths.
- **Portable Backup Export/Import**: Export or import all configuration profiles and test scenarios as a single JSON file to easily migrate to another server.
  - Sensitive information (API keys, tokens, MCP server configs) is excluded by default and can be optionally included.
  - On import, you can choose a conflict policy (skip/overwrite/create copy) and an activation policy (all inactive/preserve exported state/keep existing state).

---

## Build and Execution

This project uses [Taskfile](https://taskfile.dev) for building and managing tasks. You must install the `task` CLI beforehand.

### Task Installation

| Environment/Tool | Command |
|---|---|
| macOS (Homebrew) | `brew install go-task/tap/go-task` |
| Linux | `sh -c "$(curl --location https://taskfile.dev/install.sh)"` |
| Windows (Scoop) | `scoop install task` |
| Node.js (npm) | `npm install -g @go-task/cli` |
| Go Environment | `go install github.com/go-task/task/v3/cmd/task@latest` |

Check installation: `task --version`

> [!TIP]
> **Running without global installation (Node.js environment)**:
> If you do not want to install `task` globally on your system, you can use `npx @go-task/cli <task-name>` (e.g. `npx @go-task/cli deps`) to run tasks on the fly.

### 1. Build and Run using Taskfile

You can see the list of available tasks by running `task` (or `task --list`).

- **Install Dependencies**:
  ```bash
  task deps
  ```
- **Unified Build (Frontend & Backend)**:
  ```bash
  task build
  ```
- **Run Server**:
  ```bash
  task run
  ```
- **Clean Build Artifacts and Cache**:
  ```bash
  task clean
  ```

### 2. Manual Build and Run

#### Frontend (Flutter Web) Build
The dashboard must be built with the `--base-href "/web/"` option to support SPA routing paths.
```bash
cd frontend
flutter pub get
flutter build web --base-href "/web/" --release
```

#### Backend (Go Server) Build and Run
```bash
# Build
go build -o ai-config-server .

# Run Server (using the 'serve' subcommand)
./ai-config-server serve
```
- Accessing `http://localhost:8080` (default port) will automatically redirect you to the `/web/` dashboard.
- CLI Command List:
  - `serve`: Starts the HTTP API and dashboard server.
  - `version`: Prints the version of the server binary.
  - `completion`: Generates shell completion scripts.

### 3. Build and Run with Docker

A multi-stage Docker build is supported to run without a compilation environment. During build, `tzdata` is installed in the final Alpine stage and automatically synchronized to the `Asia/Seoul` timezone.

- **Build Image**:
  ```bash
  task docker-build
  ```
- **Run Container (Volume Mount & Port Binding)**:
  ```bash
  task docker-run
  ```
  Mounts the `data/` directory under the working directory to `/app/data` inside the container to persist the SQLite database.
- **Stop Container & Remove Resources**:
  ```bash
  task docker-stop
  ```

### 4. Running Unit Tests

You can run integration and unit tests to verify server backend logic, such as authentication middleware, rate limiting, data masking, and JSON validation.

```bash
go test ./...
```

---

## Configuration (`config.yaml` / Environment Variables)

Server configuration can be set by copying `config.example.yaml` to `config.yaml` or using environment variables. (`config.yaml` is ignored in git via `.gitignore` to prevent secret leakage). System environment variables take precedence, prefixed with `AI_CONFIG_SERVER_`.

| Configuration Key | Environment Variable | Default Value | Description |
|---|---|---|---|
| `server.host` | `AI_CONFIG_SERVER_SERVER_HOST` | `0.0.0.0` | Server binding host |
| `server.port` | `AI_CONFIG_SERVER_SERVER_PORT` | `8080` | Server port |
| `log.level` | `AI_CONFIG_SERVER_LOG_LEVEL` | `info` | Logging level |
| `database.path` | `AI_CONFIG_SERVER_DATABASE_PATH` | `ai-config-server.db` | SQLite database file path |
| `security.admin_token` | `AI_CONFIG_SERVER_SECURITY_ADMIN_TOKEN` | `""` | Admin token for dashboard/scenario editing |
| `security.device_token` | `AI_CONFIG_SERVER_SECURITY_DEVICE_TOKEN` | `""` | Dedicated token for robot device deployment APIs |
| `security.cors_allowed_origins`| `AI_CONFIG_SERVER_SECURITY_CORS_ALLOWED_ORIGINS` | `[]` | List of allowed CORS origins |

---

## SQLite Database Seeding (Seed)

On the first run, the `ai-config-server.db` file is created and seeded automatically by scanning local configuration files.
- **Configurations and Scenarios Seed**:
  - Automatically imports robot configuration profiles for `butler` (office environment) and `former` (factory environment).
  - Automatically registers and activates 3 default automated test scenarios: `butler`, `former`, and `default` (generic baseline).

---

## API Specification & Authentication

All REST API paths use the `/api/v1` prefix. When authentication tokens are configured, requests must include the **`Authorization: Bearer <token>`** header.

### 1. Configuration Management API (for Dashboard, requires `admin_token`)
- **List Configurations**: `GET /api/v1/configs` (Filters: `robot_name`, `environment`)
- **Get Configuration**: `GET /api/v1/configs/:id`
- **Get Configuration File**: `GET /api/v1/configs/:id/files/:filename` (Retrieves the raw content of individual files within a configuration profile)
- **Create Configuration**: `POST /api/v1/configs`
  - *`LimitsContent` and `OllamaOptionsJson` fields undergo automatic JSON integrity validation.*
- **Update Configuration**: `PUT /api/v1/configs/:id`
  - *Sensitive data like credentials are masked with `********`. Sending this mask value in an update request will preserve the original value in the database.*
- **Delete Configuration**: `DELETE /api/v1/configs/:id`
- **Clone Configuration**: `POST /api/v1/configs/:id/clone`
- **Activate Configuration**: `POST /api/v1/configs/:id/activate`

### Portable Backup API (for Dashboard, requires `admin_token`)
- **Export Backup**: `GET /api/v1/admin/transfer/export` (query: `include_secrets`, `include_configs`, `include_scenarios`) or `POST /api/v1/admin/transfer/export`
  - Exports configuration profiles and test scenarios as a portable JSON file.
  - `include_secrets=true` includes API keys/tokens/MCP server configs as plain text.
- **Validate Backup**: `POST /api/v1/admin/transfer/import/validate`
  - Checks schema version, required fields, nested JSON integrity, and conflicts against existing data before upload.
- **Import Backup**: `POST /api/v1/admin/transfer/import`
  - Body: `{"document": {...}, "options": {"conflict_policy": "skip|overwrite|copy", "activation_policy": "inactive|preserve|keep_existing"}}`
  - Processes everything in a single transaction; any failure rolls back the entire import.

### 2. Test Scenario API (requires `admin_token`)
- **List Scenarios**: `GET /api/v1/scenarios` (Filters: `robot_name`, `environment`)
- **Get Scenario**: `GET /api/v1/scenarios/:id`
- **Create Scenario**: `POST /api/v1/scenarios`
- **Update Scenario**: `PUT /api/v1/scenarios/:id`
- **Delete Scenario**: `DELETE /api/v1/scenarios/:id`
- **Clone Scenario**: `POST /api/v1/scenarios/:id/clone`
- **Activate Scenario**: `POST /api/v1/scenarios/:id/activate`

### 3. Robot Device Integration API (requires `device_token` or `admin_token`)
- **Get Active Configuration**: `GET /api/v1/configs/active`
- **Download Configuration File**: `GET /api/v1/configs/active/files/:filename` (e.g. `.env`, `ROBOT.md`, etc.)
- **Get Active Test Scenario**: `GET /api/v1/scenarios/active`

### 4. Health Check API
- **Check Status**: `GET /ping` (Tests server operation and database connectivity, no authentication required)

### API Traffic Control (Rate Limiting)
- Requests exceeding the in-memory Rate Limiter limits will receive a `429 Too Many Requests` status code.

---

## Kubernetes Deployment

A deployment specification is provided at [kube/deployment.yaml](file:///home/seoyc/Workspace/server/ai-config-server/kube/deployment.yaml) for reliable execution in Kubernetes environments.

- **Timezone Synchronization**: Mounts the host machine's `/etc/localtime` into the container to align log and server time with the host.
- **Health Check (Probes)**: Configures Liveness and Readiness probes using the `/ping` endpoint to support self-healing Pods.
- **Resource Constraints**: Explicit CPU and memory Requests and Limits are set to prevent cluster node crashes from resource leaks.
