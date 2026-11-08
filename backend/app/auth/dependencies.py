from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.auth import service
from app.auth.exceptions import InvalidToken
from app.config import SettingsDep
from app.database import SessionDep
from app.users.models import AppUser

# auto_error=False so a missing header gets our envelope and code instead of FastAPI's default.
bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    session: SessionDep,
    settings: SettingsDep,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> AppUser:
    """Loads the account named by the bearer access token."""
    if credentials is None:
        raise InvalidToken("Missing bearer token", token_sent=False)
    return service.user_for_token(session, credentials.credentials, "access", settings)


CurrentUserDep = Annotated[AppUser, Depends(get_current_user)]
