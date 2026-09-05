from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    postgres_url: str
    igdb_client_id: str | None = None
    igdb_client_secret: str | None = None


settings = Settings()
