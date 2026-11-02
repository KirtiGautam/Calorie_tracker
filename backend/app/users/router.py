from typing import Any

from fastapi import APIRouter, status

from app.auth.dependencies import CurrentUserDep
from app.database import SessionDep
from app.exceptions import error_responses
from app.users import service
from app.users.schemas import UserPublic

router = APIRouter(
    prefix="/me",
    tags=["users"],
    responses=error_responses(status.HTTP_401_UNAUTHORIZED),
)


@router.get("", summary="Read the signed-in account", response_model=UserPublic)
def read_me(user: CurrentUserDep) -> Any:
    return user


@router.delete(
    "", summary="Delete the signed-in account", status_code=status.HTTP_204_NO_CONTENT
)
def delete_me(user: CurrentUserDep, session: SessionDep) -> None:
    """Deletes the account with its goal and every daily log. This can't be undone."""
    service.delete(session, user)
