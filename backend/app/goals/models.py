import uuid
from datetime import date, datetime

from sqlalchemy import CheckConstraint
from sqlmodel import Field

from app.db_types import UTCDateTime
from app.macros import Macros


class UserGoal(Macros, table=True):
    """One account's daily targets and weight goal from `effective_from` until the next row's day.

    Each day the goal changes on gets its own row, so earlier days keep the goal they had. The
    targets are the `Macros` fields. The body profile stays on the device.
    """

    __tablename__ = "user_goal"
    __table_args__ = (
        CheckConstraint("goal IN ('cut', 'maintain', 'bulk')", name="goal"),
    )

    user_id: uuid.UUID = Field(
        primary_key=True, foreign_key="app_user.id", ondelete="CASCADE"
    )
    # The day the goal was saved on, in the saving device's time zone.
    effective_from: date = Field(primary_key=True)
    goal: str = Field(max_length=16)
    # When the person saved the goal on their device. The newest save of a day wins.
    updated_at: datetime = Field(sa_type=UTCDateTime)
