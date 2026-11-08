from app.cache import ENTRY_OVERHEAD_BYTES, ResponseCache

ENTRY_SIZE = ENTRY_OVERHEAD_BYTES + 3


class FakeClock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


def test_returns_a_stored_body() -> None:
    cache = ResponseCache()

    cache.put("a", b"one")

    assert cache.get("a") == b"one"
    assert cache.get("b") is None


def test_entries_expire() -> None:
    clock = FakeClock()
    cache = ResponseCache(ttl_seconds=10, clock=clock)
    cache.put("a", b"one")

    clock.now = 9.9
    assert cache.get("a") == b"one"

    clock.now = 10
    assert cache.get("a") is None


def test_evicts_the_least_recently_used_entry_when_over_the_limit() -> None:
    cache = ResponseCache(max_bytes=2 * ENTRY_SIZE)
    cache.put("a", b"one")
    cache.put("b", b"two")
    assert cache.get("a") == b"one"

    cache.put("c", b"six")

    assert cache.get("a") == b"one"
    assert cache.get("b") is None
    assert cache.get("c") == b"six"


def test_replacing_an_entry_doesnt_count_it_twice() -> None:
    cache = ResponseCache(max_bytes=2 * ENTRY_SIZE)
    cache.put("a", b"one")
    cache.put("b", b"two")

    cache.put("b", b"new")

    assert cache.get("a") == b"one"
    assert cache.get("b") == b"new"


def test_expired_entries_free_their_space() -> None:
    clock = FakeClock()
    cache = ResponseCache(max_bytes=2 * ENTRY_SIZE, ttl_seconds=10, clock=clock)
    cache.put("a", b"one")
    clock.now = 5
    cache.put("b", b"two")

    clock.now = 10
    assert cache.get("a") is None
    cache.put("c", b"six")

    # Removing "a" made room for "c", so "b" wasn't evicted.
    assert cache.get("b") == b"two"
    assert cache.get("c") == b"six"


def test_a_body_larger_than_the_limit_isnt_stored() -> None:
    cache = ResponseCache(max_bytes=ENTRY_SIZE)
    cache.put("a", b"one")

    cache.put("b", b"too large to fit")

    assert cache.get("a") == b"one"
    assert cache.get("b") is None


def test_many_tiny_bodies_still_count_towards_the_limit() -> None:
    cache = ResponseCache(max_bytes=2 * ENTRY_OVERHEAD_BYTES)

    for key in range(3):
        cache.put(key, b"")

    assert cache.get(0) is None
    assert cache.get(1) == b""
    assert cache.get(2) == b""
