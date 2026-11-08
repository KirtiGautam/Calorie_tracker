from typing import Any

from fastapi import status

from app.exceptions import AppError


class InvalidCredentials(AppError):
    """A wrong password or an unknown email at sign-in.

    A 400, as for OAuth's `invalid_grant` (RFC 6749 §5.2): sign-in doesn't use HTTP authentication,
    so a 401 and its required `WWW-Authenticate` challenge don't apply.
    """

    status_code = status.HTTP_400_BAD_REQUEST
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


class InvalidRefreshToken(AppError):
    """A refresh token in a request body that's malformed, expired, used, revoked or for a deleted account.

    A 400, as for OAuth's `invalid_grant`, since the token isn't HTTP authentication. It keeps the
    `invalid_token` code, which the app signs out on.
    """

    status_code = status.HTTP_400_BAD_REQUEST
    code = "invalid_token"
