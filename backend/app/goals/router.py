from typing import Any

from fastapi import APIRouter, Response, status

from app.auth.dependencies import CurrentUserDep
from app.database import SessionDep
from app.exceptions import error_responses
from app.goals import service
from app.goals.schemas import GoalIn, GoalPublic

router = APIRouter(
    prefix="/me/goal",
    tags=["goals"],
    responses=error_responses(status.HTTP_401_UNAUTHORIZED),
)


@router.get(
    "",
    summary="Read the current goal",
    response_model=GoalPublic,
    responses=error_responses(status.HTTP_404_NOT_FOUND),
)
def read_goal(user: CurrentUserDep, session: SessionDep) -> Any:
    """Returns the goal with the latest `effective_from`."""
    return service.get(session, user.id)


@router.put(
    "",
    summary="Save the goal for a day",
    response_model=GoalPublic,
    responses={
        status.HTTP_201_CREATED: {
            "model": GoalPublic,
            "description": "The account's first goal was saved",
        },
        **error_responses(
            status.HTTP_409_CONFLICT, status.HTTP_422_UNPROCESSABLE_CONTENT
        ),
    },
)
def put_goal(
    goal_in: GoalIn, user: CurrentUserDep, session: SessionDep, response: Response
) -> Any:
    """Saves the goal from `effective_from` on and returns it, with 201 when it's the first.

    A later day adds a row and keeps the earlier days' goals. The same day replaces that day's goal
    when `updated_at` is newer. An older goal returns 409 `goal_outdated`. An `updated_at` more than
    5 minutes ahead of the server's clock returns 422 `invalid_goal_date`.
    """
    goal, created = service.put(session, user.id, goal_in)
    if created:
        response.status_code = status.HTTP_201_CREATED
    return goal
