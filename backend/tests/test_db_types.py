from datetime import UTC, datetime, timedelta, timezone

import pytest
from sqlalchemy.dialects import sqlite

from app.db_types import UTCDateTime

DIALECT = sqlite.dialect()


def test_binds_aware_datetimes_in_utc() -> None:
    plus_two = datetime(2026, 10, 29, 10, 0, tzinfo=timezone(timedelta(hours=2)))

    bound = UTCDateTime().process_bind_param(plus_two, DIALECT)

    assert bound == datetime(2026, 10, 29, 8, 0, tzinfo=UTC)
    assert bound is not None
    assert bound.tzinfo == UTC


def test_rejects_naive_datetimes() -> None:
    with pytest.raises(ValueError, match="timezone-aware"):
        UTCDateTime().process_bind_param(datetime(2026, 10, 29), DIALECT)  # noqa: DTZ001


def test_reads_naive_values_as_utc() -> None:
    value = UTCDateTime().process_result_value(datetime(2026, 10, 29, 8), DIALECT)  # noqa: DTZ001

    assert value == datetime(2026, 10, 29, 8, tzinfo=UTC)


def test_passes_none_through() -> None:
    assert UTCDateTime().process_bind_param(None, DIALECT) is None
    assert UTCDateTime().process_result_value(None, DIALECT) is None
