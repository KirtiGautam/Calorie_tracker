import base64
import binascii
import json
import uuid
from collections import defaultdict
from collections.abc import Iterable
from datetime import UTC, date, datetime
from typing import Any

from sqlalchemy import tuple_
from sqlmodel import Session, col, select

from app.daily_logs.exceptions import InvalidCursor, TooManyFoods
from app.daily_logs.models import DailyLog
from app.daily_logs.schemas import MAX_FOODS_PER_DAY, LogChanges
from app.users.models import AppUser

MACRO_KEYS = ("energy_kcal", "protein_g", "carbs_g", "fat_g")


def merge_foods(
    existing: Iterable[dict[str, Any]],
    added: Iterable[dict[str, Any]],
    removed_ids: Iterable[str],
) -> list[dict[str, Any]]:
    """Merges by `entry_id`: an added item replaces one with the same ID, and removed IDs are dropped.

    Removal wins over an addition in the same change. The result is ordered by `logged_at`, then ID.
    """
    by_id = {item["entry_id"]: item for item in existing}
    for item in added:
        by_id[item["entry_id"]] = item
    for entry_id in removed_ids:
        by_id.pop(entry_id, None)
    return sorted(
        by_id.values(), key=lambda item: (item["logged_at"], item["entry_id"])
    )


def totals_for(foods: Iterable[dict[str, Any]]) -> dict[str, float | None]:
    """Sums each macro over the foods that report it. A macro no food reports stays `None`."""
    totals: dict[str, float | None] = dict.fromkeys(MACRO_KEYS)
    for item in foods:
        for key in MACRO_KEYS:
            value = item.get(key)
            if value is not None:
                totals[key] = (totals[key] or 0) + value
    return totals


def apply_changes(
    session: Session, user_id: uuid.UUID, changes: LogChanges
) -> list[DailyLog]:
    """Applies `changes` in one transaction and returns the touched days, oldest first.

    Merging by `entry_id` makes a retried request harmless.
    """
    added: dict[date, list[dict[str, Any]]] = defaultdict(list)
    for food in changes.added:
        added[food.log_date].append(food.model_dump(mode="json", exclude={"log_date"}))
    removed: dict[date, set[str]] = defaultdict(set)
    for food in changes.removed:
        removed[food.log_date].add(str(food.entry_id))

    days = sorted(added.keys() | removed.keys())
    if not days:
        return []

    # Locking the account serializes one person's pushes, so `updated_at` grows in commit order
    # and a pull can never move its cursor past a push that hasn't committed yet.
    session.exec(
        select(AppUser.id).where(AppUser.id == user_id).with_for_update()
    ).one()
    now = datetime.now(UTC)

    logs: list[DailyLog] = []
    for log_date in days:
        log = session.get(DailyLog, (user_id, log_date))
        if log is None:
            log = DailyLog(user_id=user_id, log_date=log_date, updated_at=now)
            session.add(log)
        foods = merge_foods(log.foods, added[log_date], removed[log_date])
        if len(foods) > MAX_FOODS_PER_DAY:
            session.rollback()
            raise TooManyFoods(
                f"A day can hold at most {MAX_FOODS_PER_DAY} foods",
                {"log_date": log_date.isoformat()},
            )
        log.sqlmodel_update({"foods": foods, "updated_at": now} | totals_for(foods))
        logs.append(log)

    session.commit()
    for log in logs:
        session.refresh(log)
    return logs


def encode_cursor(log: DailyLog) -> str:
    raw = json.dumps([log.updated_at.isoformat(), log.log_date.isoformat()])
    return base64.urlsafe_b64encode(raw.encode()).decode()


def decode_cursor(cursor: str) -> tuple[datetime, date]:
    try:
        updated_at, log_date = json.loads(base64.urlsafe_b64decode(cursor.encode()))
        position = (datetime.fromisoformat(updated_at), date.fromisoformat(log_date))
    except (binascii.Error, ValueError, TypeError) as exc:
        raise InvalidCursor("The cursor isn't valid") from exc
    if position[0].tzinfo is None:
        raise InvalidCursor("The cursor isn't valid")
    return position


def list_changed(
    session: Session, user_id: uuid.UUID, cursor: str | None, limit: int
) -> tuple[list[DailyLog], str | None, bool]:
    """Returns the days changed after `cursor`, oldest change first, the cursor after them, and whether more remain.

    Pages are keyed on `(updated_at, log_date)`, because one push gives many days the same timestamp.
    """
    query = select(DailyLog).where(DailyLog.user_id == user_id)
    if cursor is not None:
        position = decode_cursor(cursor)
        query = query.where(
            tuple_(col(DailyLog.updated_at), col(DailyLog.log_date)) > position
        )
    query = query.order_by(col(DailyLog.updated_at), col(DailyLog.log_date)).limit(
        limit + 1
    )
    logs = list(session.exec(query).all())
    page = logs[:limit]
    next_cursor = encode_cursor(page[-1]) if page else cursor
    return page, next_cursor, len(logs) > limit
