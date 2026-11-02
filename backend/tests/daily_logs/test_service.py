import base64
import json
import uuid
from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest
from sqlalchemy import Engine, event
from sqlmodel import Session

from app.daily_logs import service
from app.daily_logs.exceptions import InvalidCursor
from app.daily_logs.models import DailyLog
from app.daily_logs.schemas import AddedFood, LogChanges, RemovedFood
from app.macros import MACRO_KEYS
from app.users.models import AppUser


def item(
    entry_id: str, logged_at: str = "2026-10-29T08:00:00Z", **macros: Any
) -> dict[str, Any]:
    return {"entry_id": entry_id, "logged_at": logged_at, **macros}


def cursor_for(updated_at: str, log_date: str) -> str:
    """Encodes a cursor the way the server does, for positions it would never hand out."""
    raw = json.dumps([updated_at, log_date]).encode()
    return base64.urlsafe_b64encode(raw).decode()


def removals(month: int, days: int) -> LogChanges:
    """Removes an unknown food from each of the first `days` days of `month`."""
    return LogChanges(
        removed=[
            RemovedFood(log_date=date(2026, month, day), entry_id=uuid.uuid4())
            for day in range(1, days + 1)
        ]
    )


@pytest.fixture
def user(session: Session) -> AppUser:
    user = AppUser(email="ada@example.com", hashed_password="x")
    session.add(user)
    session.commit()
    return user


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


def test_merge_orders_by_time_not_by_text() -> None:
    merged = service.merge_foods(
        [],
        added=[
            item("half-past", "2026-10-29T08:00:00.500000Z"),
            item("on-the-second", "2026-10-29T08:00:00Z"),
            item("earliest", "2026-10-29T09:30:00+02:00"),
        ],
        removed_ids=[],
    )

    assert [food["entry_id"] for food in merged] == [
        "earliest",
        "on-the-second",
        "half-past",
    ]


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
    assert service.totals_for([]) == dict.fromkeys(MACRO_KEYS)


def test_apply_changes_with_nothing_returns_nothing(session: Session) -> None:
    assert service.apply_changes(session, uuid.uuid4(), LogChanges()) == []


def test_apply_changes_creates_row_even_for_removal_only(
    session: Session, user: AppUser
) -> None:
    removal = RemovedFood(log_date=date(2026, 10, 29), entry_id=uuid.uuid4())

    logs = service.apply_changes(session, user.id, LogChanges(removed=[removal]))

    assert len(logs) == 1
    assert logs[0].foods == []


def test_apply_changes_stores_json_ready_items(session: Session, user: AppUser) -> None:
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
    session: Session, user: AppUser
) -> None:
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


def test_apply_changes_runs_the_same_queries_for_any_number_of_days(
    session: Session, engine: Engine, user: AppUser
) -> None:
    def statements_for(changes: LogChanges) -> int:
        count = 0

        def count_statement(*_: Any) -> None:
            nonlocal count
            count += 1

        event.listen(engine, "before_cursor_execute", count_statement)
        try:
            service.apply_changes(session, user.id, changes)
        finally:
            event.remove(engine, "before_cursor_execute", count_statement)
        return count

    few = statements_for(removals(month=1, days=2))
    many = statements_for(removals(month=2, days=25))

    assert many == few


def test_apply_changes_returns_touched_days_oldest_first(
    session: Session, user: AppUser
) -> None:
    logs = service.apply_changes(session, user.id, removals(month=3, days=5))

    assert [log.log_date for log in logs] == [date(2026, 3, day) for day in range(1, 6)]


def test_decode_cursor_returns_the_position_in_utc() -> None:
    position = service.decode_cursor(
        cursor_for("2026-10-29T10:00:00+02:00", "2026-10-29")
    )

    assert position == (datetime(2026, 10, 29, 8, tzinfo=UTC), date(2026, 10, 29))
    assert position[0].tzinfo == UTC


@pytest.mark.parametrize(
    ("updated_at", "log_date"),
    [
        ("0001-01-01T00:00:00+14:00", "2026-10-29"),  # before year 1 in UTC
        ("9999-12-31T23:59:59-14:00", "2026-10-29"),  # after year 9999 in UTC
        ("2026-10-29T08:00:00Z", "2026-02-30"),
    ],
)
def test_decode_cursor_rejects_out_of_range_positions(
    updated_at: str, log_date: str
) -> None:
    with pytest.raises(InvalidCursor):
        service.decode_cursor(cursor_for(updated_at, log_date))


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
