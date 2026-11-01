from typing import Literal

from pydantic import BaseModel


class HealthStatus(BaseModel):
    """The body of a successful health check."""

    status: Literal["ok"] = "ok"
