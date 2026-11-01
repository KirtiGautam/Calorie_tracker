from collections.abc import Iterator
from typing import Annotated

from fastapi import Depends
from sqlmodel import Session, create_engine

from app.config import get_settings

# Creating the engine doesn't connect. The first connection happens on the first query.
engine = create_engine(
    get_settings().sqlalchemy_database_url,
    pool_pre_ping=True,
    connect_args={"connect_timeout": 5},
)


def get_session() -> Iterator[Session]:
    with Session(engine) as session:
        yield session


SessionDep = Annotated[Session, Depends(get_session)]
