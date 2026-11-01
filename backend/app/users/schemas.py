import uuid

from pydantic import BaseModel


class UserPublic(BaseModel):
    """The account fields a client may see."""

    id: uuid.UUID
    email: str
