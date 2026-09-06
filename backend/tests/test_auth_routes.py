import pyotp
from litestar.testing import TestClient


async def test_login_returns_access_token_for_correct_credentials(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "routeuser@example.com")

    assert headers["Authorization"].startswith("Bearer ")


async def test_login_rejects_wrong_password(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        await create_and_login(client, "wrongpwroute@example.com", password="hunter22")
        login_response = client.post(
            "/api/auth/login",
            json={"email": "wrongpwroute@example.com", "password": "not-hunter22"},
        )

    assert login_response.status_code == 401


async def test_login_rejects_unknown_email(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        login_response = client.post(
            "/api/auth/login",
            json={"email": "nobody@example.com", "password": "hunter22"},
        )

    assert login_response.status_code == 401


def test_login_is_rate_limited(postgres_url: str) -> None:
    """Login is capped at 10 requests/minute per client (see
    routes/auth.py) - the highest-value brute-force target in the API.
    A fresh app per test (via create_app(), not the shared module-level
    singleton) means this doesn't interfere with other tests' login
    calls - see create_app()'s docstring."""
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        responses = [
            client.post("/api/auth/login", json={"email": "nobody@example.com", "password": "x"})
            for _ in range(11)
        ]

    assert [response.status_code for response in responses[:10]] == [401] * 10
    assert responses[-1].status_code == 429


async def test_enroll_two_factor_returns_secret_and_otpauth_url(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "enrollroute@example.com")
        response = client.post("/api/auth/2fa/enroll", headers=headers)

    assert response.status_code == 201
    body = response.json()
    assert body["secret"]
    assert body["otpauth_url"].startswith("otpauth://totp/")


async def test_enroll_two_factor_requires_authentication(postgres_url: str) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        response = client.post("/api/auth/2fa/enroll")

    assert response.status_code == 401


async def _enroll_and_verify(client: TestClient, headers: dict[str, str]) -> tuple[str, list[str]]:
    enroll_response = client.post("/api/auth/2fa/enroll", headers=headers)
    secret = enroll_response.json()["secret"]

    verify_response = client.post(
        "/api/auth/2fa/verify", json={"code": pyotp.TOTP(secret).now()}, headers=headers
    )
    return secret, verify_response.json()["backup_codes"]


async def test_verify_two_factor_enables_it_and_returns_backup_codes(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "verifyroute@example.com")
        enroll_response = client.post("/api/auth/2fa/enroll", headers=headers)
        secret = enroll_response.json()["secret"]

        verify_response = client.post(
            "/api/auth/2fa/verify", json={"code": pyotp.TOTP(secret).now()}, headers=headers
        )

        me_response = client.get("/api/user/me", headers=headers)

    assert verify_response.status_code == 200
    assert len(verify_response.json()["backup_codes"]) == 10
    assert me_response.json()["is_two_factor_enabled"] is True


async def test_verify_two_factor_rejects_wrong_code_without_invalidating_the_session(
    postgres_url: str, create_and_login
) -> None:
    """A mistyped code must not silently log the user out: the frontend
    wipes its stored token on any 401, so a wrong-code response here
    has to be a 400, not a 401 (unlike login, which has no session yet
    to lose)."""
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "verifywrongroute@example.com")
        client.post("/api/auth/2fa/enroll", headers=headers)

        verify_response = client.post(
            "/api/auth/2fa/verify", json={"code": "000000"}, headers=headers
        )
        me_response = client.get("/api/user/me", headers=headers)

    assert verify_response.status_code == 400
    assert me_response.status_code == 200


async def test_enroll_two_factor_rejects_when_already_enabled(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "reenrollroute@example.com")
        await _enroll_and_verify(client, headers)

        second_enroll_response = client.post("/api/auth/2fa/enroll", headers=headers)

    assert second_enroll_response.status_code == 409


async def test_verify_two_factor_rejects_a_repeat_call_once_enabled(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "reverifyroute@example.com")
        secret, _backup_codes = await _enroll_and_verify(client, headers)

        second_verify_response = client.post(
            "/api/auth/2fa/verify", json={"code": pyotp.TOTP(secret).now()}, headers=headers
        )

    assert second_verify_response.status_code == 409


async def test_login_requires_a_second_step_once_two_factor_is_enabled(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "twofactorloginroute@example.com")
        secret, _backup_codes = await _enroll_and_verify(client, headers)

        login_response = client.post(
            "/api/auth/login",
            json={"email": "twofactorloginroute@example.com", "password": "hunter22"},
        )
        login_body = login_response.json()

        verify_login_response = client.post(
            "/api/auth/2fa/login-verify",
            json={
                "challenge_token": login_body["challenge_token"],
                "code": pyotp.TOTP(secret).now(),
            },
        )
        access_token = verify_login_response.json()["access_token"]
        me_response = client.get(
            "/api/user/me", headers={"Authorization": f"Bearer {access_token}"}
        )

    assert login_response.status_code == 200
    assert login_body["requires_2fa"] is True
    assert login_body["access_token"] is None
    assert verify_login_response.status_code == 200
    assert me_response.status_code == 200
    assert me_response.json()["email"] == "twofactorloginroute@example.com"


async def test_login_verify_rejects_wrong_code(postgres_url: str, create_and_login) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "loginverifywrongroute@example.com")
        await _enroll_and_verify(client, headers)

        login_response = client.post(
            "/api/auth/login",
            json={"email": "loginverifywrongroute@example.com", "password": "hunter22"},
        )
        challenge_token = login_response.json()["challenge_token"]

        verify_login_response = client.post(
            "/api/auth/2fa/login-verify",
            json={"challenge_token": challenge_token, "code": "000000"},
        )

    assert verify_login_response.status_code == 401


async def test_login_verify_backup_code_can_only_be_used_once(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "backuponceroute@example.com")
        _secret, backup_codes = await _enroll_and_verify(client, headers)

        def get_challenge_token() -> str:
            response = client.post(
                "/api/auth/login",
                json={"email": "backuponceroute@example.com", "password": "hunter22"},
            )
            return response.json()["challenge_token"]

        first_response = client.post(
            "/api/auth/2fa/login-verify",
            json={"challenge_token": get_challenge_token(), "code": backup_codes[0]},
        )
        second_response = client.post(
            "/api/auth/2fa/login-verify",
            json={"challenge_token": get_challenge_token(), "code": backup_codes[0]},
        )

    assert first_response.status_code == 200
    assert second_response.status_code == 401


async def test_a_two_factor_challenge_token_cannot_be_used_as_a_bearer_token(
    postgres_url: str, create_and_login
) -> None:
    """Direct regression test for the purpose-claim fix: a challenge
    token only proves the password check passed, not the second
    factor - it must never grant access to a normal authenticated
    route on its own."""
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "purposeconfusionroute@example.com")
        await _enroll_and_verify(client, headers)

        login_response = client.post(
            "/api/auth/login",
            json={"email": "purposeconfusionroute@example.com", "password": "hunter22"},
        )
        challenge_token = login_response.json()["challenge_token"]

        me_response = client.get(
            "/api/user/me", headers={"Authorization": f"Bearer {challenge_token}"}
        )

    assert me_response.status_code == 401


async def test_disable_two_factor_requires_correct_password(
    postgres_url: str, create_and_login
) -> None:
    from backlog_manager_backend.app import create_app

    app = create_app()

    with TestClient(app=app) as client:
        headers = await create_and_login(client, "disableroute@example.com")
        await _enroll_and_verify(client, headers)

        wrong_password_response = client.post(
            "/api/auth/2fa/disable", json={"password": "not-hunter22"}, headers=headers
        )
        disable_response = client.post(
            "/api/auth/2fa/disable", json={"password": "hunter22"}, headers=headers
        )
        me_response = client.get("/api/user/me", headers=headers)

    assert wrong_password_response.status_code == 400
    assert disable_response.status_code == 204
    assert me_response.json()["is_two_factor_enabled"] is False
