from fastapi import APIRouter, status
from sqlalchemy import exc as sa_exc
from sqlalchemy import text

from app.database import SessionDep
from app.exceptions import error_responses
from app.health.exceptions import DatabaseUnavailable
from app.health.schemas import HealthStatus

router = APIRouter(prefix="/health", tags=["health"])


# HEAD too, because uptime checkers often probe with it (RFC 9110 §9.1). FastAPI, unlike Starlette,
# doesn't add HEAD to GET routes. It's left out of the schema so the operation isn't listed twice.
@router.get("", summary="Liveness check")
@router.head("", include_in_schema=False)
async def liveness() -> HealthStatus:
    """Returns 200 while the process can serve requests. Touches nothing else."""
    return HealthStatus()


@router.get(
    "/ready",
    summary="Readiness check",
    responses=error_responses(status.HTTP_503_SERVICE_UNAVAILABLE),
)
@router.head("/ready", include_in_schema=False)
def readiness(session: SessionDep) -> HealthStatus:
    """Returns 200 when the database answers a trivial query, otherwise 503."""
    try:
        session.connection().execute(text("SELECT 1"))
    except (sa_exc.OperationalError, sa_exc.TimeoutError) as exc:
        raise DatabaseUnavailable("Database is unreachable") from exc
    return HealthStatus()
