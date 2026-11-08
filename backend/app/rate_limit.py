import ipaddress
import math
import time
from collections.abc import Awaitable, Callable

from fastapi import Request, status

from app.exceptions import AppError

WINDOW_SECONDS = 60 * 60
MAX_TRACKED_CLIENTS = 10_000
# One IPv6 device can use every address in its /64, so that's what counts as one client.
IPV6_CLIENT_PREFIX = 64


class RateLimited(AppError):
    """This client sent more requests than its allowance for the window."""

    status_code = status.HTTP_429_TOO_MANY_REQUESTS
    code = "rate_limited"


def client_key(host: str | None) -> str:
    """Returns who a request's address counts as for the rate limit."""
    if host is None:
        return "unknown"
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        return host
    if isinstance(address, ipaddress.IPv6Address):
        if address.ipv4_mapped is not None:
            return str(address.ipv4_mapped)
        return str(ipaddress.ip_network((address, IPV6_CLIENT_PREFIX), strict=False))
    return str(address)


class ClientRateLimiter:
    """Allows each client `limit` requests per fixed window.

    It lives in this process, so a restart resets it and each replica counts on its own. Every method
    runs on the event loop without awaiting, so it needs no lock.
    """

    def __init__(
        self,
        limit: int,
        window_seconds: float = WINDOW_SECONDS,
        max_clients: int = MAX_TRACKED_CLIENTS,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._limit = limit
        self._window_seconds = window_seconds
        self._max_clients = max_clients
        self._clock = clock
        # Each client's window start and request count. A new window is always re-inserted, so the
        # first item is the oldest window.
        self._windows: dict[str, tuple[float, int]] = {}

    def check(self, client: str) -> None:
        """Counts a request from `client`, or raises `RateLimited` when its window is used up."""
        now = self._clock()
        started_at, count = self._windows.get(client, (-math.inf, 0))
        if now - started_at >= self._window_seconds:
            self._start_window(client, now)
            return
        if count >= self._limit:
            retry_after = math.ceil(started_at + self._window_seconds - now)
            raise RateLimited(
                "Too many requests. Try again later.",
                headers={"Retry-After": str(retry_after)},
            )
        self._windows[client] = (started_at, count + 1)

    def _start_window(self, client: str, now: float) -> None:
        self._windows.pop(client, None)
        if len(self._windows) >= self._max_clients:
            # Forgetting the window closest to ending costs that client the least.
            del self._windows[next(iter(self._windows))]
        self._windows[client] = (now, 1)


def limit_by_client(state_attr: str) -> Callable[[Request], Awaitable[None]]:
    """Returns a dependency that counts each request against the limiter at `app.state.<state_attr>`.

    The limiter is looked up on every request, because the lifespan creates it after routers are
    declared. A request counts whether or not the route goes on to do any work.
    """

    async def check_client(request: Request) -> None:
        host = request.client.host if request.client else None
        limiter: ClientRateLimiter = getattr(request.app.state, state_attr)
        limiter.check(client_key(host))

    return check_client
