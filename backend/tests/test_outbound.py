import logging
from collections.abc import AsyncIterator, Callable
from datetime import UTC, datetime

import httpx
import pytest
from fastapi import status

from app.exceptions import AppError
from app.outbound import (
    DEFAULT_TIMEOUT_SECONDS,
    JSONAPIClient,
    make_http_client,
    retry_after_seconds,
)


class ExampleTimeout(AppError):
    status_code = status.HTTP_504_GATEWAY_TIMEOUT
    code = "example_timeout"


class ExampleUnavailable(AppError):
    status_code = status.HTTP_502_BAD_GATEWAY
    code = "example_unavailable"


class ExampleRateLimited(AppError):
    status_code = status.HTTP_429_TOO_MANY_REQUESTS
    code = "example_rate_limited"


class ExampleClient(JSONAPIClient):
    """A client for a made-up API that records the responses its hook sees."""

    service_name = "Example"
    base_url = "https://api.example.com/v1"
    timeout_error = ExampleTimeout
    unavailable_error = ExampleUnavailable
    rate_limited_error = ExampleRateLimited

    def __init__(self, http_client: httpx.AsyncClient) -> None:
        super().__init__(http_client)
        self.seen: list[httpx.Response] = []

    def request_headers(self) -> dict[str, str]:
        return {"X-Api-Key": "secret"}

    def on_response(self, response: httpx.Response) -> None:
        self.seen.append(response)


Handler = Callable[[httpx.Request], httpx.Response]


@pytest.fixture
def anyio_backend() -> str:
    return "asyncio"


@pytest.fixture
async def answer_with() -> AsyncIterator[Callable[[Handler], ExampleClient]]:
    """Builds an `ExampleClient` whose requests `handler` answers."""
    http_clients: list[httpx.AsyncClient] = []

    def build(handler: Handler) -> ExampleClient:
        http_client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        http_clients.append(http_client)
        return ExampleClient(http_client)

    yield build
    for http_client in http_clients:
        await http_client.aclose()


def raising(exc: Exception) -> Handler:
    def handler(request: httpx.Request) -> httpx.Response:
        raise exc

    return handler


@pytest.mark.anyio
async def test_post_sends_json_with_the_headers_and_returns_the_body(
    answer_with: Callable[[Handler], ExampleClient],
) -> None:
    requests: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return httpx.Response(200, content=b'{"ok": true}')

    client = answer_with(handler)

    body = await client.post("things", {"name": "banana"})

    assert body == b'{"ok": true}'
    assert str(requests[0].url) == "https://api.example.com/v1/things"
    assert requests[0].method == "POST"
    assert requests[0].headers["X-Api-Key"] == "secret"
    assert requests[0].content == b'{"name":"banana"}'
    assert len(client.seen) == 1


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("handler", "error"),
    [
        (raising(httpx.ReadTimeout("too slow")), ExampleTimeout),
        (raising(httpx.ConnectError("no route")), ExampleUnavailable),
        (lambda _: httpx.Response(429), ExampleRateLimited),
        (lambda _: httpx.Response(401), ExampleUnavailable),
        (lambda _: httpx.Response(403), ExampleUnavailable),
        (lambda _: httpx.Response(500), ExampleUnavailable),
        (lambda _: httpx.Response(404), ExampleUnavailable),
    ],
)
async def test_failures_raise_the_client_s_own_errors(
    answer_with: Callable[[Handler], ExampleClient],
    handler: Handler,
    error: type[AppError],
) -> None:
    with pytest.raises(error) as raised:
        await answer_with(handler).post("things", {})

    assert "Example" in raised.value.message


@pytest.mark.anyio
async def test_redirects_are_not_followed(
    answer_with: Callable[[Handler], ExampleClient],
) -> None:
    hosts: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        hosts.append(request.url.host)
        return httpx.Response(302, headers={"Location": "https://elsewhere.example/"})

    client = answer_with(handler)
    # A client that follows redirects by default must still not follow them here.
    client._http_client.follow_redirects = True

    with pytest.raises(ExampleUnavailable):
        await client.post("things", {})

    assert hosts == ["api.example.com"]


@pytest.mark.anyio
async def test_the_hook_sees_failed_responses_too(
    answer_with: Callable[[Handler], ExampleClient],
) -> None:
    client = answer_with(lambda _: httpx.Response(429))

    with pytest.raises(ExampleRateLimited):
        await client.post("things", {})

    assert [response.status_code for response in client.seen] == [429]


@pytest.mark.anyio
async def test_credential_failures_are_logged_as_errors(
    answer_with: Callable[[Handler], ExampleClient],
    caplog: pytest.LogCaptureFixture,
) -> None:
    with pytest.raises(ExampleUnavailable):
        await answer_with(lambda _: httpx.Response(403)).post("things", {})

    record = caplog.records[-1]
    assert record.levelno == logging.ERROR
    assert record.getMessage() == "Example rejected the API key: HTTP 403"
    assert "secret" not in caplog.text


@pytest.mark.anyio
async def test_the_shared_client_has_a_timeout_and_does_not_follow_redirects() -> None:
    async with make_http_client() as http_client:
        assert http_client.timeout.read == DEFAULT_TIMEOUT_SECONDS
        assert http_client.follow_redirects is False


@pytest.mark.anyio
async def test_rate_limited_errors_carry_the_api_s_retry_after(
    answer_with: Callable[[Handler], ExampleClient],
) -> None:
    client = answer_with(lambda _: httpx.Response(429, headers={"Retry-After": "30"}))

    with pytest.raises(ExampleRateLimited) as raised:
        await client.post("things", {})

    assert raised.value.headers == {"Retry-After": "30"}


@pytest.mark.anyio
async def test_rate_limited_errors_fall_back_to_the_client_s_retry_after(
    answer_with: Callable[[Handler], ExampleClient],
) -> None:
    client = answer_with(lambda _: httpx.Response(429))

    with pytest.raises(ExampleRateLimited) as raised:
        await client.post("things", {})

    assert raised.value.headers == {"Retry-After": "60"}


NOW = datetime(2026, 11, 8, 12, 0, 0, tzinfo=UTC)


@pytest.mark.parametrize(
    ("value", "seconds"),
    [
        (None, 99),
        ("120", 120),
        (" 7 ", 7),
        ("0", 1),
        ("Sun, 08 Nov 2026 12:10:00 GMT", 600),
        ("Sun, 08 Nov 2026 11:00:00 GMT", 1),
        ("Sun, 08 Nov 2026 12:10:00 -0000", 99),
        ("-5", 99),
        ("tomorrow", 99),
    ],
)
def test_retry_after_seconds(value: str | None, seconds: int) -> None:
    assert retry_after_seconds(value, 99, NOW) == seconds
