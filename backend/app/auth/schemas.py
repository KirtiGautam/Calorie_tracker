from typing import Literal

from pydantic import BaseModel, Field

from app.users.schemas import NormalizedEmail, UserPublic


class SignupRequest(BaseModel):
    email: NormalizedEmail
    password: str = Field(min_length=8, max_length=128)


class LoginRequest(BaseModel):
    email: NormalizedEmail
    # No minimum here: a short password just fails to match, with the same error as any other.
    password: str = Field(min_length=1, max_length=128)


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
