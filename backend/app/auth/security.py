"""Password hashing and token signing. No database or HTTP here."""

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from functools import cache
from typing import Literal

import jwt
from pwdlib import PasswordHash

from app.auth.exceptions import InvalidToken

ALGORITHM = "HS256"

TokenType = Literal["access", "refresh"]

password_hash = PasswordHash.recommended()


def hash_password(password: str) -> str:
    return password_hash.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    return password_hash.verify(password, hashed)


@cache
def dummy_hash() -> str:
    """A hash to verify against when the email is unknown, so the timing matches a real check."""
    return password_hash.hash("not-a-real-password")


@dataclass(frozen=True)
class TokenClaims:
    """What a valid token says."""

    user_id: uuid.UUID
    expires_at: datetime
    # Every token issued since tokens had IDs has one.
    jti: str | None
    # The refresh token family, on refresh tokens issued since families were stored. A refresh
    # token without one predates them.
    family_id: uuid.UUID | None


def create_token(
    user_id: uuid.UUID,
    token_type: TokenType,
    lifetime: timedelta,
    secret: str,
    now: datetime | None = None,
    jti: str | None = None,
    family_id: uuid.UUID | None = None,
) -> str:
    """Signs a token. `jti` defaults to a new random ID, which makes every token unique."""
    issued_at = now or datetime.now(UTC)
    payload = {
        "sub": str(user_id),
        "typ": token_type,
        "iat": issued_at,
        "exp": issued_at + lifetime,
        "jti": jti or new_token_id(),
    }
    if family_id is not None:
        payload["fam"] = str(family_id)
    return jwt.encode(payload, secret, algorithm=ALGORITHM)


def new_token_id() -> str:
    return uuid.uuid4().hex


def decode_token(token: str, expected_type: TokenType, secret: str) -> TokenClaims:
    """Returns the claims of a valid token of `expected_type`, or raises `InvalidToken`."""
    try:
        payload = jwt.decode(
            token,
            secret,
            algorithms=[ALGORITHM],
            options={"require": ["sub", "typ", "exp"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise InvalidToken("Token has expired") from exc
    except jwt.InvalidTokenError as exc:
        raise InvalidToken() from exc

    if payload["typ"] != expected_type:
        raise InvalidToken(f"Expected a {expected_type} token")
    jti = payload.get("jti")
    family = payload.get("fam")
    try:
        return TokenClaims(
            user_id=uuid.UUID(str(payload["sub"])),
            expires_at=datetime.fromtimestamp(payload["exp"], UTC),
            jti=str(jti) if jti is not None else None,
            family_id=uuid.UUID(str(family)) if family is not None else None,
        )
    except (ValueError, TypeError, OverflowError) as exc:
        raise InvalidToken() from exc
