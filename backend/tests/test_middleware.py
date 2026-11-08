from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.middleware import MAX_BODY_BYTES
from tests.conftest import bearer, signup


def test_a_declared_length_over_the_limit_is_refused_before_reading(
    client: TestClient,
) -> None:
    response = client.post(
        "/auth/login",
        content=b"x" * (MAX_BODY_BYTES + 1),
        headers={"Content-Type": "application/json"},
    )

    assert response.status_code == 413
    assert response.json()["error"]["code"] == "content_too_large"
    assert response.headers["Cache-Control"] == "no-store"


def test_a_chunked_body_is_refused_once_it_goes_over_the_limit(
    client: TestClient,
) -> None:
    def chunks() -> Iterator[bytes]:
        yield b'{"fdc_ids": ['
        for _ in range(MAX_BODY_BYTES // 1024 + 1):
            yield b"1," * 512

    response = client.post(
        "/usda/foods", content=chunks(), headers={"Content-Type": "application/json"}
    )

    assert response.status_code == 413
    assert response.json()["error"]["code"] == "content_too_large"


def test_a_body_at_the_limit_is_read(client: TestClient) -> None:
    body = b'{"email": "not-an-email", "password": "x"}'
    padded = body + b" " * (MAX_BODY_BYTES - len(body))

    response = client.post(
        "/auth/login", content=padded, headers={"Content-Type": "application/json"}
    )

    # It got as far as validation.
    assert response.status_code == 422


@pytest.mark.parametrize("path", ["/me", "/me/goal", "/daily-logs"])
def test_personal_data_is_never_stored_by_caches(api: TestClient, path: str) -> None:
    response = api.get(path, headers=bearer(signup(api)))

    assert response.headers["Cache-Control"] == "no-store"
    assert "Pragma" not in response.headers


def test_head_works_on_the_health_checks(client: TestClient) -> None:
    response = client.head("/health")

    assert response.status_code == 200
    assert response.content == b""
