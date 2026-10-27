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
task monitor:dev           # starts on http://localhost:8080
task monitor:test          # runs the tests
task monitor:lint          # compiles code and tests with -Xlint:all -Werror
task monitor:format        # formats the code (Spotless, palantir-java-format)
task monitor:format:check  # checks the format without changing files
task monitor:build         # builds the executable jar in monitor/target/
```

They wrap the Maven wrapper; inside `monitor/`, `./mvnw verify` runs
everything CI runs (compile, tests, format check).

`GET http://localhost:8080/actuator/health` answers `{"status":"UP"}`.
