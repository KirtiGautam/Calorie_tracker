from fastapi import APIRouter, status

from app.auth import service
from app.auth.schemas import LoginRequest, RefreshRequest, SignupRequest, TokenPair
from app.config import SettingsDep
from app.database import SessionDep
from app.exceptions import ErrorEnvelope

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post(
    "/signup",
    summary="Create an account",
    status_code=status.HTTP_201_CREATED,
    responses={status.HTTP_409_CONFLICT: {"model": ErrorEnvelope}},
)
def signup(
    body: SignupRequest, session: SessionDep, settings: SettingsDep
) -> TokenPair:
    """Creates an account and signs it in. Returns 409 `email_taken` for a used email, in any letter case."""
    return service.signup(session, body.email, body.password, settings)


@router.post(
    "/login",
    summary="Sign in",
    responses={status.HTTP_401_UNAUTHORIZED: {"model": ErrorEnvelope}},
)
def login(body: LoginRequest, session: SessionDep, settings: SettingsDep) -> TokenPair:
    """Returns 401 `invalid_credentials` for a wrong password or an unknown email alike."""
    return service.login(session, body.email, body.password, settings)


@router.post(
    "/refresh",
    summary="Exchange a refresh token for a new pair",
    responses={status.HTTP_401_UNAUTHORIZED: {"model": ErrorEnvelope}},
)
def refresh(
    body: RefreshRequest, session: SessionDep, settings: SettingsDep
) -> TokenPair:
    return service.refresh(session, body.refresh_token, settings)
