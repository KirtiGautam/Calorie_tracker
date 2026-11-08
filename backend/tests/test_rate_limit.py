import pytest

from app.rate_limit import ClientRateLimiter, RateLimited, client_key


class FakeClock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


def test_refuses_requests_over_the_limit_and_says_when_to_retry() -> None:
    clock = FakeClock()
    limiter = ClientRateLimiter(limit=2, window_seconds=60, clock=clock)
    limiter.check("a")
    limiter.check("a")

    clock.now = 45.5
    with pytest.raises(RateLimited) as excinfo:
        limiter.check("a")

    assert excinfo.value.headers == {"Retry-After": "15"}


def test_clients_have_separate_allowances() -> None:
    limiter = ClientRateLimiter(limit=1)
    limiter.check("a")

    limiter.check("b")

    with pytest.raises(RateLimited):
        limiter.check("a")


def test_allowance_returns_when_the_window_ends() -> None:
    clock = FakeClock()
    limiter = ClientRateLimiter(limit=1, window_seconds=60, clock=clock)
    limiter.check("a")

    clock.now = 60
    limiter.check("a")

    with pytest.raises(RateLimited):
        limiter.check("a")


def test_forgets_the_oldest_window_when_tracking_too_many_clients() -> None:
    clock = FakeClock()
    limiter = ClientRateLimiter(limit=1, max_clients=2, clock=clock)
    limiter.check("a")
    clock.now = 1
    limiter.check("b")

    limiter.check("c")

    # "a" was forgotten, so it starts over. That in turn forgets "b", the oldest left.
    limiter.check("a")
    limiter.check("b")
    with pytest.raises(RateLimited):
        limiter.check("a")


@pytest.mark.parametrize(
    ("host", "expected"),
    [
        ("203.0.113.7", "203.0.113.7"),
        ("2001:db8:1:2:3:4:5:6", "2001:db8:1:2::/64"),
        ("2001:db8:1:2:aaaa:bbbb:cccc:dddd", "2001:db8:1:2::/64"),
        ("::ffff:203.0.113.7", "203.0.113.7"),
        ("testclient", "testclient"),
        (None, "unknown"),
    ],
)
def test_client_key(host: str | None, expected: str) -> None:
    assert client_key(host) == expected
