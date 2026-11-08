import email.message
import logging
from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.routing import iter_route_contexts
from pydantic import BaseModel
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.routing import Match

logger = logging.getLogger(__name__)

# The parts of a Pydantic error that are safe to send back. `input` is left out because it echoes
# whatever was sent: a password, a body of any size, or a number like `inf` that JSON can't encode.
# `url` only links to Pydantic's docs.
VALIDATION_ERROR_FIELDS = ("type", "loc", "msg", "ctx")


class AppError(Exception):
    """Base for domain errors. Subclasses set an HTTP status and a stable code."""

    status_code: int = status.HTTP_400_BAD_REQUEST
    code: str = "bad_request"

    def __init__(
        self,
        message: str,
        details: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.details = details
        self.headers = headers


class ContentTooLarge(StarletteHTTPException):
    """The request body is over the size limit.

    It's an `HTTPException` rather than an `AppError` because FastAPI turns any other exception
    raised while it reads the body into a 400.
    """

    code = "content_too_large"

    def __init__(self) -> None:
        super().__init__(
            status.HTTP_413_CONTENT_TOO_LARGE, "The request body is too large"
        )


class ErrorBody(BaseModel):
    """The inner object of every error response."""

    code: str
    message: str
    details: Any = None


class ErrorEnvelope(BaseModel):
    """The shape of every error response, for the OpenAPI docs."""

    error: ErrorBody


def error_responses(*status_codes: int) -> dict[int | str, dict[str, Any]]:
    """OpenAPI `responses` entries that document the error envelope for each of `status_codes`."""
    return {status_code: {"model": ErrorEnvelope} for status_code in status_codes}


def error_response(
    status_code: int,
    code: str,
    message: str,
    details: Any = None,
    headers: dict[str, str] | None = None,
) -> JSONResponse:
    content = {"error": {"code": code, "message": message, "details": details}}
    return JSONResponse(status_code=status_code, content=content, headers=headers)


def is_json_media_type(content_type: str | None) -> bool:
    """Whether `content_type` is one FastAPI parses as JSON: `application/json` or `application/*+json`."""
    if not content_type:
        return False
    message = email.message.Message()
    message["content-type"] = content_type
    subtype = message.get_content_subtype()
    return message.get_content_maintype() == "application" and (
        subtype == "json" or subtype.endswith("+json")
    )


def safe_validation_errors(errors: Any) -> list[dict[str, Any]]:
    """Returns each validation error with only `VALIDATION_ERROR_FIELDS`, ready to encode as JSON."""
    return jsonable_encoder(
        [
            {key: error[key] for key in VALIDATION_ERROR_FIELDS if key in error}
            for error in errors
        ]
    )


def allowed_methods(request: Request) -> str:
    """Every method some route serves at the request's path, for a 405's `Allow` header.

    Starlette only lists the first matching route's methods, which is wrong when, as for `/me`, GET
    and DELETE are declared as separate routes.
    """
    methods: set[str] = set()
    # FastAPI 0.137 made `router.routes` a tree. This flattens it, with each route's full path.
    for route in iter_route_contexts(request.app.router.routes):
        match, _ = route.matches(request.scope)
        if match != Match.NONE and route.methods:
            methods |= route.methods
    return ", ".join(sorted(methods))


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def handle_app_error(request: Request, exc: AppError) -> JSONResponse:
        return error_response(
            exc.status_code, exc.code, exc.message, exc.details, exc.headers
        )

    @app.exception_handler(ContentTooLarge)
    async def handle_content_too_large(
        request: Request, exc: ContentTooLarge
    ) -> JSONResponse:
        return error_response(exc.status_code, exc.code, exc.detail)

    @app.exception_handler(StarletteHTTPException)
    async def handle_http_error(
        request: Request, exc: StarletteHTTPException
    ) -> JSONResponse:
        headers = dict(exc.headers) if exc.headers else {}
        if exc.status_code == status.HTTP_405_METHOD_NOT_ALLOWED:
            headers["Allow"] = allowed_methods(request)
        return error_response(
            exc.status_code, "http_error", str(exc.detail), headers=headers or None
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        errors = exc.errors()
        # FastAPI leaves a body it didn't parse as JSON as bytes, because its content type isn't JSON.
        if isinstance(exc.body, bytes) and exc.body:
            content_type = request.headers.get("content-type")
            if not is_json_media_type(content_type):
                return error_response(
                    status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                    "validation_error",
                    "The request body must be JSON, sent as application/json",
                )
        # Malformed syntax is a 400. 422 is for well-formed content that can't be processed.
        malformed = any(error.get("type") == "json_invalid" for error in errors)
        return error_response(
            status.HTTP_400_BAD_REQUEST
            if malformed
            else status.HTTP_422_UNPROCESSABLE_CONTENT,
            "validation_error",
            "The request body isn't valid JSON"
            if malformed
            else "Request validation failed",
            safe_validation_errors(errors),
        )

    @app.exception_handler(Exception)
    async def handle_unexpected(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled error on %s %s", request.method, request.url.path)
        return error_response(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            "internal_error",
            "Internal server error",
        )
