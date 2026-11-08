import json
import logging
from collections.abc import AsyncIterator
from typing import Any

import httpx
import pytest
from fastapi.testclient import TestClient

from app.dependencies import get_http_client
from app.main import app
from app.rate_limit import ClientRateLimiter

API_KEY = "test-usda-key"
SEARCH_RESPONSE: dict[str, Any] = {
    "totalHits": 40,
    "currentPage": 1,
    "totalPages": 2,
    "pageList": [1, 2],
    "aggregations": {"dataType": {"SR Legacy": 40}},
    "foods": [
        {
            "fdcId": 173944,
            "description": "Bananas, raw",
            "dataType": "SR Legacy",
            "score": 512.5,
            "foodNutrients": [
                {
                    "nutrientId": 1008,
                    "nutrientName": "Energy",
                    "nutrientNumber": "208",
                    "unitName": "KCAL",
                    "value": 89.0,
                    "rank": 300,
                }
            ],
        }
    ],
}
FOODS_RESPONSE = [
    {
        "fdcId": 173944,
        "description": "Bananas, raw",
        "dataType": "SR Legacy",
        "publicationDate": "4/1/2019",
        "foodNutrients": [
            {"number": "208", "name": "Energy", "amount": 89.0, "unitName": "KCAL"}
        ],
    }
]


class FakeUSDA:
    """Stands in for USDA's servers and records every request it receives."""

    def __init__(self) -> None:
        self.answer: httpx.Response | Exception = httpx.Response(
            200, json=SEARCH_RESPONSE
        )
        self.requests: list[httpx.Request] = []

    def handle(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        if isinstance(self.answer, Exception):
            raise self.answer
        return self.answer

    @property
    def last_body(self) -> dict[str, Any]:
        return json.loads(self.requests[-1].content)


@pytest.fixture
def usda(client: TestClient) -> FakeUSDA:
    fake = FakeUSDA()

    async def fake_http_client() -> AsyncIterator[httpx.AsyncClient]:
        async with httpx.AsyncClient(transport=httpx.MockTransport(fake.handle)) as c:
            yield c

    app.dependency_overrides[get_http_client] = fake_http_client
    return fake


def search(client: TestClient, query: str = "banana", page: int = 1) -> Any:
    return client.post("/usda/foods/search", json={"query": query, "page": page})


def test_search_needs_no_account_and_sends_fixed_criteria(
    client: TestClient, usda: FakeUSDA
) -> None:
    response = search(client, "banana", page=3)

    assert response.status_code == 200
    request = usda.requests[0]
    assert request.method == "POST"
    assert str(request.url) == "https://api.nal.usda.gov/fdc/v1/foods/search"
    assert usda.last_body == {
        "query": "banana",
        "dataType": ["Foundation", "SR Legacy", "Survey (FNDDS)"],
        "pageSize": 20,
        "pageNumber": 3,
    }


def test_search_keeps_only_the_fields_the_app_reads(
    client: TestClient, usda: FakeUSDA
) -> None:
    response = search(client)

    assert response.headers["content-type"] == "application/json"
    assert response.json() == {
        "currentPage": 1,
        "totalPages": 2,
        "foods": [
            {
                "fdcId": 173944,
                "description": "Bananas, raw",
                "foodNutrients": [
                    {"nutrientNumber": "208", "unitName": "KCAL", "value": 89.0}
                ],
            }
        ],
    }


def test_search_keeps_the_brand_when_there_is_one(
    client: TestClient, usda: FakeUSDA
) -> None:
    usda.answer = httpx.Response(
        200, json={"foods": [{"fdcId": 1, "brandOwner": "Acme"}]}
    )

    assert search(client).json()["foods"][0]["brandOwner"] == "Acme"


def test_the_key_goes_in_a_header_and_nowhere_else(
    client: TestClient, usda: FakeUSDA, caplog: pytest.LogCaptureFixture
) -> None:
    usda.answer = httpx.Response(403, json={"error": {"code": "API_KEY_INVALID"}})

    with caplog.at_level(logging.DEBUG):
        response = search(client)

    request = usda.requests[0]
    assert request.headers["X-Api-Key"] == API_KEY
    assert API_KEY not in str(request.url)
    assert API_KEY.encode() not in request.content
    assert API_KEY not in response.text
    assert API_KEY not in caplog.text
    assert "banana" not in caplog.text


def test_foods_asks_for_the_abridged_format_with_sorted_unique_ids(
    client: TestClient, usda: FakeUSDA
) -> None:
    usda.answer = httpx.Response(200, json=FOODS_RESPONSE)

    response = client.post("/usda/foods", json={"fdc_ids": [9, 173944, 9]})

    assert response.status_code == 200
    assert str(usda.requests[0].url) == "https://api.nal.usda.gov/fdc/v1/foods"
    assert usda.last_body == {"fdcIds": [9, 173944], "format": "abridged"}
    assert response.json() == [
        {
            "fdcId": 173944,
            "description": "Bananas, raw",
            "foodNutrients": [{"number": "208", "unitName": "KCAL", "amount": 89.0}],
        }
    ]


@pytest.mark.parametrize(
    "body",
    [
        {"query": ""},
        {"query": "   "},
        {"query": "x" * 201},
        {"query": "ﷺ" * 12},  # 12 characters that normalize to 216
        {"query": "banana", "page": 0},
        {"query": "banana", "page": 101},
        {"page": 1},
    ],
)
def test_search_rejects_bad_input_without_calling_usda(
    client: TestClient, usda: FakeUSDA, body: dict[str, Any]
) -> None:
    response = client.post("/usda/foods/search", json=body)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
    assert usda.requests == []


@pytest.mark.parametrize(
    "fdc_ids", [[], [0], [-1], [2_147_483_648], list(range(1, 22))]
)
def test_foods_rejects_bad_input_without_calling_usda(
    client: TestClient, usda: FakeUSDA, fdc_ids: list[int]
) -> None:
    response = client.post("/usda/foods", json={"fdc_ids": fdc_ids})

    assert response.status_code == 422
    assert usda.requests == []


@pytest.mark.parametrize(
    ("answer", "status_code", "code"),
    [
        (httpx.Response(429), 503, "usda_rate_limited"),
        (httpx.Response(500), 502, "usda_unavailable"),
        (httpx.Response(200, text="not json"), 502, "usda_unavailable"),
        (httpx.Response(200, json={"foods": [{"no": "id"}]}), 502, "usda_unavailable"),
        (httpx.ConnectError("no route"), 502, "usda_unavailable"),
        (httpx.ReadTimeout("too slow"), 504, "usda_timeout"),
    ],
)
def test_usda_failures_map_to_stable_codes_and_are_never_cached(
    client: TestClient,
    usda: FakeUSDA,
    answer: httpx.Response | Exception,
    status_code: int,
    code: str,
) -> None:
    usda.answer = answer

    response = search(client)
    usda.answer = httpx.Response(200, json=SEARCH_RESPONSE)
    retried = search(client)

    assert response.status_code == status_code
    assert response.json()["error"]["code"] == code
    assert retried.status_code == 200
    assert len(usda.requests) == 2


@pytest.mark.parametrize(
    "similar", ["BANANA  RAW", "  banana raw  ", "Banana\tRaw", "ｂａｎａｎａ raw"]
)
def test_similar_searches_share_a_cached_answer(
    client: TestClient, usda: FakeUSDA, similar: str
) -> None:
    first = search(client, "banana raw")
    second = search(client, similar)

    assert first.headers["Cache-Status"] == "gramwise; fwd=uri-miss"
    assert second.headers["Cache-Status"] == "gramwise; hit"
    assert second.json() == first.json()
    assert len(usda.requests) == 1
    assert usda.last_body["query"] == "banana raw"


def test_different_words_and_pages_are_cached_separately(
    client: TestClient, usda: FakeUSDA
) -> None:
    search(client, "raw banana")
    search(client, "banana raw")
    search(client, "banana raw", page=2)

    assert len(usda.requests) == 3


def test_foods_are_cached_by_their_set_of_ids(
    client: TestClient, usda: FakeUSDA
) -> None:
    usda.answer = httpx.Response(200, json=FOODS_RESPONSE)

    client.post("/usda/foods", json={"fdc_ids": [1, 2]})
    second = client.post("/usda/foods", json={"fdc_ids": [2, 1]})
    client.post("/usda/foods", json={"fdc_ids": [1, 3]})

    assert second.headers["Cache-Status"] == "gramwise; hit"
    assert len(usda.requests) == 2


def test_a_search_with_no_results_is_cached(client: TestClient, usda: FakeUSDA) -> None:
    usda.answer = httpx.Response(200, json={"foods": []})

    search(client, "xyzzy")
    second = search(client, "xyzzy")

    assert second.headers["Cache-Status"] == "gramwise; hit"
    assert second.json() == {"foods": []}


def test_clients_over_their_limit_are_refused_without_calling_usda(
    client: TestClient, usda: FakeUSDA
) -> None:
    app.state.usda_rate_limiter = ClientRateLimiter(limit=2)
    search(client, "first")
    search(client, "first")

    response = search(client, "second")

    assert response.status_code == 429
    assert response.json()["error"]["code"] == "rate_limited"
    assert int(response.headers["Retry-After"]) > 0
    assert len(usda.requests) == 1


def test_low_usda_quota_logs_a_warning(
    client: TestClient, usda: FakeUSDA, caplog: pytest.LogCaptureFixture
) -> None:
    usda.answer = httpx.Response(
        200,
        json=SEARCH_RESPONSE,
        headers={"X-RateLimit-Limit": "1000", "X-RateLimit-Remaining": "99"},
    )

    search(client)

    assert "USDA quota is low: 99 of 1000" in caplog.text


@pytest.mark.parametrize(
    "headers",
    [
        {"X-RateLimit-Limit": "1000", "X-RateLimit-Remaining": "100"},
        {"X-RateLimit-Limit": "unknown", "X-RateLimit-Remaining": "0"},
        {},
    ],
)
def test_healthy_or_missing_quota_logs_nothing(
    client: TestClient,
    usda: FakeUSDA,
    caplog: pytest.LogCaptureFixture,
    headers: dict[str, str],
) -> None:
    usda.answer = httpx.Response(200, json=SEARCH_RESPONSE, headers=headers)

    search(client)

    assert "USDA quota" not in caplog.text


def test_large_responses_are_compressed(client: TestClient, usda: FakeUSDA) -> None:
    food = SEARCH_RESPONSE["foods"][0]
    usda.answer = httpx.Response(200, json={"foods": [food] * 50})

    response = client.post(
        "/usda/foods/search",
        json={"query": "banana"},
        headers={"Accept-Encoding": "gzip"},
    )

    assert response.headers["Content-Encoding"] == "gzip"
    assert len(response.json()["foods"]) == 50


@pytest.mark.parametrize(
    ("usda_retry_after", "retry_after"),
    [(None, "3600"), ("120", "120"), ("soon", "3600")],
)
def test_usda_blocking_the_key_is_a_503_with_retry_after(
    client: TestClient,
    usda: FakeUSDA,
    usda_retry_after: str | None,
    retry_after: str,
) -> None:
    headers = {"Retry-After": usda_retry_after} if usda_retry_after else {}
    usda.answer = httpx.Response(429, headers=headers)

    response = search(client)

    # Every user shares the key, so this isn't the client sending too many requests.
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "usda_rate_limited"
    assert response.headers["Retry-After"] == retry_after


def test_usda_answers_may_be_cached_by_clients(
    client: TestClient, usda: FakeUSDA
) -> None:
    response = search(client)

    assert "Cache-Control" not in response.headers


@pytest.mark.parametrize(
    ("path", "body"),
    [
        ("/usda/foods", '{"fdc_ids": [Infinity]}'),
        ("/usda/foods", '{"fdc_ids": [NaN]}'),
        ("/usda/foods/search", '{"query": "x", "page": 1e400}'),
    ],
)
def test_non_finite_numbers_are_a_422_without_calling_usda(
    client: TestClient, usda: FakeUSDA, path: str, body: str
) -> None:
    response = client.post(
        path, content=body, headers={"Content-Type": "application/json"}
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
    assert usda.requests == []
