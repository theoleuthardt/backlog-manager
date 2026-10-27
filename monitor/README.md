# Monitor

Status and alerting service for the homelab (epic #468): it checks the
Backlog Manager backend and other services, receives pushes from cron jobs,
alerts through a Discord webhook and serves a public status page. It runs in
its own LXC, never next to what it watches.

Stack: Spring Boot 4.1.2, Java 25, Maven (wrapper included), PostgreSQL,
Liquibase, OpenAPI, vavr. The design (packages, data model, flows, error
handling, decisions) is in
[`docs/MONITOR_ARCHITECTURE.md`](../docs/MONITOR_ARCHITECTURE.md).

## Running it

Needs a JDK 25; Maven is downloaded by the wrapper. From the repository root,
use the tasks (see `Taskfile.yml`):

```bash
task monitor:install       # downloads the Maven dependencies and plugins
task monitor:db:create     # creates its role and database in the local Postgres (once)
task monitor:dev           # starts on http://localhost:8090
task monitor:test          # runs the tests
task monitor:lint          # compiles code and tests with -Xlint:all -Werror
task monitor:format        # formats the code (Spotless, palantir-java-format)
task monitor:format:check  # checks the format without changing files
task monitor:build         # builds the executable jar in monitor/target/
```

They wrap the Maven wrapper; inside `monitor/`, `./mvnw verify` runs
everything CI runs (compile, tests, format check).

`GET http://localhost:8090/actuator/health` answers `{"status":"UP", ...}`,
with the database among its components.

## Database and configuration

The Monitor has its own role and database in the local Postgres of
`compose.yml`: `task db:up`, then `task monitor:db:create` once. The script
behind it (`postgres/create-monitor-db.bash`) can be re-run any time, also on
a volume that existed before the Monitor (Postgres only runs init scripts on
an empty volume, so the Monitor does not rely on them).

Profiles:

- **dev** (the default): takes `MONITOR_DB_NAME`, `MONITOR_DB_USER`,
  `MONITOR_DB_PASSWORD`, `POSTGRES_PORT` and `MONITOR_PORT` from the
  environment (see `.env.example`). `task monitor:dev` and
  `task monitor:db:create` load them from the repository's `.env` with the
  same parser, so the password the role is created with is the one the
  Monitor connects with; started another way (an IDE), set them yourself.
  Listens on `127.0.0.1:8090` (pgAdmin has 8080; `MONITOR_ADDRESS=0.0.0.0`
  opens it to the network) and shows the details of `/actuator/health`.
- **prod** (`SPRING_PROFILES_ACTIVE=prod`): the datasource comes only from
  `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME` and
  `SPRING_DATASOURCE_PASSWORD`, logs are structured (ECS JSON), health shows
  no details.

The Monitor's own settings are the `MonitorProperties` record (prefix
`monitor`): `MONITOR_SCHEDULER_TICK` (5s), `MONITOR_HTTP_DEFAULT_TIMEOUT`
(10s), `MONITOR_RETENTION_DAYS` (30), `MONITOR_PUSH_MESSAGE_MAX_LENGTH` (200).
They are validated at start; an invalid value stops the start.

Tests that start the application context get a Postgres 17 container from
Testcontainers (`TestcontainersConfiguration`), so `task monitor:test` needs
Docker or Podman, as the backend tests do.
