import uuid

from sqlalchemy.exc import IntegrityError
from sqlmodel import Session, select

from app.users.exceptions import EmailTaken
from app.users.models import AppUser
from app.users.schemas import normalize_email


def get_by_email(session: Session, email: str) -> AppUser | None:
    return session.exec(
        select(AppUser).where(AppUser.email == normalize_email(email))
    ).first()


def create(session: Session, email: str, hashed_password: str) -> AppUser:
    """Creates an account, raising `EmailTaken` when the email is already in use."""
    email = normalize_email(email)
    if get_by_email(session, email) is not None:
        raise EmailTaken("An account with this email already exists")

    user = AppUser(email=email, hashed_password=hashed_password)
    session.add(user)
    try:
        session.commit()
    except IntegrityError as exc:
        # Another signup with the same email won the race between the check and the insert.
        session.rollback()
        raise EmailTaken("An account with this email already exists") from exc
    session.refresh(user)
    return user


def lock_account(session: Session, user_id: uuid.UUID) -> None:
    """Locks the account's row until the transaction ends, so one person's writes run one at a time."""
    session.exec(
        select(AppUser.id).where(AppUser.id == user_id).with_for_update()
    ).one()


def delete(session: Session, user: AppUser) -> None:
    """Deletes the account. The database cascades the delete to its goal and daily logs."""
    session.delete(user)
    session.commit()
