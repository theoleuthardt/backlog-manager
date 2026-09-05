from litestar.testing import TestClient


async def test_get_own_user_returns_own_profile_without_password_hash(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "ownprofile@example.com")
        response = client.get("/api/user/me", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["email"] == "ownprofile@example.com"
    assert body["is_admin"] is False
    assert "password_hash" not in body


async def test_get_own_user_requires_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        response = client.get("/api/user/me")

    assert response.status_code == 401


async def test_update_own_user_hashes_new_password(postgres_url: str, create_and_login) -> None:
    """Regression test: the tRPC prototype this replaces wrote whatever
    the client sent straight into the PasswordHash column unhashed for
    updates (only registration hashed it) - a real plaintext-password
    storage bug. The new password must actually work to log in with,
    and the old one must stop working."""
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(
            client, "passwordchange@example.com", password="original-pw"
        )

        update_response = client.put(
            "/api/user/me", headers=headers, json={"password": "new-password-123"}
        )

        old_login = client.post(
            "/api/auth/login",
            json={"email": "passwordchange@example.com", "password": "original-pw"},
        )
        new_login = client.post(
            "/api/auth/login",
            json={"email": "passwordchange@example.com", "password": "new-password-123"},
        )

    assert update_response.status_code == 200
    assert old_login.status_code == 401
    assert new_login.status_code == 200


async def test_update_own_user_rejects_short_password(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "shortpwupdate@example.com")
        response = client.put("/api/user/me", headers=headers, json={"password": "short"})

    assert response.status_code == 400


async def test_update_own_user_cannot_set_is_admin(postgres_url: str, create_and_login) -> None:
    """UpdateOwnUserRequest has no is_admin field at all - a self-update
    request that tries to sneak one in must simply be ignored, not
    silently grant admin."""
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "noselfpromote@example.com")
        client.put("/api/user/me", headers=headers, json={"is_admin": True})
        profile = client.get("/api/user/me", headers=headers)

    assert profile.json()["is_admin"] is False


async def test_delete_own_user_removes_account(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "deleteme@example.com", password="hunter22")
        delete_response = client.delete("/api/user/me", headers=headers)
        login_after_delete = client.post(
            "/api/auth/login",
            json={"email": "deleteme@example.com", "password": "hunter22"},
        )

    assert delete_response.status_code == 204
    assert login_after_delete.status_code == 401


async def test_get_user_by_username_is_public_but_excludes_sensitive_fields(
    postgres_url: str, create_and_login
) -> None:
    """Regression test: this endpoint requires no authentication (it
    doesn't declare current_user, so the router's auth dependency never
    runs), so it must never return email, is_admin, or timestamps -
    only enough to confirm the username exists."""
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        await create_and_login(client, "publiclookup@example.com")
        response = client.get("/api/user/by-username/publiclookup")

    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "publiclookup"
    assert "email" not in body
    assert "is_admin" not in body
    assert "created_at" not in body


async def test_user_responses_are_not_cached(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "nocache@example.com")
        response = client.get("/api/user/me", headers=headers)

    assert response.headers["cache-control"] == "no-store"


async def test_get_user_by_username_returns_404_for_unknown_username(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        response = client.get("/api/user/by-username/nobody-with-this-name")

    assert response.status_code == 404


async def test_admin_routes_reject_non_admin_user(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "regularuser@example.com")
        response = client.get("/api/admin/users", headers=headers)

    assert response.status_code == 403


async def test_admin_routes_reject_unauthenticated_requests(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        response = client.get("/api/admin/users")

    assert response.status_code == 401


async def test_admin_can_create_list_update_and_delete_users(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        admin_headers = await create_and_login(client, "theadmin@example.com", is_admin=True)

        create_response = client.post(
            "/api/admin/users",
            headers=admin_headers,
            json={
                "username": "createdbyadmin",
                "email": "createdbyadmin@example.com",
                "password": "hunter22",
            },
        )
        assert create_response.status_code == 201
        created_user_id = create_response.json()["id"]

        list_response = client.get("/api/admin/users", headers=admin_headers)
        get_response = client.get(f"/api/admin/users/{created_user_id}", headers=admin_headers)

        update_response = client.put(
            f"/api/admin/users/{created_user_id}",
            headers=admin_headers,
            json={"is_admin": True},
        )

        delete_response = client.delete(
            f"/api/admin/users/{created_user_id}", headers=admin_headers
        )
        get_after_delete = client.get(f"/api/admin/users/{created_user_id}", headers=admin_headers)

    assert {user["email"] for user in list_response.json()} >= {
        "theadmin@example.com",
        "createdbyadmin@example.com",
    }
    assert get_response.json()["email"] == "createdbyadmin@example.com"
    assert update_response.status_code == 200
    assert update_response.json()["is_admin"] is True
    assert delete_response.status_code == 204
    assert get_after_delete.status_code == 404


async def test_non_admin_cannot_create_users(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "notanadmin@example.com")
        response = client.post(
            "/api/admin/users",
            headers=headers,
            json={
                "username": "shouldnotexist",
                "email": "shouldnotexist@example.com",
                "password": "hunter22",
            },
        )

    assert response.status_code == 403
