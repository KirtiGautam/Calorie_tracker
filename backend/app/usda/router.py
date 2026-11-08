from fastapi import APIRouter, Depends, Response, status

from app.cache import cached_json
from app.exceptions import error_responses
from app.rate_limit import limit_by_client
from app.usda.dependencies import ResponseCacheDep, USDAClientDep
from app.usda.schemas import USDAFood, USDAFoodsIn, USDASearchIn, USDASearchPage

# Public on purpose: food search works without an account, so these routes take no bearer token
# and don't touch the database. Clients can only send a query, a page or IDs, so this is no
# general relay to USDA.
router = APIRouter(
    prefix="/usda",
    tags=["usda"],
    dependencies=[Depends(limit_by_client("usda_rate_limiter"))],
    responses=error_responses(
        status.HTTP_429_TOO_MANY_REQUESTS,
        status.HTTP_502_BAD_GATEWAY,
        status.HTTP_503_SERVICE_UNAVAILABLE,
        status.HTTP_504_GATEWAY_TIMEOUT,
    ),
)


@router.post(
    "/foods/search",
    summary="Search USDA whole foods",
    responses={status.HTTP_200_OK: {"model": USDASearchPage}},
)
async def search_foods(
    search: USDASearchIn, client: USDAClientDep, cache: ResponseCacheDep
) -> Response:
    """Returns one page of matching foods, using USDA's field names, limited to the ones the app reads.

    Searches that differ only in letter case or spacing share a cached answer.
    """
    return await cached_json(
        cache,
        ("search", search.query, search.page),
        lambda: client.search(search.query, search.page),
    )


@router.post(
    "/foods",
    summary="Look up USDA foods by ID",
    responses={status.HTTP_200_OK: {"model": list[USDAFood]}},
)
async def look_up_foods(
    foods: USDAFoodsIn, client: USDAClientDep, cache: ResponseCacheDep
) -> Response:
    """Returns the foods with these IDs. IDs USDA doesn't know are left out."""
    return await cached_json(
        cache,
        ("foods", tuple(foods.fdc_ids)),
        lambda: client.foods(foods.fdc_ids),
    )
