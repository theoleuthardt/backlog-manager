"""Per-user-credentials-with-server-wide-fallback resolution for IGDB and
SteamGridDB (docs/ARCHITECTURE.md): a user's own stored value takes priority
over the server's environment configuration, which remains the fallback for
users who haven't set their own.

Each resolver returns None when nothing is configured anywhere, and raises
StoredCredentialError when the user's own stored value exists but cannot be
used (the encryption key changed, or the blob is corrupt). What that means
is the caller's call: a route that cannot work without the credential maps
it to a 503, one that can degrade gracefully treats it like "not set"."""

import msgspec
from cryptography.fernet import InvalidToken

from backlog_manager_backend.auth.encryption import decrypt
from backlog_manager_backend.config import settings
from backlog_manager_backend.integrations.types import IGDBCredentials
from backlog_manager_backend.schemas.user import User


class StoredCredentialError(Exception):
    pass


def resolve_igdb_credentials(user: User) -> tuple[str, str] | None:
    """IGDB needs both halves of a Twitch OAuth2 client-credentials pair
    together, so they are stored as one encrypted blob (see
    routes/user.py::_encrypt_igdb_credentials_if_present)."""
    if user.igdb_credentials_encrypted and settings.steam_api_key_encryption_key:
        try:
            decrypted = decrypt(
                user.igdb_credentials_encrypted, settings.steam_api_key_encryption_key
            )
            credentials = msgspec.json.decode(decrypted, type=IGDBCredentials)
        except (InvalidToken, ValueError, msgspec.DecodeError) as error:
            raise StoredCredentialError from error
        return credentials.client_id, credentials.client_secret
    if settings.igdb_client_id and settings.igdb_client_secret:
        return settings.igdb_client_id, settings.igdb_client_secret
    return None


def resolve_steamgriddb_api_key(user: User) -> str | None:
    if user.steamgriddb_api_key_encrypted and settings.steam_api_key_encryption_key:
        try:
            return decrypt(
                user.steamgriddb_api_key_encrypted, settings.steam_api_key_encryption_key
            )
        except (InvalidToken, ValueError) as error:
            raise StoredCredentialError from error
    return settings.steamgriddb_api_key


def resolve_igdb_credentials_or_none(user: User) -> tuple[str, str] | None:
    """For callers that degrade gracefully (e.g. a CSV preview that falls
    back to HowLongToBeat-only matching): a broken stored pair counts as
    not configured."""
    try:
        return resolve_igdb_credentials(user)
    except StoredCredentialError:
        return None


def resolve_steamgriddb_api_key_or_none(user: User) -> str | None:
    """For callers where a missing cover is not fatal: a broken stored key
    counts as not configured."""
    try:
        return resolve_steamgriddb_api_key(user)
    except StoredCredentialError:
        return None
