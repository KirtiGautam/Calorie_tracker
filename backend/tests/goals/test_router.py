from datetime import UTC, datetime
from typing import Any

from fastapi.testclient import TestClient
from sqlmodel import Session, col, select

from app.goals.models import UserGoal
from tests.conftest import bearer, signup


def goal(
    updated_at: str, effective_from: str | None = None, **overrides: Any
) -> dict[str, Any]:
    return {
        "goal": "cut",
        "energy_kcal": 2000,
        "protein_g": 150,
        "carbs_g": None,
        "fat_g": 60,
        "updated_at": updated_at,
        "effective_from": effective_from or updated_at[:10],
    } | overrides


def stored_days(session: Session) -> list[tuple[str, str, float | None]]:
    rows = session.exec(select(UserGoal).order_by(col(UserGoal.effective_from))).all()
    return [(row.effective_from.isoformat(), row.goal, row.energy_kcal) for row in rows]


def test_get_goal_before_any_save_is_404(api: TestClient) -> None:
    response = api.get("/me/goal", headers=bearer(signup(api)))

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "goal_not_found"


def test_put_then_get_goal(api: TestClient) -> None:
    headers = bearer(signup(api))

    put = api.put("/me/goal", headers=headers, json=goal("2026-10-01T08:00:00Z"))
    get = api.get("/me/goal", headers=headers)

    assert put.status_code == 200
    assert get.json() == put.json()
    assert get.json()["carbs_g"] is None
    assert get.json()["updated_at"].startswith("2026-10-01T08:00:00")
    assert get.json()["effective_from"] == "2026-10-01"


def test_a_later_save_the_same_day_replaces_that_days_goal(
    api: TestClient, session: Session
) -> None:
    headers = bearer(signup(api))
    api.put("/me/goal", headers=headers, json=goal("2026-10-01T08:00:00Z"))

    response = api.put(
        "/me/goal",
        headers=headers,
        json=goal("2026-10-01T20:00:00Z", goal="bulk", energy_kcal=3000),
    )

    assert response.status_code == 200
    assert response.json()["goal"] == "bulk"
    assert stored_days(session) == [("2026-10-01", "bulk", 3000)]


def test_a_save_on_a_later_day_adds_a_row_and_keeps_the_earlier_days(
    api: TestClient, session: Session
) -> None:
    headers = bearer(signup(api))
    api.put("/me/goal", headers=headers, json=goal("2026-10-01T08:00:00Z"))

    response = api.put(
        "/me/goal",
        headers=headers,
        json=goal("2026-10-05T08:00:00Z", goal="maintain", energy_kcal=2400),
    )

    assert response.json()["effective_from"] == "2026-10-05"
    assert api.get("/me/goal", headers=headers).json() == response.json()
    assert stored_days(session) == [
        ("2026-10-01", "cut", 2000),
        ("2026-10-05", "maintain", 2400),
    ]


def test_a_goal_for_an_earlier_day_is_refused(
    api: TestClient, session: Session
) -> None:
    headers = bearer(signup(api))
    api.put("/me/goal", headers=headers, json=goal("2026-10-05T08:00:00Z"))

    # Saved later, but dated an earlier day, like a device that was offline since then.
    response = api.put(
        "/me/goal",
        headers=headers,
        json=goal("2026-10-05T09:00:00Z", "2026-10-04", goal="bulk"),
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "goal_outdated"
    assert response.json()["error"]["details"] == {"effective_from": "2026-10-05"}
    assert stored_days(session) == [("2026-10-05", "cut", 2000)]


def test_an_earlier_save_the_same_day_is_refused(
    api: TestClient, session: Session
) -> None:
    headers = bearer(signup(api))
    api.put("/me/goal", headers=headers, json=goal("2026-10-01T08:00:00Z"))

    response = api.put(
        "/me/goal", headers=headers, json=goal("2026-10-01T07:00:00Z", goal="bulk")
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "goal_outdated"
    assert stored_days(session) == [("2026-10-01", "cut", 2000)]


def test_resending_the_stored_save_returns_it(api: TestClient) -> None:
    headers = bearer(signup(api))
    first = api.put("/me/goal", headers=headers, json=goal("2026-10-01T08:00:00Z"))

    # 09:00+01:00 is 08:00Z, the same save, so it's treated as a retry.
    retry = api.put(
        "/me/goal",
        headers=headers,
        json=goal("2026-10-01T09:00:00+01:00", "2026-10-01", goal="bulk"),
    )

    assert retry.status_code == 200
    assert retry.json() == first.json()


def test_effective_from_must_be_the_day_of_updated_at(api: TestClient) -> None:
    headers = bearer(signup(api))

    # 23:00 in UTC-10 is 09:00 the next day in UTC, so both days are plausible.
    west = api.put(
        "/me/goal", headers=headers, json=goal("2026-10-02T09:00:00Z", "2026-10-01")
    )
    backdated = api.put(
        "/me/goal", headers=headers, json=goal("2026-10-09T08:00:00Z", "2026-10-07")
    )
    ahead = api.put(
        "/me/goal", headers=headers, json=goal("2026-10-09T08:00:00Z", "2026-10-11")
    )

    assert west.status_code == 200
    assert backdated.status_code == 422
    assert backdated.json()["error"]["code"] == "invalid_goal_date"
    assert ahead.status_code == 422


def test_future_timestamp_is_clamped_to_now(api: TestClient) -> None:
    headers = bearer(signup(api))
    today = datetime.now(UTC).date().isoformat()

    response = api.put(
        "/me/goal", headers=headers, json=goal("2999-01-01T00:00:00Z", today)
    )

    assert response.status_code == 200
    assert not response.json()["updated_at"].startswith("2999")


def test_a_goal_dated_in_the_future_is_refused(api: TestClient) -> None:
    headers = bearer(signup(api))

    response = api.put("/me/goal", headers=headers, json=goal("2999-01-01T00:00:00Z"))

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "invalid_goal_date"


def test_put_rejects_naive_timestamp_unknown_goal_and_missing_date(
    api: TestClient,
) -> None:
    headers = bearer(signup(api))
    no_date = goal("2026-10-01T08:00:00Z")
    del no_date["effective_from"]

    naive = api.put("/me/goal", headers=headers, json=goal("2026-10-01T08:00:00"))
    unknown = api.put(
        "/me/goal", headers=headers, json=goal("2026-10-01T08:00:00Z", goal="shred")
    )
    missing = api.put("/me/goal", headers=headers, json=no_date)

    assert naive.status_code == 422
    assert unknown.status_code == 422
    assert missing.status_code == 422


def test_goals_are_per_user(api: TestClient) -> None:
    ada = bearer(signup(api, "ada@example.com"))
    bob = bearer(signup(api, "bob@example.com"))
    api.put("/me/goal", headers=ada, json=goal("2026-10-05T08:00:00Z"))

    assert api.get("/me/goal", headers=bob).status_code == 404
    # Ada's later goal doesn't make Bob's earlier one outdated.
    assert (
        api.put("/me/goal", headers=bob, json=goal("2026-10-01T08:00:00Z")).status_code
        == 200
    )
