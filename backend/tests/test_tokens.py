import time
from types import ModuleType

import pytest


@pytest.fixture
def tokens() -> ModuleType:
    """Imported lazily since backlog_manager_backend.auth.tokens imports
    config at module scope, and config eagerly builds Settings() on
    import - see the game_service fixture in test_game_service.py for
    the same pattern."""
    from backlog_manager_backend.auth import tokens as module

    return module


def test_create_and_decode_access_token_round_trips(tokens: ModuleType) -> None:
    token = tokens.create_access_token(42)

    assert tokens.decode_access_token(token) == 42


def test_decode_access_token_rejects_garbage(tokens: ModuleType) -> None:
    with pytest.raises(tokens.TokenError):
        tokens.decode_access_token("not-a-jwt")


def test_decode_access_token_rejects_expired_token(
    tokens: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(tokens, "_ACCESS_TOKEN_LIFETIME_SECONDS", -1)
    expired_token = tokens.create_access_token(42)

    with pytest.raises(tokens.TokenError):
        tokens.decode_access_token(expired_token)


def test_decode_access_token_rejects_wrong_signature(
    tokens: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    token = tokens.create_access_token(42)

    monkeypatch.setattr(tokens.settings, "auth_secret", "a-completely-different-secret")

    with pytest.raises(tokens.TokenError):
        tokens.decode_access_token(token)


def test_decode_access_token_rejects_non_integer_subject(tokens: ModuleType) -> None:
    from jose import jwt

    bad_token = jwt.encode(
        {"sub": "not-an-id", "exp": int(time.time()) + 60},
        tokens.settings.auth_secret,
        algorithm="HS256",
    )

    with pytest.raises(tokens.TokenError):
        tokens.decode_access_token(bad_token)


def test_create_and_decode_two_factor_challenge_token_round_trips(tokens: ModuleType) -> None:
    token = tokens.create_two_factor_challenge_token(42)

    assert tokens.decode_two_factor_challenge_token(token) == 42


def test_decode_two_factor_challenge_token_rejects_expired_token(
    tokens: ModuleType, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(tokens, "_TWO_FACTOR_CHALLENGE_TOKEN_LIFETIME_SECONDS", -1)
    expired_token = tokens.create_two_factor_challenge_token(42)

    with pytest.raises(tokens.TokenError):
        tokens.decode_two_factor_challenge_token(expired_token)


def test_decode_access_token_rejects_a_two_factor_challenge_token(tokens: ModuleType) -> None:
    """A challenge token only proves "password already checked, second
    factor still owed" - if it were accepted anywhere a real access
    token is, 2FA would be bypassable by stopping right after the
    password check, before any code is ever entered."""
    challenge_token = tokens.create_two_factor_challenge_token(42)

    with pytest.raises(tokens.TokenError):
        tokens.decode_access_token(challenge_token)


def test_decode_two_factor_challenge_token_rejects_a_real_access_token(tokens: ModuleType) -> None:
    access_token = tokens.create_access_token(42)

    with pytest.raises(tokens.TokenError):
        tokens.decode_two_factor_challenge_token(access_token)


def test_decode_access_token_accepts_a_legacy_token_with_no_purpose_claim(
    tokens: ModuleType,
) -> None:
    """Tokens issued before the purpose claim existed have no `purpose` at
    all - they must still decode as access tokens, or every session up to
    the 30-day lifetime gets logged out the moment this claim ships."""
    from jose import jwt

    legacy_token = jwt.encode(
        {"sub": "42", "exp": int(time.time()) + 60},
        tokens.settings.auth_secret,
        algorithm="HS256",
    )

    assert tokens.decode_access_token(legacy_token) == 42
