from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    postgres_url: str = (
        "postgresql+asyncpg://postgres:1234@localhost:5432/backlog-manager-db"
    )


settings = Settings()
