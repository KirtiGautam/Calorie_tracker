from datetime import timedelta

from sqlmodel import Session

from app.auth import security
from app.auth.exceptions import InvalidCredentials, InvalidToken
from app.auth.schemas import TokenPair
from app.config import Settings
from app.users import service as users_service
from app.users.models import AppUser
from app.users.schemas import UserPublic


def issue_tokens(user: AppUser, settings: Settings) -> TokenPair:
    secret = settings.jwt_secret.get_secret_value()
    access_lifetime = timedelta(minutes=settings.access_token_minutes)
    return TokenPair(
        access_token=security.create_token(user.id, "access", access_lifetime, secret),
        refresh_token=security.create_token(
            user.id, "refresh", timedelta(days=settings.refresh_token_days), secret
        ),
        expires_in=int(access_lifetime.total_seconds()),
        user=UserPublic(id=user.id, email=user.email),
    )


def signup(
    session: Session, email: str, password: str, settings: Settings
) -> TokenPair:
    user = users_service.create(session, email, security.hash_password(password))
    return issue_tokens(user, settings)


def login(session: Session, email: str, password: str, settings: Settings) -> TokenPair:
    user = users_service.get_by_email(session, email)
    if user is None:
        # Spend the same time as a real check, so timing doesn't reveal which emails exist.
        security.verify_password(password, security.dummy_hash())
        raise InvalidCredentials("Incorrect email or password")
    if not security.verify_password(password, user.hashed_password):
        raise InvalidCredentials("Incorrect email or password")
    return issue_tokens(user, settings)


def refresh(session: Session, refresh_token: str, settings: Settings) -> TokenPair:
    """Exchanges a refresh token for a new pair. Tokens are stateless, so the old one stays valid until it expires."""
    user_id = security.decode_token(
        refresh_token, "refresh", settings.jwt_secret.get_secret_value()
    )
    user = session.get(AppUser, user_id)
    if user is None:
        raise InvalidToken("The account no longer exists")
    return issue_tokens(user, settings)
