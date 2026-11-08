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


@pytest.mark.parametrize(
    ("method", "path", "allow"),
    [
        ("PATCH", "/me", "DELETE, GET"),
        ("HEAD", "/me", "DELETE, GET"),
        ("POST", "/me/goal", "GET, PUT"),
        ("DELETE", "/health", "GET, HEAD"),
        ("GET", "/auth/login", "POST"),
    ],
)
def test_405_lists_every_method_the_path_supports(
    client: TestClient, method: str, path: str, allow: str
) -> None:
    response = client.request(method, path)

    assert response.status_code == 405
    assert response.headers["Allow"] == allow


def test_malformed_json_is_a_400(client: TestClient) -> None:
    response = client.post(
        "/auth/login",
        content='{"email": ',
        headers={"Content-Type": "application/json"},
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "validation_error"
    assert response.json()["error"]["details"][0]["type"] == "json_invalid"


@pytest.mark.parametrize("content_type", ["text/plain", None])
def test_a_body_that_isn_t_sent_as_json_is_a_415(
    client: TestClient, content_type: str | None
) -> None:
    headers = {"Content-Type": content_type} if content_type else {}

    response = client.post(
        "/auth/login",
        content='{"email": "ada@example.com", "password": "correct horse"}',
        headers=headers,
    )

    assert response.status_code == 415
    assert response.json()["error"]["code"] == "validation_error"


def test_json_with_a_charset_or_a_json_suffix_is_accepted(client: TestClient) -> None:
    for content_type in ["application/json; charset=utf-8", "application/problem+json"]:
        response = client.post(
            "/auth/login",
            content='{"email": "not-an-email", "password": "x"}',
            headers={"Content-Type": content_type},
        )

        assert response.status_code == 422


def test_an_empty_body_is_a_422(client: TestClient) -> None:
    response = client.post("/auth/login")

    assert response.status_code == 422
    assert response.json()["error"]["details"][0]["type"] == "missing"


def test_an_oversized_body_is_refused_without_echoing_it(client: TestClient) -> None:
    password = "x" * (3 * 1024 * 1024)

    response = client.post(
        "/auth/login", json={"email": "ada@example.com", "password": password}
    )

    assert response.status_code == 413
    assert response.json()["error"]["code"] == "content_too_large"
    assert len(response.content) < 1024


def test_a_long_password_under_the_body_limit_isn_t_echoed(client: TestClient) -> None:
    response = client.post(
        "/auth/login", json={"email": "ada@example.com", "password": "x" * 100_000}
    )

    assert response.status_code == 422
    assert len(response.content) < 1024
