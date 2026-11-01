from sqlalchemy.exc import IntegrityError
from sqlmodel import Session, select

from app.users.exceptions import EmailTaken
from app.users.models import AppUser


def normalize_email(email: str) -> str:
    """Trims and lowercases `email`, so lookups and the unique constraint ignore case."""
    return email.strip().lower()


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


def delete(session: Session, user: AppUser) -> None:
    """Deletes the account. The database cascades the delete to its goal and daily logs."""
    session.delete(user)
    session.commit()
