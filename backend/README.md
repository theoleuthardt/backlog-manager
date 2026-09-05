# backlog-manager-backend

Python/Litestar backend for Backlog Manager, managed with [uv](https://docs.astral.sh/uv/).
This is the first increment of the Next.js → Litestar migration (see issue #104):
just enough scaffolding to run a health check against Postgres. No domain
routes, ORM models, or auth yet — those land in follow-up PRs.

## Setup

```bash
cp .env.example .env  # adjust POSTGRES_URL if needed
uv sync
```

## Run

```bash
uv run uvicorn backlog_manager_backend.app:app --reload --port 8000
curl localhost:8000/health
```

Requires a reachable Postgres — the root `docker-compose.yml` `db` service
works for local development.

## Test

```bash
uv run pytest
```

Spins up a real Postgres container per test session via `testcontainers`
and hits `/health` against it. Requires a working Docker (or Podman, with
`DOCKER_HOST` pointed at its socket) daemon.

## Lint

```bash
uv run ruff check .
```
