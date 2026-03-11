import random
from typing import TypeVar

T = TypeVar("T")


def shuffle[T](items: list[T]) -> list[T]:
    """Return a new shuffled copy of the list."""
    result = items.copy()
    random.shuffle(result)
    return result
