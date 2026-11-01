from fastapi import status

from app.exceptions import AppError


class DatabaseUnavailable(AppError):
    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    code = "database_unavailable"
