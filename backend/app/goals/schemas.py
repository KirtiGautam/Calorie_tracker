from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.macros import Macros
from app.schemas import UTCDatetime

WeightGoal = Literal["cut", "maintain", "bulk"]


class GoalIn(BaseModel):
    """A goal saved on a device.

    `updated_at` is when the person saved it there, and `effective_from` is that moment's day in the
    device's time zone.
    """

    goal: WeightGoal
    energy_kcal: float | None = Field(default=None, ge=0, le=100_000)
    protein_g: float | None = Field(default=None, ge=0, le=10_000)
    carbs_g: float | None = Field(default=None, ge=0, le=10_000)
    fat_g: float | None = Field(default=None, ge=0, le=10_000)
    updated_at: UTCDatetime
    effective_from: date


class GoalPublic(Macros):
    """A stored goal, with its targets in the `Macros` fields."""

    goal: WeightGoal
    updated_at: datetime
    effective_from: date
