"""Request and response types that several domains share."""

from datetime import UTC, datetime
from typing import Annotated

from pydantic import AfterValidator, AwareDatetime


def to_utc(value: datetime) -> datetime:
    """Converts `value` to UTC, rejecting one that falls outside the representable range there."""
    try:
        return value.astimezone(UTC)
    except OverflowError as exc:
        # Pydantic turns ValueError into a 422. Any other exception would be a 500.
        raise ValueError("The datetime is out of range once converted to UTC") from exc


# An aware datetime, converted to UTC, so comparing, storing and returning it never depends on
# the offset the client sent.
UTCDatetime = Annotated[AwareDatetime, AfterValidator(to_utc)]
