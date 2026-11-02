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


def user_for_token(
    session: Session, token: str, token_type: security.TokenType, settings: Settings
) -> AppUser:
    """Returns the account named by a valid `token_type` token, or raises `InvalidToken`."""
    user_id = security.decode_token(
        token, token_type, settings.jwt_secret.get_secret_value()
    )
    user = session.get(AppUser, user_id)
    if user is None:
        raise InvalidToken("The account no longer exists")
    return user


def signup(
    session: Session, email: str, password: str, settings: Settings
) -> TokenPair:
    user = users_service.create(session, email, security.hash_password(password))
    return issue_tokens(user, settings)


def login(session: Session, email: str, password: str, settings: Settings) -> TokenPair:
    user = users_service.get_by_email(session, email)
    # An unknown email is checked against a dummy hash, so timing doesn't reveal which emails exist.
    hashed = user.hashed_password if user is not None else security.dummy_hash()
    verified = security.verify_password(password, hashed)
    if user is None or not verified:
        raise InvalidCredentials("Incorrect email or password")
    return issue_tokens(user, settings)


def refresh(session: Session, refresh_token: str, settings: Settings) -> TokenPair:
    """Exchanges a refresh token for a new pair. Tokens are stateless, so the old one stays valid until it expires."""
    user = user_for_token(session, refresh_token, "refresh", settings)
    return issue_tokens(user, settings)
