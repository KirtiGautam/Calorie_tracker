"""Password hashing and token signing. No database or HTTP here."""

import uuid
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


def create_token(
    user_id: uuid.UUID,
    token_type: TokenType,
    lifetime: timedelta,
    secret: str,
    now: datetime | None = None,
) -> str:
    issued_at = now or datetime.now(UTC)
    payload = {
        "sub": str(user_id),
        "typ": token_type,
        "iat": issued_at,
        "exp": issued_at + lifetime,
        # Makes every token unique, even two issued in the same second.
        "jti": uuid.uuid4().hex,
    }
    return jwt.encode(payload, secret, algorithm=ALGORITHM)


def decode_token(token: str, expected_type: TokenType, secret: str) -> uuid.UUID:
    """Returns the user ID in a valid token of `expected_type`, or raises `InvalidToken`."""
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
    try:
        return uuid.UUID(str(payload["sub"]))
    except ValueError as exc:
        raise InvalidToken() from exc
