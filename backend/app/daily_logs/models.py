import uuid
from datetime import date, datetime
from typing import Any

from sqlalchemy import Column, Index
from sqlmodel import Field, SQLModel

from app.db_types import JSONType, UTCDateTime


class DailyLog(SQLModel, table=True):
    """One account's foods for one day, with totals the server computes from them."""

    __tablename__ = "daily_log"
    __table_args__ = (
        Index(
            "daily_log_user_id_updated_at_log_date_idx",
            "user_id",
            "updated_at",
            "log_date",
        ),
    )

    user_id: uuid.UUID = Field(
        primary_key=True, foreign_key="app_user.id", ondelete="CASCADE"
    )
    log_date: date = Field(primary_key=True)
    energy_kcal: float | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fat_g: float | None = None
    # A list of `LoggedFood` dicts. Always assign a new list, so SQLAlchemy sees the change.
    foods: list[dict[str, Any]] = Field(
        default_factory=list, sa_column=Column(JSONType, nullable=False)
    )
    # Set by the server on every change, for pulls.
    updated_at: datetime = Field(sa_type=UTCDateTime)
