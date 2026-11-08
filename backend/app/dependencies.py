"""Dependencies that every domain can use."""

from typing import Annotated

import httpx
from fastapi import Depends, Request


async def get_http_client(request: Request) -> httpx.AsyncClient:
    """Returns the HTTP client the lifespan created for outbound calls."""
    return request.app.state.http_client


HTTPClientDep = Annotated[httpx.AsyncClient, Depends(get_http_client)]
