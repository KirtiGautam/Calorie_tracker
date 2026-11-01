from typing import Any

from fastapi import status

from app.exceptions import AppError


class InvalidCredentials(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = "invalid_credentials"


class InvalidToken(AppError):
    """A missing, malformed, expired or wrong-type token, or one for a deleted account."""

    status_code = status.HTTP_401_UNAUTHORIZED
    code = "invalid_token"

    def __init__(
        self,
        message: str = "Invalid or expired token",
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message, details, headers={"WWW-Authenticate": "Bearer"})
