import os

import pytest
from pydantic import ValidationError

from app.config import MIN_SECRET_BYTES, Settings

DATABASE_URL = "postgresql://test:test@db.invalid:5432/test"
STRONG_SECRET = "0123456789abcdef" * 2  # 32 bytes


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


def test_short_secret_is_rejected_outside_development() -> None:
    with pytest.raises(ValidationError, match=f"at least {MIN_SECRET_BYTES} bytes"):
        Settings(
            database_url=DATABASE_URL,
            jwt_secret="x" * (MIN_SECRET_BYTES - 1),
            fastapi_env="staging",
        )


def test_errors_never_show_the_secret_or_database_password() -> None:
    with pytest.raises(ValidationError) as excinfo:
        Settings(
            database_url="postgresql://app:db-password@db.invalid:5432/app",
            jwt_secret="short-but-real-secret",
            fastapi_env="production",
        )

    assert "short-but-real-secret" not in str(excinfo.value)
    assert "db-password" not in str(excinfo.value)


def test_sqlalchemy_url_uses_psycopg() -> None:
    settings = Settings(database_url=DATABASE_URL, jwt_secret=STRONG_SECRET)

    assert settings.sqlalchemy_database_url.startswith("postgresql+psycopg://")


def test_conftest_pins_every_setting() -> None:
    """A setting left out of conftest.py would be read from the shell or .env instead."""
    unpinned = [
        name for name in Settings.model_fields if name.upper() not in os.environ
    ]

    assert unpinned == []
