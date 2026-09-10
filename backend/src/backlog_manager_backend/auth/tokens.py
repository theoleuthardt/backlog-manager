"""JWT access tokens and two-factor challenge tokens.

`_ACCESS_TOKEN_LIFETIME_SECONDS` is 30 days, matching NextAuth's former JWT
session default. `_ACCESS_TOKEN_PURPOSE` and `_TWO_FACTOR_CHALLENGE_PURPOSE`
distinguish a real access token from a 2FA challenge token (issued once the
password check passes, before the second factor is checked) - without this,
a challenge token would decode successfully anywhere an access token is
accepted, bypassing 2FA entirely."""

import time

from jose import JWTError, jwt

from backlog_manager_backend.config import settings

_ALGORITHM = "HS256"
_ACCESS_TOKEN_LIFETIME_SECONDS = 60 * 60 * 24 * 30
_TWO_FACTOR_CHALLENGE_TOKEN_LIFETIME_SECONDS = 60 * 5

_ACCESS_TOKEN_PURPOSE = "access"
_TWO_FACTOR_CHALLENGE_PURPOSE = "2fa_challenge"


class TokenError(Exception):
    pass


def _decode(token: str) -> dict:
    try:
        return jwt.decode(token, settings.auth_secret, algorithms=[_ALGORITHM])
    except JWTError as error:
        raise TokenError("Invalid or expired token") from error


def _extract_subject(payload: dict) -> int:
    subject = payload.get("sub")
    if subject is None:
        raise TokenError("Token is missing its subject claim")

    try:
        return int(subject)
    except ValueError as error:
        raise TokenError("Token subject is not a valid user id") from error


def create_access_token(user_id: int) -> str:
    payload = {
        "sub": str(user_id),
        "purpose": _ACCESS_TOKEN_PURPOSE,
        "exp": int(time.time()) + _ACCESS_TOKEN_LIFETIME_SECONDS,
    }
    return jwt.encode(payload, settings.auth_secret, algorithm=_ALGORITHM)


def decode_access_token(token: str) -> int:
    """A missing purpose claim means this token was issued before the claim
    existed - it was always an access token (challenge tokens are new and
    always set purpose), so it's still accepted rather than logging out
    every existing session on deploy. Only an explicit, different purpose
    (e.g. a 2fa_challenge token) is rejected."""
    payload = _decode(token)
    if payload.get("purpose", _ACCESS_TOKEN_PURPOSE) != _ACCESS_TOKEN_PURPOSE:
        raise TokenError("Token is not an access token")
    return _extract_subject(payload)


def create_two_factor_challenge_token(user_id: int) -> str:
    payload = {
        "sub": str(user_id),
        "purpose": _TWO_FACTOR_CHALLENGE_PURPOSE,
        "exp": int(time.time()) + _TWO_FACTOR_CHALLENGE_TOKEN_LIFETIME_SECONDS,
    }
    return jwt.encode(payload, settings.auth_secret, algorithm=_ALGORITHM)


def decode_two_factor_challenge_token(token: str) -> int:
    payload = _decode(token)
    if payload.get("purpose") != _TWO_FACTOR_CHALLENGE_PURPOSE:
        raise TokenError("Token is not a two-factor challenge token")
    return _extract_subject(payload)
