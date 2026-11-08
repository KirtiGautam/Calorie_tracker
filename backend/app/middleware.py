"""ASGI middleware that applies to every route."""

from starlette.datastructures import Headers, MutableHeaders
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.exceptions import ContentTooLarge, error_response

# The largest legitimate body is `POST /daily-logs/changes` with 500 added foods, each with a
# 500-character name. Even when every character takes 4 bytes, or a client escapes them as `\uXXXX`,
# that stays under 2 MiB.
MAX_BODY_BYTES = 2 * 1024 * 1024

# Responses from these path prefixes may be stored by caches. Everything else is personal data or
# tokens.
CACHEABLE_PREFIXES = ("/usda/",)
# Token responses also get `Pragma: no-cache`, as RFC 6749 §5.1 asks.
TOKEN_PREFIXES = ("/auth/",)


class BodySizeLimitMiddleware:
    """Answers 413 `content_too_large` for a request body over `max_bytes`.

    A body that declares a larger `Content-Length` is refused before it's read. One without a length
    (chunked) is counted as it arrives, and refused as soon as it goes over, so it's never held in
    memory in full. Starlette's own `RequestBodyLimitMiddleware` sends plain text in the first case,
    which would break the error envelope.
    """

    def __init__(self, app: ASGIApp, max_bytes: int = MAX_BODY_BYTES) -> None:
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        declared = Headers(scope=scope).get("content-length", "")
        if declared.isdigit() and int(declared) > self.max_bytes:
            exc = ContentTooLarge()
            response = error_response(exc.status_code, exc.code, exc.detail)
            await response(scope, receive, send)
            return

        received = 0

        async def receive_within_limit() -> Message:
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > self.max_bytes:
                    # The app's exception handler turns this into the error envelope.
                    raise ContentTooLarge()
            return message

        await self.app(scope, receive_within_limit, send)


class CacheControlMiddleware:
    """Marks every response that isn't public food data as `Cache-Control: no-store`.

    Without it, `URLSession`'s cache could write an account, goal or day of logged foods to disk,
    where it would stay after sign-out. A route that sets its own `Cache-Control` keeps it.
    """

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        path: str = scope.get("path", "")
        if scope["type"] != "http" or path.startswith(CACHEABLE_PREFIXES):
            await self.app(scope, receive, send)
            return

        async def send_with_cache_control(message: Message) -> None:
            if message["type"] == "http.response.start":
                headers = MutableHeaders(scope=message)
                headers.setdefault("Cache-Control", "no-store")
                if path.startswith(TOKEN_PREFIXES):
                    headers.setdefault("Pragma", "no-cache")
            await send(message)

        await self.app(scope, receive, send_with_cache_control)
