from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.routing import APIRoute

from app.auth.router import router as auth_router
from app.cache import ResponseCache
from app.config import get_settings
from app.daily_logs.router import router as daily_logs_router
from app.exceptions import register_exception_handlers
from app.goals.router import router as goals_router
from app.health.router import router as health_router
from app.middleware import BodySizeLimitMiddleware, CacheControlMiddleware
from app.outbound import make_http_client
from app.rate_limit import ClientRateLimiter
from app.usda.router import router as usda_router
from app.users.router import router as users_router

settings = get_settings()


def generate_unique_id(route: APIRoute) -> str:
    return f"{route.tags[0]}-{route.name}" if route.tags else route.name


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None]:
    async with make_http_client() as http_client:
        app.state.http_client = http_client
        app.state.usda_cache = ResponseCache()
        app.state.usda_rate_limiter = ClientRateLimiter(
            settings.usda_rate_limit_per_hour
        )
        yield


app = FastAPI(
    title="Gramwise API",
    lifespan=lifespan,
    openapi_url="/openapi.json" if settings.show_docs else None,
    generate_unique_id_function=generate_unique_id,
)
# USDA responses are about 14 times smaller compressed, which matters on a phone connection.
app.add_middleware(GZipMiddleware, minimum_size=1000)
# Added last so they run first: an oversized body is refused before anything reads it, and even that
# refusal is marked `no-store`.
app.add_middleware(BodySizeLimitMiddleware)
app.add_middleware(CacheControlMiddleware)
register_exception_handlers(app)
app.include_router(health_router)
app.include_router(auth_router)
app.include_router(users_router)
app.include_router(goals_router)
app.include_router(daily_logs_router)
app.include_router(usda_router)
