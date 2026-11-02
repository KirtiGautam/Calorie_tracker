import uuid
from datetime import date, datetime

from pydantic import BaseModel, Field

from app.schemas import UTCDatetime

MAX_CHANGES = 500
MAX_FOODS_PER_DAY = 200


class LoggedFood(BaseModel):
    """One food in a day. The macros are for the amount eaten, and `None` means unknown."""

    entry_id: uuid.UUID
    food_id: str = Field(max_length=64, pattern=r"^(usda|off)-[A-Za-z0-9]+$")
    # The fallback when the food can no longer be looked up.
    name: str = Field(min_length=1, max_length=500)
    grams: float = Field(gt=0, le=5000)
    logged_at: UTCDatetime
    energy_kcal: float | None = Field(default=None, ge=0, le=50_000)
    protein_g: float | None = Field(default=None, ge=0, le=5000)
    carbs_g: float | None = Field(default=None, ge=0, le=5000)
    fat_g: float | None = Field(default=None, ge=0, le=5000)


class AddedFood(LoggedFood):
    log_date: date


class RemovedFood(BaseModel):
    log_date: date
    entry_id: uuid.UUID


class LogChanges(BaseModel):
    """Foods to add or replace, and foods to remove, grouped by the server into days."""

    added: list[AddedFood] = Field(default_factory=list, max_length=MAX_CHANGES)
    removed: list[RemovedFood] = Field(default_factory=list, max_length=MAX_CHANGES)


class DailyLogPublic(BaseModel):
    log_date: date
    energy_kcal: float | None
    protein_g: float | None
    carbs_g: float | None
    fat_g: float | None
    foods: list[LoggedFood]
    updated_at: datetime


class ChangedDays(BaseModel):
    """The days a change touched, after the merge."""

    days: list[DailyLogPublic]


class DailyLogPage(BaseModel):
    """One page of changed days.

    `next_cursor` is the position after the last day returned (or the request's cursor when the page
    is empty), so a client can store it and resume from there on its next sync. Keep requesting
    while `has_more` is true.
    """

    days: list[DailyLogPublic]
    next_cursor: str | None
    has_more: bool
