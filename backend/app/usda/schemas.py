import unicodedata
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, TypeAdapter, field_validator
from pydantic.alias_generators import to_camel

MAX_QUERY_LENGTH = 200
MAX_PAGE = 100
# The most IDs USDA's `foods` endpoint accepts in one request.
MAX_FOODS_PER_REQUEST = 20
MAX_FDC_ID = 2_147_483_647

FdcID = Annotated[int, Field(gt=0, le=MAX_FDC_ID)]


def normalize_query(query: str) -> str:
    """Returns the one form of `query` that's searched and cached.

    USDA's results don't depend on letter case or spacing, so these all count as the same search.
    Word order and plurals stay as typed because they can change the results.
    """
    return " ".join(unicodedata.normalize("NFKC", query).split()).casefold()


class USDASearchIn(BaseModel):
    """One page of a food search. `query` is normalized, so it's safe to use as a cache key."""

    query: str = Field(max_length=MAX_QUERY_LENGTH)
    page: int = Field(default=1, ge=1, le=MAX_PAGE)

    @field_validator("query")
    @classmethod
    def normalized_query(cls, query: str) -> str:
        normalized = normalize_query(query)
        # Normalizing can lengthen text, so the limit is checked again afterwards.
        if not 1 <= len(normalized) <= MAX_QUERY_LENGTH:
            raise ValueError(
                f"The query must have 1 to {MAX_QUERY_LENGTH} characters of text"
            )
        return normalized


class USDAFoodsIn(BaseModel):
    """The foods to look up. `fdc_ids` end up unique and sorted, so one set of IDs has one cache key."""

    fdc_ids: list[FdcID] = Field(min_length=1, max_length=MAX_FOODS_PER_REQUEST)

    @field_validator("fdc_ids")
    @classmethod
    def unique_sorted_ids(cls, fdc_ids: list[int]) -> list[int]:
        return sorted(set(fdc_ids))


class USDAResponseModel(BaseModel):
    """Part of a USDA response: USDA's camelCase names, limited to the fields the app reads."""

    model_config = ConfigDict(alias_generator=to_camel, extra="ignore")


class USDANutrient(USDAResponseModel):
    """One nutrient amount per 100 g.

    Search results use `nutrient_number` and `value`. The `foods` endpoint uses `number` and `amount`.
    """

    nutrient_number: str | None = None
    number: str | None = None
    unit_name: str | None = None
    value: float | None = None
    amount: float | None = None


class USDAFood(USDAResponseModel):
    fdc_id: int
    description: str | None = None
    brand_owner: str | None = None
    food_nutrients: list[USDANutrient] = Field(default_factory=list)


class USDASearchPage(USDAResponseModel):
    foods: list[USDAFood] = Field(default_factory=list)
    current_page: int | None = None
    total_pages: int | None = None


USDASearchPageAdapter = TypeAdapter(USDASearchPage)
USDAFoodsAdapter = TypeAdapter(list[USDAFood])
