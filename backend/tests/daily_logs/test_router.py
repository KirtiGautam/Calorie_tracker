import uuid
from typing import Any

from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app.daily_logs.models import DailyLog
from tests.conftest import bearer, signup


def food(log_date: str = "2026-10-29", **overrides: Any) -> dict[str, Any]:
    return {
        "log_date": log_date,
        "entry_id": str(uuid.uuid4()),
        "food_id": "usda-173944",
        "name": "Bananas, raw",
        "grams": 120,
        "logged_at": f"{log_date}T08:15:00Z",
        "energy_kcal": 107,
        "protein_g": 1.3,
        "carbs_g": 27.4,
        "fat_g": 0.4,
    } | overrides


def test_changes_add_foods_and_compute_totals(api: TestClient) -> None:
    headers = bearer(signup(api))
    banana = food()
    oats = food(
        food_id="usda-173904", name="Oats", grams=70, energy_kcal=265, fat_g=None
    )

    response = api.post(
        "/daily-logs/changes", headers=headers, json={"added": [banana, oats]}
    )

    assert response.status_code == 200
    [day] = response.json()["days"]
    assert day["log_date"] == "2026-10-29"
    assert day["energy_kcal"] == 372
    assert day["fat_g"] == 0.4
    assert {item["entry_id"] for item in day["foods"]} == {
        banana["entry_id"],
        oats["entry_id"],
    }


def test_changes_remove_food_and_keep_empty_day(api: TestClient) -> None:
    headers = bearer(signup(api))
    banana = food()
    api.post("/daily-logs/changes", headers=headers, json={"added": [banana]})

    response = api.post(
        "/daily-logs/changes",
        headers=headers,
        json={"removed": [{"log_date": "2026-10-29", "entry_id": banana["entry_id"]}]},
    )

    [day] = response.json()["days"]
    assert day["foods"] == []
    assert day["energy_kcal"] is None
    [pulled] = api.get("/daily-logs", headers=headers).json()["days"]
    assert pulled["foods"] == []


def test_changes_are_idempotent(api: TestClient) -> None:
    headers = bearer(signup(api))
    body = {"added": [food(), food(log_date="2026-10-28")]}

    first = api.post("/daily-logs/changes", headers=headers, json=body).json()
    second = api.post("/daily-logs/changes", headers=headers, json=body).json()

    assert [d["foods"] for d in second["days"]] == [d["foods"] for d in first["days"]]
    assert [d["energy_kcal"] for d in second["days"]] == [107, 107]


def test_changes_validate_items(api: TestClient) -> None:
    headers = bearer(signup(api))
    bad = [
        food(food_id="sample-oats"),
        food(grams=0),
        food(grams=5001),
        food(logged_at="2026-10-29T08:15:00"),
        food(energy_kcal=-1),
    ]

    for item in bad:
        response = api.post(
            "/daily-logs/changes", headers=headers, json={"added": [item]}
        )
        assert response.status_code == 422, item


def test_changes_limit_batch_size(api: TestClient) -> None:
    headers = bearer(signup(api))

    response = api.post(
        "/daily-logs/changes", headers=headers, json={"added": [food()] * 501}
    )

    assert response.status_code == 422


def test_changes_limit_foods_per_day(api: TestClient, session: Session) -> None:
    headers = bearer(signup(api))
    api.post(
        "/daily-logs/changes",
        headers=headers,
        json={"added": [food() for _ in range(200)]},
    )

    response = api.post(
        "/daily-logs/changes", headers=headers, json={"added": [food()]}
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "too_many_foods"
    [log] = session.exec(select(DailyLog)).all()
    assert len(log.foods) == 200


def test_pull_pages_through_days_sharing_one_timestamp(api: TestClient) -> None:
    headers = bearer(signup(api))
    added = [
        food(log_date=f"2026-{month:02d}-{day:02d}")
        for month in range(1, 6)
        for day in range(1, 29)
    ]
    assert len(added) == 140
    api.post("/daily-logs/changes", headers=headers, json={"added": added})

    seen: list[str] = []
    cursor: str | None = None
    pages = 0
    while True:
        params = {"limit": 50} | ({"cursor": cursor} if cursor else {})
        page = api.get("/daily-logs", headers=headers, params=params).json()
        seen += [day["log_date"] for day in page["days"]]
        pages += 1
        cursor = page["next_cursor"]
        if not page["has_more"]:
            break

    assert pages == 3
    assert seen == sorted(item["log_date"] for item in added)


def test_pull_default_page_holds_100_days(api: TestClient) -> None:
    headers = bearer(signup(api))
    added = [
        food(log_date=f"2026-{month:02d}-{day:02d}")
        for month in range(1, 6)
        for day in range(1, 29)
    ]
    api.post("/daily-logs/changes", headers=headers, json={"added": added})

    page = api.get("/daily-logs", headers=headers).json()

    assert len(page["days"]) == 100
    assert page["has_more"]


def test_stored_cursor_resumes_with_only_later_changes(api: TestClient) -> None:
    headers = bearer(signup(api))
    api.post(
        "/daily-logs/changes", headers=headers, json={"added": [food("2026-10-01")]}
    )
    first = api.get("/daily-logs", headers=headers).json()
    assert first["has_more"] is False
    stored = first["next_cursor"]

    nothing_new = api.get(
        "/daily-logs", headers=headers, params={"cursor": stored}
    ).json()
    api.post(
        "/daily-logs/changes", headers=headers, json={"added": [food("2026-09-01")]}
    )
    later = api.get("/daily-logs", headers=headers, params={"cursor": stored}).json()

    assert nothing_new == {"days": [], "next_cursor": stored, "has_more": False}
    assert [d["log_date"] for d in later["days"]] == ["2026-09-01"]


def test_pull_with_no_days_has_no_cursor(api: TestClient) -> None:
    page = api.get("/daily-logs", headers=bearer(signup(api))).json()

    assert page == {"days": [], "next_cursor": None, "has_more": False}


def test_pull_rejects_bad_cursor(api: TestClient) -> None:
    response = api.get(
        "/daily-logs", headers=bearer(signup(api)), params={"cursor": "nope"}
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "invalid_cursor"


def test_logs_are_isolated_between_users(api: TestClient) -> None:
    ada = bearer(signup(api, "ada@example.com"))
    bob = bearer(signup(api, "bob@example.com"))
    banana = food()
    api.post("/daily-logs/changes", headers=ada, json={"added": [banana]})

    # Bob can neither see Ada's day nor remove her food from it.
    assert api.get("/daily-logs", headers=bob).json()["days"] == []
    api.post(
        "/daily-logs/changes",
        headers=bob,
        json={"removed": [{"log_date": "2026-10-29", "entry_id": banana["entry_id"]}]},
    )
    [ada_day] = api.get("/daily-logs", headers=ada).json()["days"]
    assert len(ada_day["foods"]) == 1


def test_daily_logs_require_token(api: TestClient) -> None:
    assert api.get("/daily-logs").status_code == 401
    assert api.post("/daily-logs/changes", json={}).status_code == 401
