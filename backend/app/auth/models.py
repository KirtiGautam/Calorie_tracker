import uuid
from datetime import datetime

from sqlmodel import Field, SQLModel

from app.db_types import UTCDateTime


class RefreshToken(SQLModel, table=True):
    """A refresh token the server issued, so it can be used only once and revoked.

    The tokens one sign-in leads to share a `family_id`: each refresh marks its token used and issues
    the next one in the family. A used token coming back means two parties hold the same chain, so
    the whole family is revoked (RFC 9700 §4.14.2).
    """

    __tablename__ = "refresh_token"

    # The token's `jti` claim.
    jti: str = Field(primary_key=True, max_length=64)
    family_id: uuid.UUID = Field(index=True)
    user_id: uuid.UUID = Field(
        foreign_key="app_user.id", ondelete="CASCADE", index=True
    )
    issued_at: datetime = Field(sa_type=UTCDateTime)
    # Indexed for the daily job that deletes expired rows (migration 0004).
    expires_at: datetime = Field(sa_type=UTCDateTime, index=True)
    # When the token was exchanged for the next one. `None` while it's the family's newest.
    used_at: datetime | None = Field(default=None, sa_type=UTCDateTime)
    # When the family was signed out or caught being reused. Set on every token in the family.
    revoked_at: datetime | None = Field(default=None, sa_type=UTCDateTime)
