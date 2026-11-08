import os
from typing import Literal

import pytest
from pydantic import ValidationError

from app.config import MIN_SECRET_BYTES, Settings

DATABASE_URL = "postgresql://test:test@db.invalid:5432/test"
STRONG_SECRET = "0123456789abcdef" * 2  # 32 bytes

type Environment = Literal["development", "staging", "production"]


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
            usda_api_key="real-usda-key",
        )

    assert "short-but-real-secret" not in str(excinfo.value)
    assert "db-password" not in str(excinfo.value)
    assert "real-usda-key" not in str(excinfo.value)


@pytest.mark.parametrize("env", ["development", "staging", "production"])
@pytest.mark.parametrize("key", ["DEMO_KEY", "demo_key", " DEMO_KEY "])
def test_usda_demo_key_is_rejected_in_every_environment(
    env: Environment, key: str
) -> None:
    with pytest.raises(ValidationError, match="USDA_API_KEY can't be DEMO_KEY"):
        Settings(
            database_url=DATABASE_URL,
            jwt_secret=STRONG_SECRET,
            fastapi_env=env,
            usda_api_key=key,
        )


@pytest.mark.parametrize("env", ["development", "production"])
def test_blank_usda_key_is_rejected(env: Environment) -> None:
    with pytest.raises(ValidationError, match="USDA_API_KEY is blank"):
        Settings(
            database_url=DATABASE_URL,
            jwt_secret=STRONG_SECRET,
            fastapi_env=env,
            usda_api_key="   ",
        )


def test_empty_usda_key_in_the_environment_counts_as_missing(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("USDA_API_KEY", "")

    with pytest.raises(ValidationError, match="usda_api_key"):
        Settings(
            _env_file=None,
            database_url=DATABASE_URL,
            jwt_secret=STRONG_SECRET,
            fastapi_env="development",
        )


def test_usda_key_is_required(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("USDA_API_KEY")

    with pytest.raises(ValidationError, match="usda_api_key"):
        Settings(
            _env_file=None,
            database_url=DATABASE_URL,
            jwt_secret=STRONG_SECRET,
        )


def test_sqlalchemy_url_uses_psycopg() -> None:
    settings = Settings(database_url=DATABASE_URL, jwt_secret=STRONG_SECRET)

    assert settings.sqlalchemy_database_url.startswith("postgresql+psycopg://")


def test_conftest_pins_every_setting() -> None:
    """A setting left out of conftest.py would be read from the shell or .env instead."""
    unpinned = [
        name for name in Settings.model_fields if name.upper() not in os.environ
    ]

    assert unpinned == []
