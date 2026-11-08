"""Calls to external JSON APIs: the shared HTTP client and a base class that maps their failures."""

import logging
from datetime import UTC, datetime
from email.utils import parsedate_to_datetime
from typing import Any, ClassVar

import httpx
from fastapi import status

from app.exceptions import AppError

logger = logging.getLogger(__name__)

# How long any outbound call may take, unless a client asks for something else.
DEFAULT_TIMEOUT_SECONDS = 15.0


def make_http_client() -> httpx.AsyncClient:
    """Creates the one HTTP client the app shares, so every outbound call gets the same defaults."""
    return httpx.AsyncClient(timeout=DEFAULT_TIMEOUT_SECONDS, follow_redirects=False)


class JSONAPIClient:
    """Posts JSON to one external API and returns the body of a 2xx answer.

    Subclasses set `service_name`, `base_url` and the `AppError` subclass to raise for each kind of
    failure, so every API they wrap fails with its own stable codes. Redirects are never followed,
    so headers such as an API key can't reach another host.
    """

    # The name used in log lines and error messages.
    service_name: ClassVar[str]
    # The URL every path is resolved against, without a trailing slash.
    base_url: ClassVar[str]
    # Raised when the API takes longer than the client's timeout.
    timeout_error: ClassVar[type[AppError]]
    # Raised when the API can't be reached, rejects the credentials, or answers with an error.
    unavailable_error: ClassVar[type[AppError]]
    # Raised when the API answers 429, meaning the backend's own allowance is used up. It's raised
    # with a `Retry-After` header.
    rate_limited_error: ClassVar[type[AppError]]
    # The `Retry-After` to send when the API refuses for its rate limit without saying when to retry.
    default_retry_after_seconds: ClassVar[int] = 60

    def __init__(self, http_client: httpx.AsyncClient) -> None:
        self._http_client = http_client

    def request_headers(self) -> dict[str, str]:
        """Headers to send with every request, such as an API key. None by default."""
        return {}

    def on_response(self, response: httpx.Response) -> None:
        """Runs on every response before its status is checked. Does nothing by default."""

    async def post(self, path: str, body: dict[str, Any]) -> bytes:
        """Posts `body` as JSON to `path` and returns the body of a 2xx response.

        Raises `timeout_error`, `rate_limited_error` or `unavailable_error` for anything else.
        """
        service = self.service_name
        try:
            response = await self._http_client.post(
                f"{self.base_url}/{path}",
                json=body,
                headers=self.request_headers(),
                # Set here as well as on the shared client, because a redirect would carry the
                # headers, and any key in them, to whatever host it names.
                follow_redirects=False,
            )
        except httpx.TimeoutException as exc:
            raise self.timeout_error(f"{service} took too long to answer") from exc
        except httpx.TransportError as exc:
            raise self.unavailable_error(f"{service} couldn't be reached") from exc

        self.on_response(response)
        if response.status_code == status.HTTP_429_TOO_MANY_REQUESTS:
            logger.error(
                "%s refused a request: the API key is over its rate limit", service
            )
            retry_after = retry_after_seconds(
                response.headers.get("Retry-After"), self.default_retry_after_seconds
            )
            raise self.rate_limited_error(
                f"{service}'s rate limit was reached. Try again later.",
                headers={"Retry-After": str(retry_after)},
            )
        if response.status_code in {
            status.HTTP_401_UNAUTHORIZED,
            status.HTTP_403_FORBIDDEN,
        }:
            logger.error(
                "%s rejected the API key: HTTP %d", service, response.status_code
            )
            raise self.unavailable_error(f"{service} isn't available right now")
        if not response.is_success:
            logger.warning("%s answered with HTTP %d", service, response.status_code)
            raise self.unavailable_error(f"{service} isn't available right now")
        return response.content


def retry_after_seconds(
    value: str | None, default: int, now: datetime | None = None
) -> int:
    """Returns an upstream `Retry-After` as whole seconds of at least 1, or `default` when it's missing or unreadable.

    RFC 9110 §10.2.3 allows either a number of seconds or an HTTP date.
    """
    if value is None:
        return default
    value = value.strip()
    if value.isdigit():
        return max(1, int(value))
    try:
        retry_at = parsedate_to_datetime(value)
    except TypeError, ValueError:
        return default
    if retry_at.tzinfo is None:
        return default
    seconds = (retry_at - (now or datetime.now(UTC))).total_seconds()
    return max(1, int(seconds))
