from fastapi import FastAPI
from fastapi.routing import APIRoute

from app.auth.router import router as auth_router
from app.config import get_settings
from app.daily_logs.router import router as daily_logs_router
from app.exceptions import register_exception_handlers
from app.goals.router import router as goals_router
from app.health.router import router as health_router
from app.middleware import BodySizeLimitMiddleware, CacheControlMiddleware
from app.users.router import router as users_router


def generate_unique_id(route: APIRoute) -> str:
    return f"{route.tags[0]}-{route.name}" if route.tags else route.name


settings = get_settings()
app = FastAPI(
    title="Gramwise API",
    openapi_url="/openapi.json" if settings.show_docs else None,
    generate_unique_id_function=generate_unique_id,
)
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
