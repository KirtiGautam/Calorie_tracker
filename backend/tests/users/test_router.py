from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app.auth.models import RefreshToken
from app.daily_logs.models import DailyLog
from app.goals.models import UserGoal
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


def test_delete_me_cascades_to_goal_and_logs(api: TestClient, session: Session) -> None:
    tokens = signup(api)
    headers = bearer(tokens)
    api.put(
        "/me/goal",
        headers=headers,
        json={
            "goal": "cut",
            "updated_at": "2026-10-29T08:00:00Z",
            "effective_from": "2026-10-29",
        },
    )
    api.post(
        "/daily-logs/changes",
        headers=headers,
        json={
            "added": [
                {
                    "log_date": "2026-10-29",
                    "entry_id": "9f1b7a52-3e1d-4c0e-9a39-7c5d1e2f0a11",
                    "food_id": "usda-173944",
                    "name": "Bananas, raw",
                    "grams": 120,
                    "logged_at": "2026-10-29T08:15:00Z",
                }
            ]
        },
    )

    response = api.delete("/me", headers=headers)

    assert response.status_code == 204
    assert api.get("/me", headers=headers).status_code == 401
    assert session.exec(select(UserGoal)).all() == []
    assert session.exec(select(DailyLog)).all() == []
    assert session.exec(select(RefreshToken)).all() == []
    login = api.post(
        "/auth/login", json={"email": "ada@example.com", "password": "correct horse"}
    )
    assert login.status_code == 400
    assert login.json()["error"]["code"] == "invalid_credentials"
