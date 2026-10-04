import ipaddress

from cryptography.fernet import Fernet
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

MIN_AUTH_SECRET_LENGTH = 32
AUTH_SECRET_PLACEHOLDER_PREFIX = "generate-your-own"


class Settings(BaseSettings):
    """Environment-driven settings (see .env.example).

    `totp_encryption_key` (TOTP secrets at rest) and
    `steam_api_key_encryption_key` (per-user Steam API keys) are Fernet keys,
    i.e. 44-character url-safe base64 strings encoding 32 bytes, not
    arbitrary strings:
    `python -c "from cryptography.fernet import Fernet;
    print(Fernet.generate_key().decode())"`. They are separate from
    `auth_secret`, which signs JWTs.

    `discord_webhook_url` is the server-wide fallback for users who have not
    set their own webhook in Account settings, the same per-user-with-fallback
    pattern as the IGDB, Steam and SteamGridDB keys (see
    docs/PRICE_TRACKING.md). `price_check_cron_secret` gates
    POST /api/prices/check, the only endpoint not meant for a logged-in user
    (routes/prices.py).

    There is no public self-registration: when `initial_admin_email` and
    `initial_admin_password` are set and no users exist yet, the first admin
    is created on startup (bootstrap.py); they are not read again afterwards.

    `cors_allowed_origins` is a comma-separated list of origins the browser
    may call the API from; the frontend talks to the backend directly,
    without a Next.js proxy. `trusted_proxy_ips` is a comma-separated list of
    IPs/CIDRs of trusted reverse proxies (auth/client_ip.py). `enable_docs`
    serves the OpenAPI schema and Swagger UI under /schema.
    `backup_scheduler_enabled` runs the automatic per-user backup scheduler in
    the API process.
    """

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    postgres_url: str
    auth_secret: str
    totp_encryption_key: str
    igdb_client_id: str | None = None
    igdb_client_secret: str | None = None
    steam_web_api_key: str | None = None
    steam_api_key_encryption_key: str | None = None
    steamgriddb_api_key: str | None = None
    discord_webhook_url: str | None = None
    price_check_cron_secret: str | None = None
    initial_admin_email: str | None = None
    initial_admin_password: str | None = None
    cors_allowed_origins: str = "http://localhost:3000"
    trusted_proxy_ips: str = ""
    enable_docs: bool = False
    backup_scheduler_enabled: bool = True

    @field_validator("auth_secret")
    @classmethod
    def _validate_auth_secret(cls, value: str) -> str:
        if len(value) < MIN_AUTH_SECRET_LENGTH or value.startswith(AUTH_SECRET_PLACEHOLDER_PREFIX):
            raise ValueError(
                f"AUTH_SECRET must be at least {MIN_AUTH_SECRET_LENGTH} characters and not the "
                "placeholder from .env.example - generate one with: openssl rand -base64 32"
            )
        return value

    @field_validator("totp_encryption_key", "steam_api_key_encryption_key")
    @classmethod
    def _validate_fernet_key(cls, value: str | None) -> str | None:
        if value is None or value == "":
            return value
        try:
            Fernet(value)
        except ValueError as error:
            raise ValueError(
                "must be a valid Fernet key - generate one with: "
                'python -c "from cryptography.fernet import Fernet; '
                'print(Fernet.generate_key().decode())"'
            ) from error
        return value

    @field_validator("trusted_proxy_ips")
    @classmethod
    def _validate_trusted_proxy_ips(cls, value: str) -> str:
        for entry in value.split(","):
            if entry.strip():
                ipaddress.ip_network(entry.strip(), strict=False)
        return value

    @property
    def trusted_proxy_networks(
        self,
    ) -> list[ipaddress.IPv4Network | ipaddress.IPv6Network]:
        return [
            ipaddress.ip_network(entry.strip(), strict=False)
            for entry in self.trusted_proxy_ips.split(",")
            if entry.strip()
        ]

    @property
    def cors_allowed_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_allowed_origins.split(",") if origin.strip()]


settings = Settings()
