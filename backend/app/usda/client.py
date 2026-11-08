import logging
from typing import Any

import httpx
from pydantic import SecretStr, TypeAdapter, ValidationError

from app.outbound import JSONAPIClient
from app.usda.exceptions import USDARateLimited, USDATimeout, USDAUnavailable
from app.usda.schemas import USDAFoodsAdapter, USDASearchPageAdapter

logger = logging.getLogger(__name__)

# Branded foods are excluded because the app gets those from Open Food Facts.
DATA_TYPES = ("Foundation", "SR Legacy", "Survey (FNDDS)")
PAGE_SIZE = 20
# Going over the limit blocks the key for an hour, for everyone, so this warns well before that.
LOW_QUOTA_FRACTION = 0.1
# How long USDA blocks a key that went over its limit.
BLOCK_SECONDS = 60 * 60


class USDAClient(JSONAPIClient):
    """Calls USDA FoodData Central with the backend's API key.

    The key goes in a header, never the URL, so it can't reach a log line that prints the URL.
    `JSONAPIClient` doesn't follow redirects, so it can't reach another host either.
    """

    service_name = "USDA"
    base_url = "https://api.nal.usda.gov/fdc/v1"
    timeout_error = USDATimeout
    unavailable_error = USDAUnavailable
    rate_limited_error = USDARateLimited
    default_retry_after_seconds = BLOCK_SECONDS

    def __init__(self, http_client: httpx.AsyncClient, api_key: SecretStr) -> None:
        super().__init__(http_client)
        self._api_key = api_key

    def request_headers(self) -> dict[str, str]:
        return {"X-Api-Key": self._api_key.get_secret_value()}

    def on_response(self, response: httpx.Response) -> None:
        _warn_if_quota_is_low(response)

    async def search(self, query: str, page: int) -> bytes:
        """Returns one page of whole foods as JSON, limited to the fields the app reads."""
        data = await self.post(
            "foods/search",
            {
                "query": query,
                "dataType": DATA_TYPES,
                "pageSize": PAGE_SIZE,
                "pageNumber": page,
            },
        )
        return _trimmed(USDASearchPageAdapter, data)

    async def foods(self, fdc_ids: list[int]) -> bytes:
        """Returns the foods with these IDs as JSON. IDs USDA doesn't know are left out."""
        data = await self.post("foods", {"fdcIds": fdc_ids, "format": "abridged"})
        return _trimmed(USDAFoodsAdapter, data)


def _warn_if_quota_is_low(response: httpx.Response) -> None:
    """Logs a warning when USDA's rate limit headers show the key's quota is nearly used up."""
    try:
        limit = int(response.headers["X-RateLimit-Limit"])
        remaining = int(response.headers["X-RateLimit-Remaining"])
    except KeyError, ValueError:
        return
    if remaining < limit * LOW_QUOTA_FRACTION:
        logger.warning("USDA quota is low: %d of %d requests left", remaining, limit)


def _trimmed(adapter: TypeAdapter[Any], data: bytes) -> bytes:
    """Returns `data` without the fields the app doesn't read.

    Raises `USDAUnavailable` when `data` isn't in the shape USDA documents, so it's never cached.
    """
    try:
        return adapter.dump_json(
            adapter.validate_json(data), by_alias=True, exclude_none=True
        )
    except ValidationError as exc:
        logger.warning("USDA sent a response in an unexpected shape")
        raise USDAUnavailable("USDA sent an unexpected response") from exc
