import unicodedata
from typing import Annotated, Literal

from pydantic import BaseModel, BeforeValidator, Field

from app.users.schemas import NormalizedEmail, UserPublic


def _nfc_if_text(value: object) -> object:
    return unicodedata.normalize("NFC", value) if isinstance(value, str) else value


# A password in Unicode NFC (RFC 8265 §4.2), so the same visible password always hashes the same,
# however the keyboard composed its accents. The length limits apply to the normalized text.
Password = Annotated[str, BeforeValidator(_nfc_if_text)]


class SignupRequest(BaseModel):
    email: NormalizedEmail
    password: Password = Field(min_length=8, max_length=128)


class LoginRequest(BaseModel):
    email: NormalizedEmail
    # No minimum here: a short password just fails to match, with the same error as any other.
    password: Password = Field(min_length=1, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1, max_length=2048)


class TokenPair(BaseModel):
    """What signup, login and refresh return."""

    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"  # noqa: S105 - the OAuth token type, not a secret
    # Seconds until `access_token` expires.
    expires_in: int
    user: UserPublic
