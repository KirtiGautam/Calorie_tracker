from fastapi import status

from app.exceptions import AppError


class EmailTaken(AppError):
    status_code = status.HTTP_409_CONFLICT
    code = "email_taken"
