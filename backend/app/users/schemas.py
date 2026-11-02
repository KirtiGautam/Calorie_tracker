import uuid
from typing import Annotated

from pydantic import BaseModel, BeforeValidator, EmailStr


def normalize_email(email: str) -> str:
    """Trims and lowercases `email`, so lookups and the unique constraint ignore case."""
    return email.strip().lower()


def _normalize_if_text(value: object) -> object:
    return normalize_email(value) if isinstance(value, str) else value


# An email that's trimmed and lowercased before it's validated.
NormalizedEmail = Annotated[EmailStr, BeforeValidator(_normalize_if_text)]


class UserPublic(BaseModel):
    """The account fields a client may see."""

    id: uuid.UUID
    email: str
