from functools import lru_cache
from typing import Annotated, Literal, Self

from fastapi import Depends
from pydantic import Field, PostgresDsn, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

PLACEHOLDER_SECRET = "changethis"  # noqa: S105 - the value the validator rejects, not a secret


class Settings(BaseSettings):
    """App settings, read from the environment and, for local runs, from `.env`."""

    model_config = SettingsConfigDict(
        env_file=".env", env_ignore_empty=True, extra="ignore"
    )

    fastapi_env: Literal["development", "staging", "production"] = "production"
    # The plain postgresql:// URI from the Supabase dashboard, so psql can use it as is.
    database_url: PostgresDsn
    # Signs access and refresh tokens. Generate one with `openssl rand -hex 32`.
    jwt_secret: SecretStr
    access_token_minutes: int = Field(default=30, ge=1, le=24 * 60)
    refresh_token_days: int = Field(default=60, ge=1, le=365)

    @model_validator(mode="after")
    def reject_placeholder_secret(self) -> Self:
        """Fails startup when a deployed environment still uses the example secret."""
        secret = self.jwt_secret.get_secret_value()
        if self.fastapi_env != "development" and secret == PLACEHOLDER_SECRET:
            raise ValueError(
                "JWT_SECRET is still 'changethis'. Set a real secret outside development."
            )
        return self

    @property
    def show_docs(self) -> bool:
        return self.fastapi_env != "production"

    @property
    def sqlalchemy_database_url(self) -> str:
        """The database URL with the psycopg 3 driver that SQLAlchemy needs."""
        url = str(self.database_url)
        scheme, _, rest = url.partition("://")
        return (
            f"postgresql+psycopg://{rest}"
            if scheme in {"postgres", "postgresql"}
            else url
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()


SettingsDep = Annotated[Settings, Depends(get_settings)]
