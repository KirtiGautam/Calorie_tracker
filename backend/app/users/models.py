import uuid
from datetime import UTC, datetime

from sqlmodel import Field, SQLModel

from app.db_types import UTCDateTime


class AppUser(SQLModel, table=True):
    """An account. Named `app_user` because `user` is reserved in Postgres."""

    __tablename__ = "app_user"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    # Stored trimmed and lowercased, so the unique constraint ignores letter case.
    email: str = Field(max_length=254, unique=True)
    hashed_password: str = Field(max_length=255)
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(UTC), sa_type=UTCDateTime
    )
