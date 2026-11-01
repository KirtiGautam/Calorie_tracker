from fastapi.testclient import TestClient

from tests.conftest import bearer, signup


def test_me_returns_account(api: TestClient) -> None:
    tokens = signup(api)

    response = api.get("/me", headers=bearer(tokens))

    assert response.status_code == 200
    assert response.json() == tokens["user"]


def test_me_requires_token(api: TestClient) -> None:
    response = api.get("/me")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_token"
    assert response.headers["WWW-Authenticate"] == "Bearer"


def test_delete_me_removes_account(api: TestClient) -> None:
    tokens = signup(api)
    headers = bearer(tokens)

    response = api.delete("/me", headers=headers)

    assert response.status_code == 204
    assert api.get("/me", headers=headers).status_code == 401
    login = api.post(
        "/auth/login", json={"email": "ada@example.com", "password": "correct horse"}
    )
    assert login.status_code == 401
