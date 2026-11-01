"""Runs the SQL migrations in this folder against DATABASE_URL.

Every schema change lives in a `NNNN_slug.sql` file next to this one. This runner only
decides which files haven't run yet and runs each one, in file-name order and in its own
transaction, recording it in `schema_migration` (created by 0001). It holds a Postgres
advisory lock while it works, so two runs can't apply the same file twice.

Migrations are forward-only. Never edit a file that has run: the runner compares
checksums and stops. To change or undo something, add a new file.

    python migrations/migrate.py      # what the compose `migrate` service runs
"""

import hashlib
import logging
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

import psycopg

logger = logging.getLogger("migrate")

MIGRATIONS_DIR = Path(__file__).resolve().parent
FILE_NAME = re.compile(r"(?P<number>\d{4})_[a-z0-9_]+\.sql")
# Any constant works. It only has to be the same for every run.
ADVISORY_LOCK_KEY = 4_720_261_029


class MigrationError(Exception):
    """The migration files and the database's record of them don't agree."""


@dataclass(frozen=True)
class Migration:
    """One SQL file. `version` is its file name, which is what `schema_migration` records."""

    version: str
    sql: bytes

    @property
    def checksum(self) -> str:
        return hashlib.sha256(self.sql).hexdigest()


def load_migrations(directory: Path = MIGRATIONS_DIR) -> list[Migration]:
    """Returns every `NNNN_slug.sql` file in `directory`, in number order."""
    migrations: list[Migration] = []
    numbers: set[str] = set()
    for path in sorted(directory.glob("*.sql")):
        match = FILE_NAME.fullmatch(path.name)
        if match is None:
            raise MigrationError(f"{path.name} isn't named like 0001_some_change.sql")
        if match["number"] in numbers:
            raise MigrationError(
                f"More than one migration is numbered {match['number']}"
            )
        numbers.add(match["number"])
        migrations.append(Migration(version=path.name, sql=path.read_bytes()))
    return migrations


def pending(migrations: list[Migration], applied: dict[str, str]) -> list[Migration]:
    """Returns the migrations that haven't run, after checking the ones that have are unchanged.

    `applied` maps each recorded version to its checksum.
    """
    on_disk = {migration.version for migration in migrations}
    missing = sorted(applied.keys() - on_disk)
    if missing:
        raise MigrationError(
            f"Applied migrations are missing from disk: {', '.join(missing)}"
        )
    for migration in migrations:
        recorded = applied.get(migration.version)
        if recorded is not None and recorded != migration.checksum:
            raise MigrationError(
                f"{migration.version} changed after it ran. Revert it and add a new migration instead."
            )
    return [migration for migration in migrations if migration.version not in applied]


def read_applied(connection: psycopg.Connection) -> dict[str, str]:
    """Returns the recorded versions and checksums, or nothing before 0001 has created the table."""
    exists = connection.execute(
        "SELECT to_regclass('schema_migration') IS NOT NULL"
    ).fetchone()
    if exists is None or not exists[0]:
        return {}
    rows = connection.execute(
        "SELECT version, checksum FROM schema_migration"
    ).fetchall()
    return dict(rows)


def migrate(database_url: str, migrations: list[Migration]) -> list[Migration]:
    """Applies the pending migrations and returns them."""
    with psycopg.connect(
        database_url, autocommit=True, connect_timeout=10
    ) as connection:
        # Session-level, so it's released when the connection closes, even on failure.
        connection.execute("SELECT pg_advisory_lock(%s)", (ADVISORY_LOCK_KEY,))
        todo = pending(migrations, read_applied(connection))
        for migration in todo:
            logger.info("Applying %s", migration.version)
            with connection.transaction():
                # No parameters, so psycopg sends the whole file, every statement, as is.
                connection.execute(migration.sql)
                connection.execute(
                    "INSERT INTO schema_migration (version, checksum) VALUES (%s, %s)",
                    (migration.version, migration.checksum),
                )
        return todo


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s  %(message)s")
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        logger.error(
            "DATABASE_URL is not set. Copy .env.example to .env and fill it in."
        )
        return 1
    try:
        applied = migrate(database_url, load_migrations())
    except (MigrationError, psycopg.Error) as exc:
        logger.error(
            "Migration failed. The failing file was rolled back and nothing after it ran: %s",
            exc,
        )
        return 1
    if applied:
        logger.info("Applied %d migration(s)", len(applied))
    else:
        logger.info("Database is up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main())
