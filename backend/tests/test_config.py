import pytest
from pydantic import ValidationError

from app.config import Settings

DATABASE_URL = "postgresql://test:test@db.invalid:5432/test"


def test_placeholder_secret_is_rejected_outside_development() -> None:
    with pytest.raises(ValidationError, match="changethis"):
        Settings(
            database_url=DATABASE_URL,
            jwt_secret="changethis",
            fastapi_env="production",
        )


def test_placeholder_secret_is_allowed_in_development() -> None:
    settings = Settings(
        database_url=DATABASE_URL,
        jwt_secret="changethis",
        fastapi_env="development",
    )

    assert settings.show_docs


def test_sqlalchemy_url_uses_psycopg() -> None:
    settings = Settings(
        database_url=DATABASE_URL,
        jwt_secret="s",
    )

    assert settings.sqlalchemy_database_url.startswith("postgresql+psycopg://")
