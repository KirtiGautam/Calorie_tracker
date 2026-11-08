from typing import Any

from fastapi import status

from app.exceptions import AppError


class InvalidCredentials(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = "invalid_credentials"


class InvalidToken(AppError):
    """A missing, malformed, expired or wrong-type access token, or one for a deleted account.

    The challenge carries `error="invalid_token"` when a token was sent, and no error code when
    none was (RFC 6750 §3.1).
    """

    status_code = status.HTTP_401_UNAUTHORIZED
    code = "invalid_token"

    def __init__(
        self,
        message: str = "Invalid or expired token",
        details: dict[str, Any] | None = None,
        *,
        token_sent: bool = True,
    ) -> None:
        challenge = 'Bearer error="invalid_token"' if token_sent else "Bearer"
        super().__init__(message, details, headers={"WWW-Authenticate": challenge})
