"""The energy and macro fields that goals and daily logs share."""

from sqlmodel import SQLModel


class Macros(SQLModel):
    """Energy and the three macros, each `None` when unknown.

    Table and response models inherit these fields. Request models declare their own, because
    their limits differ.
    """

    energy_kcal: float | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fat_g: float | None = None


MACRO_KEYS: tuple[str, ...] = tuple(Macros.model_fields)
