"""공통 유틸리티 함수."""

from __future__ import annotations

from enum import Enum
from typing import Any


def enum_value(obj: Any) -> Any:
    """Enum이면 .value를 반환하고, 아니면 그대로 반환한다.

    ``jlpt_level.value if hasattr(jlpt_level, "value") else jlpt_level``
    패턴을 대체하는 헬퍼.
    """
    if isinstance(obj, Enum):
        return obj.value
    return obj
