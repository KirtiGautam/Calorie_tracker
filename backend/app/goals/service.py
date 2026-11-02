import uuid
from datetime import UTC, datetime, timedelta

from sqlmodel import Session, col, select

from app.goals.exceptions import GoalNotFound, GoalOutdated, InvalidGoalDate
from app.goals.models import UserGoal
from app.goals.schemas import GoalIn
from app.users.models import AppUser


def current(session: Session, user_id: uuid.UUID) -> UserGoal | None:
    """The goal with the latest `effective_from`, or `None` when none has been saved."""
    return session.exec(
        select(UserGoal)
        .where(UserGoal.user_id == user_id)
        .order_by(col(UserGoal.effective_from).desc())
        .limit(1)
    ).first()


def get(session: Session, user_id: uuid.UUID) -> UserGoal:
    goal = current(session, user_id)
    if goal is None:
        raise GoalNotFound("No goal has been saved yet")
    return goal


def put(
    session: Session, user_id: uuid.UUID, goal_in: GoalIn, now: datetime | None = None
) -> UserGoal:
    """Saves `goal_in` as the goal from its `effective_from` day on, and returns the stored goal.

    A goal for a later day than the current one is added as a new row, so earlier days keep their
    goal. One for the same day replaces it when it was saved later, and an identical save (a retry)
    returns the stored goal unchanged. Anything older raises `GoalOutdated`, so a past day's goal
    never changes. `now` is the current UTC time, which tests may pin.
    """
    # A device clock set in the future would otherwise win every later comparison. Both are UTC.
    updated_at = min(goal_in.updated_at, now or datetime.now(UTC))
    # Time zones run from UTC-12 to UTC+14, so the device's day is within one day of the UTC day.
    # This also stops a goal dated in the future from locking out every later save.
    saved_on = updated_at.date()
    one_day = timedelta(days=1)
    if not saved_on - one_day <= goal_in.effective_from <= saved_on + one_day:
        raise InvalidGoalDate(
            "effective_from must be the day updated_at falls on",
            details={"effective_from": goal_in.effective_from.isoformat()},
        )
    values = goal_in.model_dump(exclude={"updated_at", "effective_from"})

    # Locking the account serializes one person's saves, so two can't both add the same day.
    session.exec(
        select(AppUser.id).where(AppUser.id == user_id).with_for_update()
    ).one()
    stored = current(session, user_id)

    if stored is None or goal_in.effective_from > stored.effective_from:
        goal = UserGoal(
            user_id=user_id,
            effective_from=goal_in.effective_from,
            updated_at=updated_at,
            **values,
        )
        session.add(goal)
    elif (
        goal_in.effective_from == stored.effective_from
        and updated_at > stored.updated_at
    ):
        goal = stored
        goal.sqlmodel_update(values | {"updated_at": updated_at})
    elif (
        goal_in.effective_from == stored.effective_from
        and updated_at == stored.updated_at
    ):
        return stored
    else:
        raise GoalOutdated(
            "A newer goal is already saved, and goals of past days can't change",
            details={"effective_from": stored.effective_from.isoformat()},
        )

    session.commit()
    session.refresh(goal)
    return goal
