import time

from jose import JWTError, jwt

from backlog_manager_backend.config import settings

_ALGORITHM = "HS256"
_ACCESS_TOKEN_LIFETIME_SECONDS = (
    60 * 60 * 24 * 30
)  # 30 days, matching NextAuth's JWT session default


class TokenError(Exception):
    pass


def create_access_token(user_id: int) -> str:
    payload = {"sub": str(user_id), "exp": int(time.time()) + _ACCESS_TOKEN_LIFETIME_SECONDS}
    return jwt.encode(payload, settings.auth_secret, algorithm=_ALGORITHM)


def decode_access_token(token: str) -> int:
    try:
        payload = jwt.decode(token, settings.auth_secret, algorithms=[_ALGORITHM])
    except JWTError as error:
        raise TokenError("Invalid or expired token") from error

    subject = payload.get("sub")
    if subject is None:
        raise TokenError("Token is missing its subject claim")

    try:
        return int(subject)
    except ValueError as error:
        raise TokenError("Token subject is not a valid user id") from error
