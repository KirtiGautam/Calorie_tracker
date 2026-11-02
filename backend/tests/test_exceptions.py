from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

from app.database import get_session
from app.main import app


def broken_session() -> Session:
    raise RuntimeError("A bug no handler knows about")


@pytest.fixture
def unguarded_client() -> Iterator[TestClient]:
    """A client that returns 500 responses instead of re-raising the server's exception."""
    with TestClient(app, raise_server_exceptions=False) as client:
        yield client
    app.dependency_overrides.clear()


def test_unexpected_error_returns_envelope_without_internals(
    unguarded_client: TestClient, caplog: pytest.LogCaptureFixture
) -> None:
    app.dependency_overrides[get_session] = broken_session

    response = unguarded_client.get("/health/ready")

    assert response.status_code == 500
    assert response.json() == {
        "error": {
            "code": "internal_error",
            "message": "Internal server error",
            "details": None,
        }
    }
    assert "Unhandled error on GET /health/ready" in caplog.text
