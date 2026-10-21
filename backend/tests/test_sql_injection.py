"""Regression tests for SQL injection: every query goes through SQLAlchemy
with bound parameters, so classic payloads in the public inputs (login,
username lookup, space invitation) are compared as plain strings, match
nothing and leave every table intact."""

import pytest
from litestar.testing import TestClient
from sqlalchemy import text

PAYLOADS = [
    "' OR '1'='1",
    "' OR 1=1 --",
    "admin'--",
    'x\'; DROP TABLE "Users"; --',
    '\' UNION SELECT "PasswordHash" FROM "Users" --',
    "%' OR \"Email\" LIKE '%",
]


async def _user_count() -> int:
    from backlog_manager_backend.db import async_session

    async with async_session() as session:
        return (await session.execute(text('SELECT count(*) FROM "Users"'))).scalar_one()


@pytest.mark.parametrize("payload", PAYLOADS)
async def test_login_payload_in_email_or_password_is_rejected(
    postgres_url: str, create_and_login, payload: str
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        await create_and_login(client, "injectiontarget@example.com")
        users_before = await _user_count()
        in_email = client.post("/api/auth/login", json={"email": payload, "password": payload})
        in_password = client.post(
            "/api/auth/login",
            json={"email": "injectiontarget@example.com", "password": payload},
        )
        real_login = client.post(
            "/api/auth/login",
            json={"email": "injectiontarget@example.com", "password": "hunter2hunter2"},
        )
        users_after = await _user_count()

    assert in_email.status_code == 401
    assert in_password.status_code == 401
    assert "access_token" not in in_email.json()
    assert real_login.status_code == 200
    assert users_after == users_before


@pytest.mark.parametrize("payload", PAYLOADS)
async def test_username_lookup_payload_finds_nobody(
    postgres_url: str, create_and_login, payload: str
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        await create_and_login(client, "lookuptarget@example.com")
        response = client.get("/api/user/by-username/" + payload)

    assert response.status_code == 404


@pytest.mark.parametrize("payload", PAYLOADS)
async def test_space_invitation_payload_finds_nobody(
    postgres_url: str, create_and_login, payload: str
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "invitetarget@example.com")
        await create_and_login(client, "invitebystander@example.com")
        response = client.post(
            "/api/space/invitations", headers=headers, json={"username": payload}
        )
        space = client.get("/api/space", headers=headers).json()

    assert response.status_code == 404
    assert space["space_id"] is None
