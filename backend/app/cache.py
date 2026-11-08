import time
from collections import OrderedDict
from collections.abc import Awaitable, Callable, Hashable

from fastapi import Response

MAX_BYTES = 64 * 1024 * 1024
# The cache's name in `Cache-Status` (RFC 9211).
CACHE_NAME = "gramwise"
TTL_SECONDS = 24 * 60 * 60
# Roughly what an entry's key and bookkeeping use. Counting it keeps many tiny bodies, such as
# searches with no results, from using far more memory than the limit says.
ENTRY_OVERHEAD_BYTES = 1024


class ResponseCache:
    """A least-recently-used cache of response bodies, bounded in bytes and in age.

    It lives in this process, so a restart empties it and replicas don't share it. Every method runs
    on the event loop without awaiting, so it needs no lock.
    """

    def __init__(
        self,
        max_bytes: int = MAX_BYTES,
        ttl_seconds: float = TTL_SECONDS,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._max_bytes = max_bytes
        self._ttl_seconds = ttl_seconds
        self._clock = clock
        self._entries: OrderedDict[Hashable, tuple[bytes, float]] = OrderedDict()
        self._used_bytes = 0

    def get(self, key: Hashable) -> bytes | None:
        """Returns the body stored for `key`, or `None` when there's none or it has expired."""
        entry = self._entries.get(key)
        if entry is None:
            return None
        body, expires_at = entry
        if self._clock() >= expires_at:
            self._remove(key)
            return None
        self._entries.move_to_end(key)
        return body

    def put(self, key: Hashable, body: bytes) -> None:
        """Stores `body`, evicting the least recently used entries when over the limit."""
        self._remove(key)
        size = _size(body)
        if size > self._max_bytes:
            return
        self._entries[key] = (body, self._clock() + self._ttl_seconds)
        self._used_bytes += size
        while self._used_bytes > self._max_bytes:
            _, (evicted, _) = self._entries.popitem(last=False)
            self._used_bytes -= _size(evicted)

    def _remove(self, key: Hashable) -> None:
        entry = self._entries.pop(key, None)
        if entry is not None:
            self._used_bytes -= _size(entry[0])


def _size(body: bytes) -> int:
    return len(body) + ENTRY_OVERHEAD_BYTES


async def cached_json(
    cache: ResponseCache, key: Hashable, fetch: Callable[[], Awaitable[bytes]]
) -> Response:
    """Returns the JSON body stored for `key`, or fetches and stores it. Failures aren't stored.

    The response says which it was in `Cache-Status` (RFC 9211): `gramwise; hit`, or
    `gramwise; fwd=uri-miss` when it was fetched.
    """
    body = cache.get(key)
    outcome = "hit"
    if body is None:
        body = await fetch()
        cache.put(key, body)
        outcome = "fwd=uri-miss"
    return Response(
        content=body,
        media_type="application/json",
        headers={"Cache-Status": f"{CACHE_NAME}; {outcome}"},
    )
