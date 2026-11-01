from fastapi import status

from app.exceptions import AppError


class TooManyFoods(AppError):
    status_code = status.HTTP_422_UNPROCESSABLE_CONTENT
    code = "too_many_foods"


class InvalidCursor(AppError):
    status_code = status.HTTP_422_UNPROCESSABLE_CONTENT
    code = "invalid_cursor"
