import logging
import uuid
from datetime import UTC, datetime, timedelta

from sqlmodel import Session, col, update

from app.auth import security
from app.auth.exceptions import InvalidCredentials, InvalidRefreshToken, InvalidToken
from app.auth.models import RefreshToken
from app.auth.schemas import TokenPair
from app.config import Settings
from app.users import service as users_service
from app.users.models import AppUser
from app.users.schemas import UserPublic

logger = logging.getLogger(__name__)

# A used refresh token that comes back within this long gets a new pair instead of revoking its
# family. It covers two requests from one device racing to refresh, where the loser would otherwise
# sign the person out. A thief replaying a token later than this is still caught.
REUSE_GRACE = timedelta(seconds=60)


def issue_tokens(
    session: Session,
    user: AppUser,
    settings: Settings,
    family_id: uuid.UUID | None = None,
    now: datetime | None = None,
) -> TokenPair:
    """Signs a new pair and records the refresh token, in `family_id` or in a new family.

    Commits the session. Expired refresh tokens are deleted by a daily job in the database
    (migration 0004), not here.
    """
    now = now or datetime.now(UTC)
    family_id = family_id or uuid.uuid4()
    secret = settings.jwt_secret.get_secret_value()
    access_lifetime = timedelta(minutes=settings.access_token_minutes)
    refresh_lifetime = timedelta(days=settings.refresh_token_days)
    jti = security.new_token_id()

    pair = TokenPair(
        access_token=security.create_token(
            user.id, "access", access_lifetime, secret, now
        ),
        refresh_token=security.create_token(
            user.id, "refresh", refresh_lifetime, secret, now, jti, family_id
        ),
        expires_in=int(access_lifetime.total_seconds()),
        user=UserPublic(id=user.id, email=user.email),
    )
    session.add(
        RefreshToken(
            jti=jti,
            family_id=family_id,
            user_id=user.id,
            issued_at=now,
            expires_at=now + refresh_lifetime,
        )
    )
    session.commit()
    return pair


def user_for_token(
    session: Session, token: str, token_type: security.TokenType, settings: Settings
) -> AppUser:
    """Returns the account named by a valid `token_type` token, or raises `InvalidToken`."""
    claims = security.decode_token(
        token, token_type, settings.jwt_secret.get_secret_value()
    )
    user = session.get(AppUser, claims.user_id)
    if user is None:
        raise InvalidToken("The account no longer exists")
    return user


def signup(
    session: Session, email: str, password: str, settings: Settings
) -> TokenPair:
    user = users_service.create(session, email, security.hash_password(password))
    return issue_tokens(session, user, settings)


def login(session: Session, email: str, password: str, settings: Settings) -> TokenPair:
    user = users_service.get_by_email(session, email)
    # An unknown email is checked against a dummy hash, so timing doesn't reveal which emails exist.
    hashed = user.hashed_password if user is not None else security.dummy_hash()
    verified = security.verify_password(password, hashed)
    if user is None or not verified:
        raise InvalidCredentials("Incorrect email or password")
    return issue_tokens(session, user, settings)


def refresh(
    session: Session,
    refresh_token: str,
    settings: Settings,
    now: datetime | None = None,
) -> TokenPair:
    """Exchanges a refresh token for a new pair, and marks it used.

    Raises `InvalidRefreshToken` for a token that's invalid, revoked, or already used. A token used
    more than `REUSE_GRACE` ago revokes its whole family, because either it or the token it was
    exchanged for is in someone else's hands. `now` is the current UTC time, which tests may pin.
    """
    now = now or datetime.now(UTC)
    claims = _refresh_claims(refresh_token, settings)
    user = session.get(AppUser, claims.user_id)
    if user is None or claims.jti is None:
        raise InvalidRefreshToken("Invalid or expired token")
    # Serializes one account's refreshes, so two can't both exchange the same token.
    users_service.lock_account(session, user.id)
    stored = session.get(RefreshToken, claims.jti)

    if stored is None:
        if claims.family_id is not None:
            # Issued with a family, so it was recorded. It's gone with its account or expired.
            raise InvalidRefreshToken("Invalid or expired token")
        # Issued before refresh tokens were stored. It becomes the first, used token of a family,
        # so presenting it again is caught like any other reuse.
        stored = RefreshToken(
            jti=claims.jti,
            family_id=uuid.uuid4(),
            user_id=user.id,
            issued_at=now,
            expires_at=claims.expires_at,
            used_at=now,
        )
        session.add(stored)
        return issue_tokens(session, user, settings, stored.family_id, now)

    if stored.user_id != user.id or stored.revoked_at is not None:
        raise InvalidRefreshToken("This session was signed out")
    if stored.used_at is not None:
        if now - stored.used_at <= REUSE_GRACE:
            return issue_tokens(session, user, settings, stored.family_id, now)
        revoke_family(session, stored.family_id, now)
        session.commit()
        logger.warning(
            "A used refresh token was presented again. Revoked its family for user %s",
            user.id,
        )
        raise InvalidRefreshToken(
            "This refresh token was already used, so its session was signed out"
        )

    stored.used_at = now
    return issue_tokens(session, user, settings, stored.family_id, now)


def logout(
    session: Session,
    refresh_token: str,
    settings: Settings,
    now: datetime | None = None,
) -> None:
    """Revokes the refresh token's family, so neither it nor any token it led to can be used again.

    Like RFC 7009 §2.2, a token that's already invalid isn't an error: there's nothing left to
    revoke. Access tokens already issued stay valid until they expire.
    """
    now = now or datetime.now(UTC)
    try:
        claims = _refresh_claims(refresh_token, settings)
    except InvalidRefreshToken:
        return
    if claims.jti is None or session.get(AppUser, claims.user_id) is None:
        return
    users_service.lock_account(session, claims.user_id)
    stored = session.get(RefreshToken, claims.jti)
    if stored is not None:
        revoke_family(session, stored.family_id, now)
    elif claims.family_id is None:
        # Issued before refresh tokens were stored: record it as revoked.
        session.add(
            RefreshToken(
                jti=claims.jti,
                family_id=uuid.uuid4(),
                user_id=claims.user_id,
                issued_at=now,
                expires_at=claims.expires_at,
                used_at=now,
                revoked_at=now,
            )
        )
    session.commit()


def revoke_family(session: Session, family_id: uuid.UUID, now: datetime) -> None:
    """Marks every token in `family_id` revoked. The caller commits."""
    session.exec(
        update(RefreshToken)
        .where(
            col(RefreshToken.family_id) == family_id,
            col(RefreshToken.revoked_at).is_(None),
        )
        .values(revoked_at=now)
    )


def _refresh_claims(refresh_token: str, settings: Settings) -> security.TokenClaims:
    """Decodes a refresh token from a request body, raising `InvalidRefreshToken` rather than a 401."""
    try:
        return security.decode_token(
            refresh_token, "refresh", settings.jwt_secret.get_secret_value()
        )
    except InvalidToken as exc:
        raise InvalidRefreshToken(exc.message) from exc
