"""Every JSON request body is sanitized before it is validated: invisible
and control characters are removed, the edges are trimmed and the text is
NFC-normalized. Passwords are left exactly as typed, and punctuation is
never stripped."""

from litestar.testing import TestClient

RLO = "\N{RIGHT-TO-LEFT OVERRIDE}"
ZWSP = "\N{ZERO WIDTH SPACE}"
ZWJ = "\N{ZERO WIDTH JOINER}"
WJ = "\N{WORD JOINER}"
FAMILY = f"\N{MAN}{ZWJ}\N{WOMAN}{ZWJ}\N{GIRL}"

_ENTRY = {
    "genre": [],
    "platform": ["PC"],
    "status": "Not Started",
    "owned": True,
    "interest": 5,
}


async def test_entry_text_is_stored_without_invisible_characters(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "sanitizedtitle@example.com")
        response = client.post(
            "/api/backlog/entries",
            headers=headers,
            json={
                **_ENTRY,
                "title": f" {RLO}Half-Life 2{ZWSP} ",
                "genre": [f" Shooter{ZWSP}"],
                "review": f"{FAMILY} with the family{WJ} ",
            },
        )

    assert response.status_code == 201
    assert response.json()["title"] == "Half-Life 2"
    assert response.json()["genre"] == ["Shooter"]
    assert response.json()["review"] == f"{FAMILY} with the family"


async def test_entry_title_keeps_quotes_semicolons_and_braces(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    title = 'Assassin\'s Creed; {Deluxe} "GOTY"'

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "punctuationtitle@example.com")
        response = client.post(
            "/api/backlog/entries", headers=headers, json={**_ENTRY, "title": title}
        )

    assert response.status_code == 201
    assert response.json()["title"] == title


async def test_username_and_email_are_trimmed_before_they_are_validated(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        admin_headers = await create_and_login(client, "trimadmin@example.com", is_admin=True)
        response = client.post(
            "/api/admin/users",
            headers=admin_headers,
            json={
                "username": " padded\n",
                "email": " padded@example.com\n",
                "password": "hunter2hunter2",
            },
        )
        client.delete(f"/api/admin/users/{response.json()['id']}", headers=admin_headers)

    assert response.status_code == 201
    assert response.json()["name"] == "padded"
    assert response.json()["email"] == "padded@example.com"


async def test_password_is_kept_exactly_as_typed(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    password = f"  spaced {ZWSP}password "

    with TestClient(app=create_app()) as client:
        admin_headers = await create_and_login(client, "pwadmin@example.com", is_admin=True)
        created = client.post(
            "/api/admin/users",
            headers=admin_headers,
            json={"username": "spacedpw", "email": "spacedpw@example.com", "password": password},
        )
        exact = client.post(
            "/api/auth/login", json={"email": "spacedpw@example.com", "password": password}
        )
        cleaned = client.post(
            "/api/auth/login",
            json={"email": "spacedpw@example.com", "password": "spaced password"},
        )
        client.delete(f"/api/admin/users/{created.json()['id']}", headers=admin_headers)

    assert created.status_code == 201
    assert exact.status_code == 200
    assert cleaned.status_code == 401


async def test_login_email_is_trimmed(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        await create_and_login(client, "trimlogin@example.com")
        response = client.post(
            "/api/auth/login",
            json={"email": f"  trimlogin@example.com{ZWSP} ", "password": "hunter2hunter2"},
        )

    assert response.status_code == 200
