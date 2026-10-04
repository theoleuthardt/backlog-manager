import ipaddress

from cryptography.fernet import Fernet
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

MIN_AUTH_SECRET_LENGTH = 32
AUTH_SECRET_PLACEHOLDER_PREFIX = "generate-your-own"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    postgres_url: str
    auth_secret: str
    # Fernet key used to encrypt TOTP secrets at rest - distinct from
    # auth_secret since Fernet requires a specific key format (32 url-safe
    # base64 bytes), not an arbitrary string. Generate via:
    # python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
    totp_encryption_key: str
    igdb_client_id: str | None = None
    igdb_client_secret: str | None = None
    steam_web_api_key: str | None = None
    steam_api_key_encryption_key: str | None = None
    steamgriddb_api_key: str | None = None
    # Server-wide fallback for users who haven't set their own Discord
    # webhook in Account settings, same per-user-with-fallback pattern as
    # the IGDB/Steam/SteamGridDB keys above (see docs/PRICE_TRACKING.md).
    discord_webhook_url: str | None = None
    # Global/ops-configured only, unlike the above - gates
    # POST /api/prices/check, the only endpoint in this API not meant to
    # be called by a logged-in user - see routes/prices.py.
    price_check_cron_secret: str | None = None
    # There is no public self-registration endpoint - if set, and no users
    # exist yet, the app creates this one admin account on startup. Not
    # read again after that first run.
    initial_admin_email: str | None = None
    initial_admin_password: str | None = None
    # Comma-separated list of origins the browser is allowed to call this
    # API from (see cors_allowed_origins_list) - the frontend talks to this
    # backend directly, cross-origin, rather than through a Next.js proxy.
    cors_allowed_origins: str = "http://localhost:3000"
    # Comma-separated IPs/CIDRs of reverse proxies (e.g. the cloudflared
    # container) whose CF-Connecting-IP header may be believed - see
    # auth/client_ip.py. Empty means the header is never trusted.
    trusted_proxy_ips: str = ""
    # Serves /schema (OpenAPI JSON, Swagger, ...). Off by default so a
    # public deployment doesn't hand out its own route map.
    enable_docs: bool = False
    # Runs the daily automatic per-user backups (see
    # services/backup_service.py) inside the API process.
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
