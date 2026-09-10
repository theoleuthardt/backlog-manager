from cryptography.fernet import Fernet
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


async def test_update_own_user_sets_steam_api_key(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(user_routes.settings, "steam_api_key_encryption_key", Fernet.generate_key().decode())

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "steamkeyuser@example.com")

        update_response = client.put(
            "/api/user/me", headers=headers, json={"steam_api_key": "my-steam-key"}
        )
        me_response = client.get("/api/user/me", headers=headers)

    assert update_response.status_code == 200
    assert update_response.json()["has_steam_api_key"] is True
    assert "steam_api_key" not in update_response.json()
    assert "steam_api_key_encrypted" not in update_response.json()
    assert me_response.json()["has_steam_api_key"] is True


async def test_update_own_user_clears_steam_api_key_with_empty_string(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(user_routes.settings, "steam_api_key_encryption_key", Fernet.generate_key().decode())

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "clearsteamkey@example.com")
        client.put("/api/user/me", headers=headers, json={"steam_api_key": "my-steam-key"})

        clear_response = client.put(
            "/api/user/me", headers=headers, json={"steam_api_key": ""}
        )

    assert clear_response.status_code == 200
    assert clear_response.json()["has_steam_api_key"] is False


async def test_update_own_user_returns_503_when_steam_key_storage_not_configured(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(user_routes.settings, "steam_api_key_encryption_key", None)

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "nokeystorage@example.com")
        response = client.put(
            "/api/user/me", headers=headers, json={"steam_api_key": "my-steam-key"}
        )

    assert response.status_code == 503


async def test_update_own_user_returns_503_when_encryption_key_is_malformed(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(user_routes.settings, "steam_api_key_encryption_key", "not-a-valid-fernet-key")

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "badencryptionkey@example.com")
        response = client.put(
            "/api/user/me", headers=headers, json={"steam_api_key": "my-steam-key"}
        )

    assert response.status_code == 503


async def test_update_own_user_trims_steam_api_key_before_storing(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.auth.encryption import decrypt
    from backlog_manager_backend.db import async_session
    from backlog_manager_backend.repositories import user_repo
    from backlog_manager_backend.routes import user as user_routes

    key = Fernet.generate_key().decode()
    monkeypatch.setattr(user_routes.settings, "steam_api_key_encryption_key", key)

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "trimsteamkey@example.com")
        client.put(
            "/api/user/me", headers=headers, json={"steam_api_key": "  my-steam-key  "}
        )

    async with async_session() as session:
        stored = await user_repo.get_user_by_email(session, "trimsteamkey@example.com")

    assert stored is not None
    assert decrypt(stored.steam_api_key_encrypted, key) == "my-steam-key"


async def test_update_own_user_sets_igdb_credentials(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(
        user_routes.settings, "steam_api_key_encryption_key", Fernet.generate_key().decode()
    )

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "igdbkeyuser@example.com")

        update_response = client.put(
            "/api/user/me",
            headers=headers,
            json={"igdb_client_id": "my-client-id", "igdb_client_secret": "my-client-secret"},
        )

    assert update_response.status_code == 200
    assert update_response.json()["has_igdb_credentials"] is True
    assert "igdb_client_id" not in update_response.json()
    assert "igdb_client_secret" not in update_response.json()
    assert "igdb_credentials_encrypted" not in update_response.json()


async def test_update_own_user_clears_igdb_credentials_with_empty_strings(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(
        user_routes.settings, "steam_api_key_encryption_key", Fernet.generate_key().decode()
    )

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "clearigdbkey@example.com")
        client.put(
            "/api/user/me",
            headers=headers,
            json={"igdb_client_id": "my-client-id", "igdb_client_secret": "my-client-secret"},
        )

        clear_response = client.put(
            "/api/user/me",
            headers=headers,
            json={"igdb_client_id": "", "igdb_client_secret": ""},
        )

    assert clear_response.status_code == 200
    assert clear_response.json()["has_igdb_credentials"] is False


async def test_update_own_user_rejects_one_sided_igdb_credentials(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    """Only sending one of client_id/client_secret must be rejected,
    not silently treated as clearing the whole pair - see CodeRabbit's
    finding on #167: omitting one field (leaving it UNSET) while
    explicitly blanking or setting the other must not be able to wipe
    an existing credential pair's untouched half."""
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(
        user_routes.settings, "steam_api_key_encryption_key", Fernet.generate_key().decode()
    )

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "onesidedigdbkey@example.com")
        client.put(
            "/api/user/me",
            headers=headers,
            json={"igdb_client_id": "my-client-id", "igdb_client_secret": "my-client-secret"},
        )

        only_secret_sent = client.put(
            "/api/user/me", headers=headers, json={"igdb_client_secret": ""}
        )
        me_after = client.get("/api/user/me", headers=headers)

    assert only_secret_sent.status_code == 400
    assert me_after.json()["has_igdb_credentials"] is True


async def test_update_own_user_returns_503_when_igdb_credential_storage_not_configured(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(user_routes.settings, "steam_api_key_encryption_key", None)

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "noigdbkeystorage@example.com")
        response = client.put(
            "/api/user/me",
            headers=headers,
            json={"igdb_client_id": "my-client-id", "igdb_client_secret": "my-client-secret"},
        )

    assert response.status_code == 503


async def test_update_own_user_trims_igdb_credentials_before_storing(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    import msgspec

    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.auth.encryption import decrypt
    from backlog_manager_backend.db import async_session
    from backlog_manager_backend.integrations.types import IGDBCredentials
    from backlog_manager_backend.repositories import user_repo
    from backlog_manager_backend.routes import user as user_routes

    key = Fernet.generate_key().decode()
    monkeypatch.setattr(user_routes.settings, "steam_api_key_encryption_key", key)

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "trimigdbkey@example.com")
        client.put(
            "/api/user/me",
            headers=headers,
            json={"igdb_client_id": "  my-client-id  ", "igdb_client_secret": "  my-secret  "},
        )

    async with async_session() as session:
        stored = await user_repo.get_user_by_email(session, "trimigdbkey@example.com")

    assert stored is not None
    decrypted = msgspec.json.decode(
        decrypt(stored.igdb_credentials_encrypted, key), type=IGDBCredentials
    )
    assert decrypted.client_id == "my-client-id"
    assert decrypted.client_secret == "my-secret"


async def test_update_own_user_sets_steamgriddb_api_key(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(
        user_routes.settings, "steam_api_key_encryption_key", Fernet.generate_key().decode()
    )

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "steamgriddbkeyuser@example.com")

        update_response = client.put(
            "/api/user/me", headers=headers, json={"steamgriddb_api_key": "my-steamgriddb-key"}
        )
        me_response = client.get("/api/user/me", headers=headers)

    assert update_response.status_code == 200
    assert update_response.json()["has_steamgriddb_api_key"] is True
    assert "steamgriddb_api_key" not in update_response.json()
    assert "steamgriddb_api_key_encrypted" not in update_response.json()
    assert me_response.json()["has_steamgriddb_api_key"] is True


async def test_update_own_user_clears_steamgriddb_api_key_with_empty_string(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(
        user_routes.settings, "steam_api_key_encryption_key", Fernet.generate_key().decode()
    )

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "clearsteamgriddbkey@example.com")
        client.put(
            "/api/user/me", headers=headers, json={"steamgriddb_api_key": "my-steamgriddb-key"}
        )

        clear_response = client.put(
            "/api/user/me", headers=headers, json={"steamgriddb_api_key": ""}
        )

    assert clear_response.status_code == 200
    assert clear_response.json()["has_steamgriddb_api_key"] is False


async def test_update_own_user_returns_503_when_steamgriddb_key_storage_not_configured(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(user_routes.settings, "steam_api_key_encryption_key", None)

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "nosteamgriddbkeystorage@example.com")
        response = client.put(
            "/api/user/me", headers=headers, json={"steamgriddb_api_key": "my-steamgriddb-key"}
        )

    assert response.status_code == 503


async def test_update_own_user_returns_503_when_steamgriddb_encryption_key_is_malformed(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(user_routes.settings, "steam_api_key_encryption_key", "not-a-valid-fernet-key")

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "badsteamgriddbencryptionkey@example.com")
        response = client.put(
            "/api/user/me", headers=headers, json={"steamgriddb_api_key": "my-steamgriddb-key"}
        )

    assert response.status_code == 503


async def test_update_own_user_trims_steamgriddb_api_key_before_storing(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.auth.encryption import decrypt
    from backlog_manager_backend.db import async_session
    from backlog_manager_backend.repositories import user_repo
    from backlog_manager_backend.routes import user as user_routes

    key = Fernet.generate_key().decode()
    monkeypatch.setattr(user_routes.settings, "steam_api_key_encryption_key", key)

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "trimsteamgriddbkey@example.com")
        client.put(
            "/api/user/me",
            headers=headers,
            json={"steamgriddb_api_key": "  my-steamgriddb-key  "},
        )

    async with async_session() as session:
        stored = await user_repo.get_user_by_email(session, "trimsteamgriddbkey@example.com")

    assert stored is not None
    assert decrypt(stored.steamgriddb_api_key_encrypted, key) == "my-steamgriddb-key"


async def test_update_own_user_can_set_both_steam_and_steamgriddb_keys_independently(
    postgres_url: str, create_and_login, monkeypatch
) -> None:
    from backlog_manager_backend.app import create_app
    from backlog_manager_backend.routes import user as user_routes

    monkeypatch.setattr(
        user_routes.settings, "steam_api_key_encryption_key", Fernet.generate_key().decode()
    )

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "bothkeys@example.com")

        client.put("/api/user/me", headers=headers, json={"steam_api_key": "steam-key"})
        response = client.put(
            "/api/user/me", headers=headers, json={"steamgriddb_api_key": "griddb-key"}
        )

    assert response.status_code == 200
    body = response.json()
    assert body["has_steam_api_key"] is True
    assert body["has_steamgriddb_api_key"] is True


async def test_update_own_user_sets_steam_family_ids(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "steamfamilyuser@example.com")

        update_response = client.put(
            "/api/user/me",
            headers=headers,
            json={"steam_family_ids": "76561197960287930, 76561198000000001"},
        )
        me_response = client.get("/api/user/me", headers=headers)

    assert update_response.status_code == 200
    assert (
        update_response.json()["steam_family_ids"]
        == "76561197960287930, 76561198000000001"
    )
    assert (
        me_response.json()["steam_family_ids"] == "76561197960287930, 76561198000000001"
    )


async def test_update_own_user_clears_steam_family_ids_with_null(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    with TestClient(app=create_app()) as client:
        headers = await create_and_login(client, "clearsteamfamilyids@example.com")
        client.put(
            "/api/user/me", headers=headers, json={"steam_family_ids": "76561197960287930"}
        )

        clear_response = client.put(
            "/api/user/me", headers=headers, json={"steam_family_ids": None}
        )

    assert clear_response.status_code == 200
    assert clear_response.json()["steam_family_ids"] is None
