import uuid
from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest
from sqlmodel import Session

from app.daily_logs import service
from app.daily_logs.exceptions import InvalidCursor
from app.daily_logs.models import DailyLog
from app.daily_logs.schemas import AddedFood, LogChanges, RemovedFood
from app.users.models import AppUser


def item(
    entry_id: str, logged_at: str = "2026-10-29T08:00:00Z", **macros: Any
) -> dict[str, Any]:
    return {"entry_id": entry_id, "logged_at": logged_at, **macros}


def test_merge_adds_replaces_and_removes() -> None:
    existing = [item("a", energy_kcal=100), item("b")]

    merged = service.merge_foods(
        existing, added=[item("a", energy_kcal=150), item("c")], removed_ids=["b"]
    )

    assert [food["entry_id"] for food in merged] == ["a", "c"]
    assert merged[0]["energy_kcal"] == 150


def test_merge_removal_wins_over_addition() -> None:
    merged = service.merge_foods([], added=[item("a")], removed_ids=["a"])

    assert merged == []


def test_merge_ignores_unknown_removal() -> None:
    merged = service.merge_foods([item("a")], added=[], removed_ids=["zzz"])

    assert [food["entry_id"] for food in merged] == ["a"]


def test_merge_orders_by_logged_at() -> None:
    merged = service.merge_foods(
        [item("late", "2026-10-29T20:00:00Z")],
        added=[item("early", "2026-10-29T07:00:00Z")],
        removed_ids=[],
    )

    assert [food["entry_id"] for food in merged] == ["early", "late"]


def test_merge_is_idempotent() -> None:
    added = [item("a", energy_kcal=100), item("b", energy_kcal=50)]
    once = service.merge_foods([], added, ["c"])

    twice = service.merge_foods(once, added, ["c"])

    assert twice == once


def test_totals_sum_known_values_only() -> None:
    foods = [
        item("a", energy_kcal=100, protein_g=2.5, carbs_g=None),
        item("b", energy_kcal=50.5, protein_g=None),
    ]

    totals = service.totals_for(foods)

    assert totals == {
        "energy_kcal": 150.5,
        "protein_g": 2.5,
        "carbs_g": None,
        "fat_g": None,
    }


def test_totals_of_no_foods_are_unknown() -> None:
    assert service.totals_for([]) == dict.fromkeys(service.MACRO_KEYS)


def test_apply_changes_with_nothing_returns_nothing(session: Session) -> None:
    assert service.apply_changes(session, uuid.uuid4(), LogChanges()) == []


def test_apply_changes_creates_row_even_for_removal_only(session: Session) -> None:
    user = AppUser(email="ada@example.com", hashed_password="x")
    session.add(user)
    session.commit()
    removal = RemovedFood(log_date=date(2026, 10, 29), entry_id=uuid.uuid4())

    logs = service.apply_changes(session, user.id, LogChanges(removed=[removal]))

    assert len(logs) == 1
    assert logs[0].foods == []


def test_apply_changes_stores_json_ready_items(session: Session) -> None:
    user = AppUser(email="ada@example.com", hashed_password="x")
    session.add(user)
    session.commit()
    food = AddedFood(
        log_date=date(2026, 10, 29),
        entry_id=uuid.uuid4(),
        food_id="off-3017620422003",
        name="Nutella",
        grams=15,
        logged_at=datetime(2026, 10, 29, 8, tzinfo=UTC),
        energy_kcal=81,
    )

    [log] = service.apply_changes(session, user.id, LogChanges(added=[food]))

    assert log.foods[0]["entry_id"] == str(food.entry_id)
    assert log.foods[0]["logged_at"] == "2026-10-29T08:00:00Z"
    assert "log_date" not in log.foods[0]
    assert log.energy_kcal == 81


def test_apply_changes_stays_after_a_change_stamped_by_a_clock_ahead(
    session: Session,
) -> None:
    user = AppUser(email="ada@example.com", hashed_password="x")
    session.add(user)
    session.commit()
    # Another replica, whose clock runs an hour ahead, saved this day.
    ahead = DailyLog(
        user_id=user.id,
        log_date=date(2026, 10, 28),
        updated_at=datetime.now(UTC) + timedelta(hours=1),
    )
    session.add(ahead)
    session.commit()
    cursor = service.encode_cursor(ahead)
    removal = RemovedFood(log_date=date(2026, 10, 29), entry_id=uuid.uuid4())

    [log] = service.apply_changes(session, user.id, LogChanges(removed=[removal]))
    days, _, _ = service.list_changed(session, user.id, cursor, limit=100)

    assert log.updated_at > ahead.updated_at
    assert [day.log_date for day in days] == [date(2026, 10, 29)]


@pytest.mark.parametrize(
    "cursor",
    [
        "%%%",
        "bm90IGpzb24",  # "not json"
        "WzEsIDJd",  # [1, 2]
        "WyIyMDI2LTEwLTI5VDA4OjAwOjAwIiwgIjIwMjYtMTAtMjkiXQ==",  # naive timestamp
    ],
)
def test_decode_cursor_rejects_bad_input(cursor: str) -> None:
    with pytest.raises(InvalidCursor):
        service.decode_cursor(cursor)
