from __future__ import annotations

from typing import Any
from uuid import UUID

from app.schemas.common import CamelModel


class MissionResponse(CamelModel):
    id: UUID
    mission_type: str
    target_count: int
    current_count: int
    is_completed: bool
    reward_claimed: bool
    xp_reward: int


class MissionClaimRequest(CamelModel):
    mission_id: UUID


class MissionClaimResponse(CamelModel):
    xp_reward: int
    total_xp: int
    events: list[dict[str, Any]]
