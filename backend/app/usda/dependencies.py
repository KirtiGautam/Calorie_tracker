from typing import Annotated

from fastapi import Depends, Request

from app.cache import ResponseCache
from app.config import SettingsDep
from app.dependencies import HTTPClientDep
from app.usda.client import USDAClient


async def get_usda_client(
    http_client: HTTPClientDep, settings: SettingsDep
) -> USDAClient:
    return USDAClient(http_client, settings.usda_api_key)


USDAClientDep = Annotated[USDAClient, Depends(get_usda_client)]


async def get_response_cache(request: Request) -> ResponseCache:
    return request.app.state.usda_cache


ResponseCacheDep = Annotated[ResponseCache, Depends(get_response_cache)]
