from typing import Annotated, Any

from fastapi import APIRouter, Query, status

from app.auth.dependencies import CurrentUserDep
from app.daily_logs import service
from app.daily_logs.schemas import ChangedDays, DailyLogPage, LogChanges
from app.database import SessionDep
from app.exceptions import ErrorEnvelope

router = APIRouter(
    prefix="/daily-logs",
    tags=["daily-logs"],
    responses={
        status.HTTP_401_UNAUTHORIZED: {"model": ErrorEnvelope},
        status.HTTP_422_UNPROCESSABLE_CONTENT: {"model": ErrorEnvelope},
    },
)


@router.post(
    "/changes", summary="Add and remove logged foods", response_model=ChangedDays
)
def post_changes(changes: LogChanges, user: CurrentUserDep, session: SessionDep) -> Any:
    """Merges the changes into each day by `entry_id`, recomputes the totals and returns the touched days.

    Sending the same changes twice gives the same result.
    """
    return {"days": service.apply_changes(session, user.id, changes)}


@router.get("", summary="List days changed since a cursor", response_model=DailyLogPage)
def list_daily_logs(
    user: CurrentUserDep,
    session: SessionDep,
    cursor: Annotated[str | None, Query(max_length=200)] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 100,
) -> Any:
    """Without a cursor, starts from the oldest change. Pass `next_cursor` back while `has_more` is true,
    and store the last one to fetch only newer changes next time."""
    days, next_cursor, has_more = service.list_changed(session, user.id, cursor, limit)
    return {"days": days, "next_cursor": next_cursor, "has_more": has_more}
