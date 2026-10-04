from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from backlog_manager_backend.auth.backup_codes import generate_backup_codes
from backlog_manager_backend.auth.passwords import hash_password, verify_password
from backlog_manager_backend.auth.tokens import (
    TokenError,
    create_access_token,
    create_two_factor_challenge_token,
    decode_two_factor_challenge_token,
)
from backlog_manager_backend.auth.totp import (
    build_otpauth_url,
    decrypt_secret,
    encrypt_secret,
    generate_secret,
    verify_totp_code,
)
from backlog_manager_backend.errors import ConflictError, NotFoundError, ValidationError
from backlog_manager_backend.repositories import backup_code_repo, user_repo
from backlog_manager_backend.schemas.auth import (
    LoginParams,
    LoginResult,
    TwoFactorEnrollResponse,
)
from backlog_manager_backend.schemas.user import (
    CreateUserParams,
    CreateUserRequest,
    UpdateUserParams,
    User,
)

_DUMMY_PASSWORD_HASH = hash_password("not-a-real-password-used-only-for-timing")

MIN_PASSWORD_LENGTH = 12
MAX_PASSWORD_LENGTH = 128
MAX_FAILED_LOGIN_ATTEMPTS = 5
LOGIN_LOCK_DURATION = timedelta(minutes=15)

_INVALID_CREDENTIALS = "Invalid email or password"


def validate_password_strength(password: str) -> None:
    """The upper bound keeps an attacker from making the server spend
    Argon2 time on megabyte-sized "passwords"."""
    if len(password) < MIN_PASSWORD_LENGTH:
        raise ValidationError(f"Password must be at least {MIN_PASSWORD_LENGTH} characters long")
    if len(password) > MAX_PASSWORD_LENGTH:
        raise ValidationError(f"Password must be at most {MAX_PASSWORD_LENGTH} characters long")


def _is_locked(user: User) -> bool:
    return user.locked_until is not None and user.locked_until > datetime.now(UTC).replace(
        tzinfo=None
    )


async def revoke_sessions(session: AsyncSession, user_id: int) -> None:
    """Invalidates every access token issued for this user so far."""
    await user_repo.bump_token_version(session, user_id)


async def create_user(session: AsyncSession, params: CreateUserRequest) -> User:
    """There is no public self-registration endpoint - every account is
    created by an admin (or, for the very first account, the startup
    bootstrap in bootstrap.py), so this is only ever reached with an
    already-authorized caller."""
    validate_password_strength(params.password)

    return await user_repo.create_user(
        session,
        CreateUserParams(
            username=params.username,
            email=params.email,
            password_hash=hash_password(params.password),
            steam_id=params.steam_id,
            is_admin=params.is_admin,
        ),
    )


async def login(session: AsyncSession, params: LoginParams) -> LoginResult:
    """Raises ValidationError for any invalid-credentials case (unknown
    email, wrong password, or an OAuth-only account with no password
    set) without distinguishing which, in the error message or in
    timing - an unknown email still runs a dummy Argon2 verification
    against _DUMMY_PASSWORD_HASH so that path pays the same cost as a
    real wrong-password attempt, rather than responding measurably
    faster and letting an attacker enumerate which emails are
    registered. Once the password check passes, an account with 2FA
    enabled gets a short-lived challenge token instead of a real access
    token - see verify_two_factor_login.

    After MAX_FAILED_LOGIN_ATTEMPTS wrong passwords the account is locked
    for LOGIN_LOCK_DURATION; a locked account answers with the same
    generic error even for the correct password, so the lock itself
    reveals nothing. The failed-attempt counter is only reset by a fully
    completed login (after the second factor, when one is enabled) -
    resetting it on the password step alone would give an attacker who
    knows the password unlimited second-factor guesses."""
    user = await user_repo.get_user_by_email(session, params.email)
    password_hash = user.password_hash if user and user.password_hash else _DUMMY_PASSWORD_HASH
    password_matches = verify_password(password_hash, params.password)

    if user is not None and _is_locked(user):
        raise ValidationError(_INVALID_CREDENTIALS)

    if user is None or not user.password_hash or not password_matches:
        if user is not None:
            await user_repo.record_failed_login(
                session, user.id, MAX_FAILED_LOGIN_ATTEMPTS, LOGIN_LOCK_DURATION
            )
        raise ValidationError(_INVALID_CREDENTIALS)

    if user.totp_enabled:
        return LoginResult(
            requires_2fa=True, challenge_token=create_two_factor_challenge_token(user.id)
        )

    await _reset_failed_logins_if_needed(session, user)
    return LoginResult(access_token=create_access_token(user.id, user.token_version))


async def _reset_failed_logins_if_needed(session: AsyncSession, user: User) -> None:
    if user.failed_login_attempts or user.locked_until is not None:
        await user_repo.reset_failed_logins(session, user.id)


async def enroll_two_factor(session: AsyncSession, user: User) -> TwoFactorEnrollResponse:
    """Always overwrites any previous (unconfirmed) secret - safe only
    because totp_enabled stays False until verify_two_factor_enrollment
    succeeds. Rejects outright if 2FA is already enabled: otherwise this
    would silently replace a working secret with an unconfirmed one,
    breaking the user's next real login before they've verified the
    replacement."""
    if user.totp_enabled:
        raise ConflictError("Two-factor authentication is already enabled")

    secret = generate_secret()
    await user_repo.update_user(
        session, UpdateUserParams(user_id=user.id, totp_secret_encrypted=encrypt_secret(secret))
    )
    return TwoFactorEnrollResponse(secret=secret, otpauth_url=build_otpauth_url(secret, user.email))


async def verify_two_factor_enrollment(session: AsyncSession, user: User, code: str) -> list[str]:
    """On success, turns 2FA on and returns a fresh set of backup codes
    in plaintext - the only time they're ever available unhashed.
    Rejects an already-enabled account (mirrors enroll_two_factor's own
    guard) so a repeated verification call can't silently append another
    active backup-code set. Backup codes are created BEFORE totp_enabled
    is flipped, not after: if code creation fails, the account correctly
    stays not-enabled and the same enrollment can just be retried, rather
    than ending up enabled with zero recovery codes."""
    if user.totp_enabled:
        raise ConflictError("Two-factor authentication is already enabled")
    if not user.totp_secret_encrypted:
        raise ValidationError("No two-factor enrollment in progress")

    secret = decrypt_secret(user.totp_secret_encrypted)
    if not verify_totp_code(secret, code):
        raise ValidationError("Invalid two-factor code")

    backup_codes = generate_backup_codes()
    await backup_code_repo.create_backup_codes(
        session, user.id, [hash_password(backup_code) for backup_code in backup_codes]
    )
    await user_repo.update_user(session, UpdateUserParams(user_id=user.id, totp_enabled=True))
    return backup_codes


async def disable_two_factor(session: AsyncSession, user: User, password: str) -> None:
    """Requires re-entering the password since this is a sensitive
    action - same timing-safety discipline as login's own password
    check."""
    password_hash = user.password_hash if user.password_hash else _DUMMY_PASSWORD_HASH
    password_matches = verify_password(password_hash, password)
    if not user.password_hash or not password_matches:
        raise ValidationError("Invalid password")

    await user_repo.update_user(
        session,
        UpdateUserParams(user_id=user.id, totp_secret_encrypted=None, totp_enabled=False),
    )
    await backup_code_repo.delete_all_backup_codes(session, user.id)
    await revoke_sessions(session, user.id)


async def verify_two_factor_login(session: AsyncSession, challenge_token: str, code: str) -> str:
    """The second login step: exchanges a challenge token (issued by
    login() once the password check passed) plus a TOTP or backup code
    for a real access token."""
    try:
        user_id = decode_two_factor_challenge_token(challenge_token)
    except TokenError as error:
        raise ValidationError("Invalid or expired two-factor challenge") from error

    try:
        user = await user_repo.get_user_by_id(session, user_id)
    except NotFoundError as error:
        raise ValidationError("Invalid or expired two-factor challenge") from error

    if not user.totp_enabled or not user.totp_secret_encrypted:
        raise ValidationError("Two-factor authentication is not enabled for this account")

    if _is_locked(user):
        raise ValidationError("Invalid or expired two-factor challenge")

    secret = decrypt_secret(user.totp_secret_encrypted)
    if verify_totp_code(secret, code) or await backup_code_repo.verify_and_consume_backup_code(
        session, user.id, code
    ):
        await _reset_failed_logins_if_needed(session, user)
        return create_access_token(user.id, user.token_version)

    await user_repo.record_failed_login(
        session, user.id, MAX_FAILED_LOGIN_ATTEMPTS, LOGIN_LOCK_DURATION
    )
    raise ValidationError("Invalid two-factor code")
