from types import ModuleType

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.errors import ConflictError, ValidationError
from backlog_manager_backend.repositories import user_repo
from backlog_manager_backend.schemas.user import CreateUserParams


@pytest.fixture
def auth_service() -> ModuleType:
    """Imported lazily - see test_game_service.py's game_service fixture
    for why (services.auth_service -> auth.tokens -> config eagerly
    builds Settings() on import)."""
    from backlog_manager_backend.services import auth_service as module

    return module


async def test_create_user_creates_user_with_hashed_password(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.user import CreateUserRequest

    user = await auth_service.create_user(
        session,
        CreateUserRequest(username="newuser", email="newuser@example.com", password="hunter22"),
    )

    assert user.name == "newuser"
    assert user.email == "newuser@example.com"
    assert user.is_admin is False
    assert user.password_hash != "hunter22"


async def test_create_user_can_create_an_admin(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.user import CreateUserRequest

    user = await auth_service.create_user(
        session,
        CreateUserRequest(
            username="newadmin", email="newadmin@example.com", password="hunter22", is_admin=True
        ),
    )

    assert user.is_admin is True


async def test_create_user_rejects_duplicate_email(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.user import CreateUserRequest

    await auth_service.create_user(
        session,
        CreateUserRequest(username="first", email="dupe@example.com", password="hunter22"),
    )

    with pytest.raises(ConflictError):
        await auth_service.create_user(
            session,
            CreateUserRequest(username="second", email="dupe@example.com", password="hunter22"),
        )


async def test_create_user_rejects_short_password(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.user import CreateUserRequest

    with pytest.raises(ValidationError):
        await auth_service.create_user(
            session,
            CreateUserRequest(username="shortpw", email="shortpw@example.com", password="short"),
        )


async def test_login_returns_token_for_correct_credentials(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.auth.tokens import decode_access_token
    from backlog_manager_backend.schemas.auth import LoginParams
    from backlog_manager_backend.schemas.user import CreateUserRequest

    user = await auth_service.create_user(
        session,
        CreateUserRequest(username="loginuser", email="loginuser@example.com", password="hunter22"),
    )

    result = await auth_service.login(
        session, LoginParams(email="loginuser@example.com", password="hunter22")
    )

    assert result.requires_2fa is False
    assert result.challenge_token is None
    assert decode_access_token(result.access_token) == user.id


async def test_login_rejects_wrong_password(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.auth import LoginParams
    from backlog_manager_backend.schemas.user import CreateUserRequest

    await auth_service.create_user(
        session,
        CreateUserRequest(username="wrongpw", email="wrongpw@example.com", password="hunter22"),
    )

    with pytest.raises(ValidationError):
        await auth_service.login(
            session, LoginParams(email="wrongpw@example.com", password="not-hunter22")
        )


async def test_login_rejects_unknown_email(auth_service: ModuleType, session: AsyncSession) -> None:
    from backlog_manager_backend.schemas.auth import LoginParams

    with pytest.raises(ValidationError):
        await auth_service.login(
            session, LoginParams(email="nobody@example.com", password="hunter22")
        )


async def test_login_rejects_oauth_only_account_with_empty_password_hash(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.schemas.auth import LoginParams

    await user_repo.create_user(
        session,
        CreateUserParams(username="oauthuser", email="oauthuser@example.com", password_hash=""),
    )

    with pytest.raises(ValidationError):
        await auth_service.login(
            session, LoginParams(email="oauthuser@example.com", password="anything")
        )


async def test_login_verifies_a_password_hash_even_for_unknown_email(
    auth_service: ModuleType, session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Regression test for a timing side-channel: skipping Argon2
    verification for an unknown email would make that path measurably
    faster than a wrong-password attempt against a real account,
    letting an attacker enumerate registered emails by response time.
    Asserts the structural fix (verify_password always runs against
    some hash) rather than measuring wall-clock time, which would be
    flaky in CI."""
    from backlog_manager_backend.schemas.auth import LoginParams

    calls: list[str] = []
    monkeypatch.setattr(
        auth_service,
        "verify_password",
        lambda password_hash, password: calls.append(password_hash) or False,
    )

    with pytest.raises(ValidationError):
        await auth_service.login(
            session, LoginParams(email="nobody@example.com", password="anything")
        )

    assert calls == [auth_service._DUMMY_PASSWORD_HASH]


async def _create_user(auth_service: ModuleType, session: AsyncSession, email: str):
    from backlog_manager_backend.schemas.user import CreateUserRequest

    return await auth_service.create_user(
        session,
        CreateUserRequest(username=email.split("@")[0], email=email, password="hunter22"),
    )


async def test_enroll_two_factor_returns_secret_and_otpauth_url(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    user = await _create_user(auth_service, session, "enroll@example.com")

    enrollment = await auth_service.enroll_two_factor(session, user)

    assert enrollment.secret
    assert enrollment.otpauth_url.startswith("otpauth://totp/")
    assert enrollment.secret in enrollment.otpauth_url


async def test_enroll_two_factor_rejects_when_already_enabled(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    import pyotp

    user = await _create_user(auth_service, session, "reenroll@example.com")
    enrollment = await auth_service.enroll_two_factor(session, user)
    user = await user_repo.get_user_by_id(session, user.id)
    await auth_service.verify_two_factor_enrollment(
        session, user, pyotp.TOTP(enrollment.secret).now()
    )
    user = await user_repo.get_user_by_id(session, user.id)

    with pytest.raises(ConflictError):
        await auth_service.enroll_two_factor(session, user)


async def test_verify_two_factor_enrollment_enables_it_and_returns_backup_codes(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    import pyotp

    user = await _create_user(auth_service, session, "verify@example.com")
    enrollment = await auth_service.enroll_two_factor(session, user)
    user = await user_repo.get_user_by_id(session, user.id)

    backup_codes = await auth_service.verify_two_factor_enrollment(
        session, user, pyotp.TOTP(enrollment.secret).now()
    )

    assert len(backup_codes) == 10
    assert len({*backup_codes}) == 10
    user = await user_repo.get_user_by_id(session, user.id)
    assert user.totp_enabled is True


async def test_verify_two_factor_enrollment_rejects_wrong_code(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    user = await _create_user(auth_service, session, "wrongcode@example.com")
    await auth_service.enroll_two_factor(session, user)
    user = await user_repo.get_user_by_id(session, user.id)

    with pytest.raises(ValidationError):
        await auth_service.verify_two_factor_enrollment(session, user, "000000")

    user = await user_repo.get_user_by_id(session, user.id)
    assert user.totp_enabled is False


async def test_verify_two_factor_enrollment_rejects_when_nothing_enrolled(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    user = await _create_user(auth_service, session, "noenroll@example.com")

    with pytest.raises(ValidationError):
        await auth_service.verify_two_factor_enrollment(session, user, "000000")


async def test_verify_two_factor_enrollment_rejects_a_repeat_call_once_enabled(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    """A second successful verification (e.g. a double-submit) must not
    silently append another active backup-code set on top of the first."""
    import pyotp

    from backlog_manager_backend.repositories import backup_code_repo

    user = await _create_user(auth_service, session, "repeatverify@example.com")
    enrollment = await auth_service.enroll_two_factor(session, user)
    user = await user_repo.get_user_by_id(session, user.id)
    first_backup_codes = await auth_service.verify_two_factor_enrollment(
        session, user, pyotp.TOTP(enrollment.secret).now()
    )
    user = await user_repo.get_user_by_id(session, user.id)

    with pytest.raises(ConflictError):
        await auth_service.verify_two_factor_enrollment(
            session, user, pyotp.TOTP(enrollment.secret).now()
        )

    assert await backup_code_repo.verify_and_consume_backup_code(
        session, user.id, first_backup_codes[0]
    ) is True


async def _enroll_and_enable(auth_service: ModuleType, session: AsyncSession, email: str):
    import pyotp

    user = await _create_user(auth_service, session, email)
    enrollment = await auth_service.enroll_two_factor(session, user)
    user = await user_repo.get_user_by_id(session, user.id)
    backup_codes = await auth_service.verify_two_factor_enrollment(
        session, user, pyotp.TOTP(enrollment.secret).now()
    )
    user = await user_repo.get_user_by_id(session, user.id)
    return user, enrollment.secret, backup_codes


async def test_disable_two_factor_clears_secret_and_backup_codes(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.repositories import backup_code_repo

    user, _secret, backup_codes = await _enroll_and_enable(
        auth_service, session, "disable@example.com"
    )

    await auth_service.disable_two_factor(session, user, "hunter22")

    user = await user_repo.get_user_by_id(session, user.id)
    assert user.totp_enabled is False
    assert user.totp_secret_encrypted is None
    assert await backup_code_repo.verify_and_consume_backup_code(
        session, user.id, backup_codes[0]
    ) is False


async def test_disable_two_factor_rejects_wrong_password(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    user, _secret, _backup_codes = await _enroll_and_enable(
        auth_service, session, "disablewrongpw@example.com"
    )

    with pytest.raises(ValidationError):
        await auth_service.disable_two_factor(session, user, "not-hunter22")

    user = await user_repo.get_user_by_id(session, user.id)
    assert user.totp_enabled is True


async def test_disable_two_factor_verifies_a_password_hash_even_for_a_bad_guess(
    auth_service: ModuleType, session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Same timing-safety discipline as login: the password check on a
    sensitive action like disabling 2FA must always run Argon2
    verification against some hash, never short-circuit."""
    user, _secret, _backup_codes = await _enroll_and_enable(
        auth_service, session, "disabletiming@example.com"
    )

    calls: list[str] = []
    monkeypatch.setattr(
        auth_service,
        "verify_password",
        lambda password_hash, password: calls.append(password_hash) or False,
    )

    with pytest.raises(ValidationError):
        await auth_service.disable_two_factor(session, user, "anything")

    assert calls == [user.password_hash]


async def test_verify_two_factor_login_succeeds_with_a_totp_code(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    import pyotp

    from backlog_manager_backend.auth.tokens import (
        create_two_factor_challenge_token,
        decode_access_token,
    )

    user, secret, _backup_codes = await _enroll_and_enable(
        auth_service, session, "loginverify@example.com"
    )
    challenge_token = create_two_factor_challenge_token(user.id)

    access_token = await auth_service.verify_two_factor_login(
        session, challenge_token, pyotp.TOTP(secret).now()
    )

    assert decode_access_token(access_token) == user.id


async def test_verify_two_factor_login_succeeds_with_a_backup_code_and_consumes_it(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.auth.tokens import (
        create_two_factor_challenge_token,
        decode_access_token,
    )

    user, _secret, backup_codes = await _enroll_and_enable(
        auth_service, session, "loginbackup@example.com"
    )
    challenge_token = create_two_factor_challenge_token(user.id)

    access_token = await auth_service.verify_two_factor_login(
        session, challenge_token, backup_codes[0]
    )

    assert decode_access_token(access_token) == user.id

    with pytest.raises(ValidationError):
        await auth_service.verify_two_factor_login(
            session, create_two_factor_challenge_token(user.id), backup_codes[0]
        )


async def test_verify_two_factor_login_rejects_wrong_code(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.auth.tokens import create_two_factor_challenge_token

    user, _secret, _backup_codes = await _enroll_and_enable(
        auth_service, session, "loginwrongcode@example.com"
    )

    with pytest.raises(ValidationError):
        await auth_service.verify_two_factor_login(
            session, create_two_factor_challenge_token(user.id), "000000"
        )


async def test_verify_two_factor_login_rejects_an_expired_challenge_token(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.auth import tokens

    user, secret, _backup_codes = await _enroll_and_enable(
        auth_service, session, "loginexpired@example.com"
    )
    original_lifetime = tokens._TWO_FACTOR_CHALLENGE_TOKEN_LIFETIME_SECONDS
    tokens._TWO_FACTOR_CHALLENGE_TOKEN_LIFETIME_SECONDS = -1
    try:
        expired_token = tokens.create_two_factor_challenge_token(user.id)
    finally:
        tokens._TWO_FACTOR_CHALLENGE_TOKEN_LIFETIME_SECONDS = original_lifetime

    import pyotp

    with pytest.raises(ValidationError):
        await auth_service.verify_two_factor_login(session, expired_token, pyotp.TOTP(secret).now())


async def test_verify_two_factor_login_rejects_a_real_access_token_used_as_a_challenge(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.auth.tokens import create_access_token

    user, secret, _backup_codes = await _enroll_and_enable(
        auth_service, session, "loginwrongpurpose@example.com"
    )
    import pyotp

    with pytest.raises(ValidationError):
        await auth_service.verify_two_factor_login(
            session, create_access_token(user.id), pyotp.TOTP(secret).now()
        )


async def test_login_returns_a_challenge_when_two_factor_is_enabled(
    auth_service: ModuleType, session: AsyncSession
) -> None:
    from backlog_manager_backend.auth.tokens import decode_two_factor_challenge_token
    from backlog_manager_backend.schemas.auth import LoginParams

    user, _secret, _backup_codes = await _enroll_and_enable(
        auth_service, session, "twofactorlogin@example.com"
    )

    result = await auth_service.login(
        session, LoginParams(email="twofactorlogin@example.com", password="hunter22")
    )

    assert result.requires_2fa is True
    assert result.access_token is None
    assert decode_two_factor_challenge_token(result.challenge_token) == user.id
