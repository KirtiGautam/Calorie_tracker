from fastapi import status

from app.exceptions import AppError


class USDARateLimited(AppError):
    """USDA refused the request because the backend's API key is over its limit.

    It's a 503, not a 429: the key is shared, so every user is refused until USDA lifts the block,
    whoever caused it. It comes with `Retry-After`.
    """

    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    code = "usda_rate_limited"


class USDAUnavailable(AppError):
    """USDA failed, couldn't be reached, or sent a response in an unexpected shape."""

    status_code = status.HTTP_502_BAD_GATEWAY
    code = "usda_unavailable"


class USDATimeout(AppError):
    status_code = status.HTTP_504_GATEWAY_TIMEOUT
    code = "usda_timeout"
