"""Writes the Litestar app's OpenAPI 3.1 schema to backend/openapi.json,
without needing a running server, a real database, or real secrets (the
required settings get throwaway placeholder values below) - the
schema is static, derived purely from the route handlers and their msgspec
DTOs. The Flutter app's `task app:generate-api` reads this file to generate
its typed Dart client (`app/lib/api/generated/`).

Run via `task backend:openapi`.
"""

import json
import os
from pathlib import Path

from cryptography.fernet import Fernet

os.environ.setdefault("POSTGRES_URL", "postgresql+asyncpg://user:password@localhost/db")
os.environ.setdefault("AUTH_SECRET", "schema-generation-only-not-a-real-secret")
os.environ.setdefault("TOTP_ENCRYPTION_KEY", Fernet.generate_key().decode())
os.environ["ENABLE_DOCS"] = "true"

from backlog_manager_backend.app import create_app

OUTPUT_PATH = Path(__file__).resolve().parents[1] / "openapi.json"


def main() -> None:
    schema = create_app().openapi_schema.to_schema()
    OUTPUT_PATH.write_text(json.dumps(schema, indent=2) + "\n")
    print(f"Wrote OpenAPI schema to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
