from fastapi import status

from app.exceptions import AppError


class GoalNotFound(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    code = "goal_not_found"


class GoalOutdated(AppError):
    """The goal is older than the current one, and goals of past days can't change."""

    status_code = status.HTTP_409_CONFLICT
    code = "goal_outdated"


class InvalidGoalDate(AppError):
    """`effective_from` isn't the day `updated_at` falls on in any time zone."""

    status_code = status.HTTP_422_UNPROCESSABLE_CONTENT
    code = "invalid_goal_date"
