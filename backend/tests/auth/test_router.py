from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.auth import security
from app.config import get_settings
from tests.conftest import bearer, signup


def test_signup_returns_tokens_and_user(api: TestClient) -> None:
    tokens = signup(api, "  Ada@Example.COM ")

    assert tokens["token_type"] == "bearer"
    assert tokens["expires_in"] == 30 * 60
    assert tokens["user"]["email"] == "ada@example.com"
    assert "hashed_password" not in tokens["user"]


@pytest.mark.parametrize(
    "email", ["ada@example.com", "ADA@EXAMPLE.COM", "Ada@example.com"]
)
def test_signup_rejects_duplicate_email_in_any_case(
    api: TestClient, email: str
) -> None:
    signup(api, "ada@example.com")

    response = api.post(
        "/auth/signup", json={"email": email, "password": "another one"}
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "email_taken"


@pytest.mark.parametrize(
    "body",
    [
        {"email": "not-an-email", "password": "long enough"},
        {"email": "ada@example.com", "password": "short"},
        {"email": "ada@example.com", "password": "x" * 129},
    ],
)
def test_signup_validates_input(api: TestClient, body: dict[str, str]) -> None:
    response = api.post("/auth/signup", json=body)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_login_returns_tokens(api: TestClient) -> None:
    signup(api)

    response = api.post(
        "/auth/login", json={"email": "ADA@example.com", "password": "correct horse"}
    )

    assert response.status_code == 200
    assert response.json()["user"]["email"] == "ada@example.com"


def test_login_rejects_wrong_password(api: TestClient) -> None:
    signup(api)

    response = api.post(
        "/auth/login", json={"email": "ada@example.com", "password": "wrong horse"}
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_credentials"


def test_login_rejects_unknown_email_the_same_way(api: TestClient) -> None:
    response = api.post(
        "/auth/login", json={"email": "nobody@example.com", "password": "anything"}
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_credentials"


def test_refresh_returns_new_working_pair(api: TestClient) -> None:
    tokens = signup(api)

    response = api.post(
        "/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )

    assert response.status_code == 200
    refreshed = response.json()
    assert refreshed["refresh_token"] != tokens["refresh_token"]
    assert api.get("/me", headers=bearer(refreshed)).status_code == 200


def test_refresh_rejects_access_token(api: TestClient) -> None:
    tokens = signup(api)

    response = api.post("/auth/refresh", json={"refresh_token": tokens["access_token"]})

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_token"


def test_refresh_rejects_garbage(api: TestClient) -> None:
    response = api.post("/auth/refresh", json={"refresh_token": "not.a.jwt"})

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_token"


def test_refresh_rejects_deleted_account(api: TestClient) -> None:
    tokens = signup(api)
    api.delete("/me", headers=bearer(tokens))

    response = api.post(
        "/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )

    assert response.status_code == 401


def test_me_rejects_refresh_token(api: TestClient) -> None:
    tokens = signup(api)

    response = api.get(
        "/me", headers={"Authorization": f"Bearer {tokens['refresh_token']}"}
    )

    assert response.status_code == 401
    assert response.headers["WWW-Authenticate"] == 'Bearer error="invalid_token"'


def test_me_without_a_token_gets_a_challenge_without_an_error(api: TestClient) -> None:
    response = api.get("/me")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_token"
    assert response.headers["WWW-Authenticate"] == "Bearer"


def test_me_rejects_expired_token(api: TestClient) -> None:
    user_id = signup(api)["user"]["id"]
    secret = get_settings().jwt_secret.get_secret_value()
    expired = security.create_token(
        user_id,
        "access",
        timedelta(minutes=30),
        secret,
        now=datetime.now(UTC) - timedelta(hours=1),
    )

    response = api.get("/me", headers={"Authorization": f"Bearer {expired}"})

    assert response.status_code == 401
    assert response.json()["error"]["message"] == "Token has expired"


def test_me_rejects_token_signed_with_another_secret(api: TestClient) -> None:
    user_id = signup(api)["user"]["id"]
    forged = security.create_token(
        user_id, "access", timedelta(minutes=5), "another-secret-0123456789abcdef0123"
    )

    response = api.get("/me", headers={"Authorization": f"Bearer {forged}"})

    assert response.status_code == 401


def test_me_rejects_token_with_bad_subject(api: TestClient) -> None:
    secret = get_settings().jwt_secret.get_secret_value()
    token = security.jwt.encode(
        {
            "sub": "not-a-uuid",
            "typ": "access",
            "exp": datetime.now(UTC) + timedelta(minutes=5),
        },
        secret,
        algorithm=security.ALGORITHM,
    )

    response = api.get("/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 401


def test_signup_names_the_account_and_forbids_caching(api: TestClient) -> None:
    response = api.post(
        "/auth/signup", json={"email": "ada@example.com", "password": "correct horse"}
    )

    assert response.status_code == 201
    assert response.headers["Location"] == "/me"
    assert response.headers["Cache-Control"] == "no-store"
    assert response.headers["Pragma"] == "no-cache"


def test_validation_errors_never_echo_the_password(api: TestClient) -> None:
    response = api.post(
        "/auth/signup", json={"email": "ada@example.com", "password": "hunter2"}
    )

    assert response.status_code == 422
    assert "hunter2" not in response.text
    assert all("input" not in error for error in response.json()["error"]["details"])


@pytest.mark.parametrize("number", ["NaN", "Infinity", "-Infinity", "1e400"])
def test_a_non_finite_number_is_a_422_not_a_500(api: TestClient, number: str) -> None:
    response = api.post(
        "/auth/signup",
        content=f'{{"email": "z@example.com", "password": {number}}}',
        headers={"Content-Type": "application/json"},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
