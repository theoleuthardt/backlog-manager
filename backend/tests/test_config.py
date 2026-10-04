import pytest
from cryptography.fernet import Fernet
from pydantic import ValidationError


def _settings(**overrides: object):
    from backlog_manager_backend.config import Settings

    values: dict[str, object] = {
        "postgres_url": "postgresql+asyncpg://u:p@localhost/db",
        "auth_secret": "a-sufficiently-long-random-secret-value",
        "totp_encryption_key": Fernet.generate_key().decode(),
    }
    values.update(overrides)
    return Settings(_env_file=None, **values)


def test_accepts_a_strong_configuration(postgres_url: str) -> None:
    assert _settings().auth_secret


def test_rejects_a_short_auth_secret(postgres_url: str) -> None:
    with pytest.raises(ValidationError):
        _settings(auth_secret="too-short")


def test_rejects_the_auth_secret_placeholder_from_env_example(postgres_url: str) -> None:
    with pytest.raises(ValidationError):
        _settings(auth_secret="generate-your-own-with-openssl-rand--base64-32")


def test_rejects_an_invalid_totp_encryption_key(postgres_url: str) -> None:
    with pytest.raises(ValidationError):
        _settings(totp_encryption_key="generate-your-own-fernet-key")


def test_rejects_an_invalid_steam_api_key_encryption_key_when_set(postgres_url: str) -> None:
    with pytest.raises(ValidationError):
        _settings(steam_api_key_encryption_key="generate-your-own-fernet-key")


def test_accepts_a_valid_steam_api_key_encryption_key(postgres_url: str) -> None:
    key = Fernet.generate_key().decode()

    assert _settings(steam_api_key_encryption_key=key).steam_api_key_encryption_key == key


def test_rejects_an_invalid_trusted_proxy_entry(postgres_url: str) -> None:
    with pytest.raises(ValidationError):
        _settings(trusted_proxy_ips="172.18.0.0/16,not-an-ip")


def test_parses_trusted_proxy_networks(postgres_url: str) -> None:
    networks = _settings(trusted_proxy_ips="172.18.0.0/16, 10.0.0.1").trusted_proxy_networks

    assert [str(network) for network in networks] == ["172.18.0.0/16", "10.0.0.1/32"]


def test_docs_are_disabled_by_default(postgres_url: str) -> None:
    assert _settings().enable_docs is False
