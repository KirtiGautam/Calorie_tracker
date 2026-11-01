import pytest
from sqlmodel import Session

from app.users import service
from app.users.exceptions import EmailTaken


def test_create_maps_unique_violation_to_email_taken(
    session: Session, monkeypatch: pytest.MonkeyPatch
) -> None:
    service.create(session, "ada@example.com", "hash")
    # Simulate a second signup that passed the existence check before the first one committed.
    monkeypatch.setattr(service, "get_by_email", lambda *_: None)

    with pytest.raises(EmailTaken):
        service.create(session, "ADA@example.com", "hash")
