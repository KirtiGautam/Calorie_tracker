from collections.abc import Iterator
from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy import exc as sa_exc
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, create_engine

from app.database import get_session
from app.main import app


class UnreachableSession(Session):
    """A session whose connection always fails, like a database that is down."""

    def connection(self, *args: Any, **kwargs: Any) -> Any:
        raise sa_exc.OperationalError("SELECT 1", {}, ConnectionRefusedError())


def sqlite_session() -> Iterator[Session]:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    with Session(engine) as session:
        yield session


def unreachable_session() -> Iterator[Session]:
    with UnreachableSession() as session:
        yield session


def test_liveness_returns_ok(client: TestClient) -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_readiness_returns_ok_when_database_answers(client: TestClient) -> None:
    app.dependency_overrides[get_session] = sqlite_session

    response = client.get("/health/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_readiness_returns_503_when_database_is_down(client: TestClient) -> None:
    app.dependency_overrides[get_session] = unreachable_session

    response = client.get("/health/ready")

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "database_unavailable"


def test_unknown_route_uses_error_envelope(client: TestClient) -> None:
    response = client.get("/nope")

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "http_error"


def test_docs_are_hidden_in_production(client: TestClient) -> None:
    assert client.get("/openapi.json").status_code == 404
    assert client.get("/docs").status_code == 404
