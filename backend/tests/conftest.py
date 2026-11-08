import os
from collections.abc import Iterator
from typing import Any

# Settings are read at import time, so this must run before `app` is imported. Every setting is
# pinned, so neither the shell nor a developer's .env can change what the tests see
# (tests/test_config.py checks that none is missed). The URL is never connected to: tests that
# need a database override the session.
os.environ["DATABASE_URL"] = "postgresql://test:test@db.invalid:5432/test"
os.environ["FASTAPI_ENV"] = "production"
os.environ["JWT_SECRET"] = "test-secret-that-is-long-enough-for-hs256-0123456789"
os.environ["ACCESS_TOKEN_MINUTES"] = "30"
os.environ["REFRESH_TOKEN_DAYS"] = "60"
os.environ["USDA_API_KEY"] = "test-usda-key"
os.environ["USDA_RATE_LIMIT_PER_HOUR"] = "120"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Engine, event
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.database import get_session

# Importing the app registers every table model, through the routers, for create_all.
from app.main import app


@pytest.fixture
def client() -> Iterator[TestClient]:
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture
def engine() -> Iterator[Engine]:
    """A fresh in-memory SQLite database with the app's tables, shared by every session."""
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )

    @event.listens_for(engine, "connect")
    def enable_foreign_keys(dbapi_connection: Any, _: Any) -> None:
        # SQLite ignores ON DELETE CASCADE unless this is on, unlike Postgres.
        dbapi_connection.execute("PRAGMA foreign_keys=ON")

    SQLModel.metadata.create_all(engine)
    yield engine
    engine.dispose()


@pytest.fixture
def session(engine: Engine) -> Iterator[Session]:
    with Session(engine) as session:
        yield session


@pytest.fixture
def api(client: TestClient, engine: Engine) -> TestClient:
    """A client whose requests use the in-memory database."""

    def sqlite_session() -> Iterator[Session]:
        with Session(engine) as session:
            yield session

    app.dependency_overrides[get_session] = sqlite_session
    return client


def signup(api: TestClient, email: str = "ada@example.com") -> dict[str, Any]:
    """Creates an account and returns its `TokenPair`."""
    response = api.post(
        "/auth/signup", json={"email": email, "password": "correct horse"}
    )
    assert response.status_code == 201, response.text
    return response.json()


def bearer(tokens: dict[str, Any]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}
