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

Requires a reachable Postgres — the root `compose.yml` `db` service works
for local development (`task db:up`).

## Test

```bash
uv run pytest
```

Spins up a real Postgres container per test session via `testcontainers`
and hits `/health` against it. Requires a working Podman (or Docker)
daemon; with Podman, point `DOCKER_HOST` at its socket first, e.g.:

```bash
export DOCKER_HOST="unix://$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}')"
```

## Lint

```bash
uv run ruff check .
```
