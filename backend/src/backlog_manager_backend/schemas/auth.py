import msgspec


class LoginParams(msgspec.Struct):
    email: str
    password: str


class TokenResponse(msgspec.Struct):
    access_token: str
    token_type: str = "bearer"
