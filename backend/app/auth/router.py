from fastapi import APIRouter, Response, status

from app.auth import service
from app.auth.schemas import LoginRequest, RefreshRequest, SignupRequest, TokenPair
from app.config import SettingsDep
from app.database import SessionDep
from app.exceptions import error_responses

router = APIRouter(
    prefix="/auth",
    tags=["auth"],
    responses=error_responses(status.HTTP_422_UNPROCESSABLE_CONTENT),
)


@router.post(
    "/signup",
    summary="Create an account",
    status_code=status.HTTP_201_CREATED,
    responses=error_responses(status.HTTP_409_CONFLICT),
)
def signup(
    body: SignupRequest, session: SessionDep, settings: SettingsDep, response: Response
) -> TokenPair:
    """Creates an account and signs it in. Returns 409 `email_taken` for a used email, in any letter case."""
    tokens = service.signup(session, body.email, body.password, settings)
    # The account just created, which the new access token reads at /me.
    response.headers["Location"] = "/me"
    return tokens


@router.post(
    "/login",
    summary="Sign in",
    responses=error_responses(status.HTTP_400_BAD_REQUEST),
)
def login(body: LoginRequest, session: SessionDep, settings: SettingsDep) -> TokenPair:
    """Returns 400 `invalid_credentials` for a wrong password or an unknown email alike."""
    return service.login(session, body.email, body.password, settings)


@router.post(
    "/refresh",
    summary="Exchange a refresh token for a new pair",
    responses=error_responses(status.HTTP_400_BAD_REQUEST),
)
def refresh(
    body: RefreshRequest, session: SessionDep, settings: SettingsDep
) -> TokenPair:
    """Each refresh token works once. Returns 400 `invalid_token` for one that's invalid, expired, revoked or used.

    Presenting a used token again signs out every device that sign-in led to.
    """
    return service.refresh(session, body.refresh_token, settings)


@router.post(
    "/logout",
    summary="Sign out a refresh token",
    status_code=status.HTTP_204_NO_CONTENT,
)
def logout(body: RefreshRequest, session: SessionDep, settings: SettingsDep) -> None:
    """Revokes the refresh token and every token it led to. Access tokens already issued last until they expire.

    Returns 204 for an invalid or already revoked token too, since there's nothing left to revoke.
    """
    service.logout(session, body.refresh_token, settings)
