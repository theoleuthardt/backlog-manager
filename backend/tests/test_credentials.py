from datetime import UTC, datetime

import msgspec
import pytest
from cryptography.fernet import Fernet

from backlog_manager_backend.integrations.types import IGDBCredentials
from backlog_manager_backend.schemas.user import User


@pytest.fixture
def credentials(postgres_url: str, monkeypatch: pytest.MonkeyPatch):
    from backlog_manager_backend.config import settings
    from backlog_manager_backend.services import credentials as module

    monkeypatch.setattr(settings, "steam_api_key_encryption_key", Fernet.generate_key().decode())
    monkeypatch.setattr(settings, "igdb_client_id", None)
    monkeypatch.setattr(settings, "igdb_client_secret", None)
    monkeypatch.setattr(settings, "steamgriddb_api_key", None)
    return module


def _user(**overrides: object) -> User:
    now = datetime.now(UTC).replace(tzinfo=None)
    return User(
        id=1, name="owner", email="owner@example.com", created_at=now, updated_at=now, **overrides
    )


def _encrypt(plaintext: str) -> str:
    from backlog_manager_backend.auth.encryption import encrypt
    from backlog_manager_backend.config import settings

    return encrypt(plaintext, settings.steam_api_key_encryption_key)


def test_igdb_credentials_prefer_the_users_own_pair(credentials, monkeypatch) -> None:
    from backlog_manager_backend.config import settings

    monkeypatch.setattr(settings, "igdb_client_id", "global-id")
    monkeypatch.setattr(settings, "igdb_client_secret", "global-secret")
    blob = msgspec.json.encode(IGDBCredentials(client_id="own-id", client_secret="own-secret"))
    user = _user(igdb_credentials_encrypted=_encrypt(blob.decode()))

    assert credentials.resolve_igdb_credentials(user) == ("own-id", "own-secret")


def test_igdb_credentials_fall_back_to_the_server_wide_pair(credentials, monkeypatch) -> None:
    from backlog_manager_backend.config import settings

    monkeypatch.setattr(settings, "igdb_client_id", "global-id")
    monkeypatch.setattr(settings, "igdb_client_secret", "global-secret")

    assert credentials.resolve_igdb_credentials(_user()) == ("global-id", "global-secret")


def test_igdb_credentials_are_none_when_nothing_is_configured(credentials) -> None:
    assert credentials.resolve_igdb_credentials(_user()) is None


def test_igdb_credentials_raise_for_an_undecryptable_stored_pair(credentials) -> None:
    user = _user(igdb_credentials_encrypted="not-a-valid-token")

    with pytest.raises(credentials.StoredCredentialError):
        credentials.resolve_igdb_credentials(user)


def test_igdb_credentials_raise_for_a_stored_blob_that_is_not_a_pair(credentials) -> None:
    user = _user(igdb_credentials_encrypted=_encrypt("not json"))

    with pytest.raises(credentials.StoredCredentialError):
        credentials.resolve_igdb_credentials(user)


def test_steamgriddb_key_prefers_the_users_own_key(credentials, monkeypatch) -> None:
    from backlog_manager_backend.config import settings

    monkeypatch.setattr(settings, "steamgriddb_api_key", "global-key")
    user = _user(steamgriddb_api_key_encrypted=_encrypt("own-key"))

    assert credentials.resolve_steamgriddb_api_key(user) == "own-key"


def test_steamgriddb_key_falls_back_to_the_server_wide_key(credentials, monkeypatch) -> None:
    from backlog_manager_backend.config import settings

    monkeypatch.setattr(settings, "steamgriddb_api_key", "global-key")

    assert credentials.resolve_steamgriddb_api_key(_user()) == "global-key"


def test_steamgriddb_key_is_none_when_nothing_is_configured(credentials) -> None:
    assert credentials.resolve_steamgriddb_api_key(_user()) is None


def test_steamgriddb_key_raises_for_an_undecryptable_stored_key(credentials) -> None:
    user = _user(steamgriddb_api_key_encrypted="not-a-valid-token")

    with pytest.raises(credentials.StoredCredentialError):
        credentials.resolve_steamgriddb_api_key(user)


def test_lenient_igdb_credentials_treat_a_broken_stored_pair_like_a_missing_one(
    credentials,
) -> None:
    user = _user(igdb_credentials_encrypted="not-a-valid-token")

    assert credentials.resolve_igdb_credentials_or_none(user) is None


def test_lenient_igdb_credentials_still_resolve_a_working_pair(credentials, monkeypatch) -> None:
    from backlog_manager_backend.config import settings

    monkeypatch.setattr(settings, "igdb_client_id", "global-id")
    monkeypatch.setattr(settings, "igdb_client_secret", "global-secret")

    assert credentials.resolve_igdb_credentials_or_none(_user()) == ("global-id", "global-secret")


def test_lenient_steamgriddb_key_treats_a_broken_stored_key_like_a_missing_one(
    credentials,
) -> None:
    user = _user(steamgriddb_api_key_encrypted="not-a-valid-token")

    assert credentials.resolve_steamgriddb_api_key_or_none(user) is None


def test_lenient_steamgriddb_key_still_resolves_a_working_key(credentials) -> None:
    user = _user(steamgriddb_api_key_encrypted=_encrypt("own-key"))

    assert credentials.resolve_steamgriddb_api_key_or_none(user) == "own-key"


def test_stored_credentials_are_ignored_without_an_encryption_key(credentials, monkeypatch) -> None:
    from backlog_manager_backend.config import settings

    user = _user(steamgriddb_api_key_encrypted=_encrypt("own-key"))
    monkeypatch.setattr(settings, "steam_api_key_encryption_key", None)
    monkeypatch.setattr(settings, "steamgriddb_api_key", "global-key")

    assert credentials.resolve_steamgriddb_api_key(user) == "global-key"
