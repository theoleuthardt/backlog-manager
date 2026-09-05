"""Writes the Litestar app's OpenAPI 3.1 schema to backend/openapi.json,
without needing a running server, a real database, or real secrets - the
schema is static, derived purely from the route handlers and their msgspec
DTOs. The frontend's `openapi-typescript` step reads this file to generate
a type-safe `openapi-fetch` client (see #104's decision on OpenAPI codegen).

Run via `task backend:openapi`.
"""

import json
import os
from pathlib import Path

# Settings requires these with no default (they're security-sensitive, so
# no baked-in fallback) - schema generation never touches the database or
# signs anything, so any well-formed placeholder is fine here.
os.environ.setdefault("POSTGRES_URL", "postgresql+asyncpg://user:password@localhost/db")
os.environ.setdefault("AUTH_SECRET", "schema-generation-only-not-a-real-secret")

from backlog_manager_backend.app import create_app

OUTPUT_PATH = Path(__file__).resolve().parents[1] / "openapi.json"


def main() -> None:
    schema = create_app().openapi_schema.to_schema()
    OUTPUT_PATH.write_text(json.dumps(schema, indent=2) + "\n")
    print(f"Wrote OpenAPI schema to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
