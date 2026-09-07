from pydantic_settings import BaseSettings, SettingsConfigDict


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
    # There is no public self-registration endpoint - if set, and no users
    # exist yet, the app creates this one admin account on startup. Not
    # read again after that first run.
    initial_admin_email: str | None = None
    initial_admin_password: str | None = None
    # Comma-separated list of origins the browser is allowed to call this
    # API from (see cors_allowed_origins_list) - the frontend talks to this
    # backend directly, cross-origin, rather than through a Next.js proxy.
    cors_allowed_origins: str = "http://localhost:3000"

    @property
    def cors_allowed_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_allowed_origins.split(",") if origin.strip()]


settings = Settings()
