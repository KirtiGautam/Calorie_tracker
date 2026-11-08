import re
from pathlib import Path

import pytest
from sqlmodel import SQLModel

from migrations.migrate import (
    Migration,
    MigrationError,
    load_migrations,
    main,
    pending,
)


def write(directory: Path, name: str, sql: str = "SELECT 1;") -> None:
    (directory / name).write_text(sql)


def test_loads_the_real_migrations_in_number_order() -> None:
    versions = [migration.version for migration in load_migrations()]

    assert versions == sorted(versions)
    assert versions[0] == "0001_create_schema_migration.sql"


def test_rejects_badly_named_files(tmp_path: Path) -> None:
    write(tmp_path, "add_things.sql")

    with pytest.raises(MigrationError, match="isn't named like"):
        load_migrations(tmp_path)


def test_rejects_duplicate_numbers(tmp_path: Path) -> None:
    write(tmp_path, "0001_first.sql")
    write(tmp_path, "0001_second.sql")

    with pytest.raises(MigrationError, match="numbered 0001"):
        load_migrations(tmp_path)


def test_pending_skips_applied_migrations(tmp_path: Path) -> None:
    write(tmp_path, "0001_first.sql")
    write(tmp_path, "0002_second.sql", "SELECT 2;")
    first, second = load_migrations(tmp_path)

    todo = pending([first, second], {first.version: first.checksum})

    assert todo == [second]


def test_pending_refuses_an_edited_migration() -> None:
    original = Migration("0001_first.sql", b"SELECT 1;")
    edited = Migration("0001_first.sql", b"SELECT 2;")

    with pytest.raises(MigrationError, match="changed after it ran"):
        pending([edited], {original.version: original.checksum})


def test_pending_refuses_a_deleted_migration() -> None:
    gone = Migration("0001_first.sql", b"SELECT 1;")

    with pytest.raises(MigrationError, match="missing from disk"):
        pending([], {gone.version: gone.checksum})


def test_main_fails_without_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("DATABASE_URL", raising=False)

    assert main() == 1


def test_sql_creates_every_model_table_and_column() -> None:
    """A cheap guard against the SQL and the models drifting apart. Tests use the models."""
    sql = "\n".join(migration.sql.decode() for migration in load_migrations())

    for table in SQLModel.metadata.sorted_tables:
        match = re.search(rf"CREATE TABLE {table.name} \((.*?)\n\);", sql, re.DOTALL)
        assert match is not None, f"No CREATE TABLE for {table.name}"
        for column in table.columns:
            created = re.search(rf"^\s+{column.name} ", match[1], re.MULTILINE)
            added = f"ALTER TABLE {table.name} ADD COLUMN {column.name} " in sql
            assert created or added, (
                f"{table.name}.{column.name} is missing from the SQL"
            )
        assert f"ALTER TABLE {table.name} ENABLE ROW LEVEL SECURITY" in sql


def test_expired_refresh_tokens_are_pruned_daily_using_an_index() -> None:
    sql = "\n".join(migration.sql.decode() for migration in load_migrations())

    assert "CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog" in sql
    assert "ON refresh_token (expires_at)" in sql
    job = re.search(r"cron\.schedule\(\s*'([^']+)',\s*'([^']+)',\s*\$\$(.*?)\$\$", sql)
    assert job is not None
    assert job[1] == "prune-expired-refresh-tokens"
    assert job[2] == "17 3 * * *"
    assert (
        job[3]
        == "DELETE FROM refresh_token WHERE expires_at < now() - interval '1 day'"
    )
