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

Needs a JDK 25; Maven is downloaded by the wrapper.

```bash
./mvnw spring-boot:run     # starts on http://localhost:8080
./mvnw test                # runs the tests
```

`GET http://localhost:8080/actuator/health` answers `{"status":"UP"}`.
