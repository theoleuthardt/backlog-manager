import msgspec


class LoginParams(msgspec.Struct):
    email: str
    password: str


class TokenResponse(msgspec.Struct):
    access_token: str
    token_type: str = "bearer"


class LoginResult(msgspec.Struct):
    """access_token is set for a normal successful login; challenge_token
    is set instead when the account has 2FA enabled, and must be
    exchanged (together with a TOTP/backup code) at /api/auth/2fa/login-
    verify for a real access_token."""

    access_token: str | None = None
    requires_2fa: bool = False
    challenge_token: str | None = None


class TwoFactorEnrollResponse(msgspec.Struct):
    secret: str
    otpauth_url: str


class TwoFactorVerifyEnrollmentParams(msgspec.Struct):
    code: str


class TwoFactorVerifyEnrollmentResponse(msgspec.Struct):
    backup_codes: list[str]


class TwoFactorDisableParams(msgspec.Struct):
    password: str


class TwoFactorLoginVerifyParams(msgspec.Struct):
    challenge_token: str
    code: str
