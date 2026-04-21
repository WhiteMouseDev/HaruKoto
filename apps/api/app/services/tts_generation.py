from __future__ import annotations

import hashlib
from collections.abc import Awaitable, Callable, Iterator
from contextlib import contextmanager
from typing import Protocol

DUPLICATE_TTS_GENERATION_DETAIL = "TTS 생성 중입니다. 잠시 후 다시 시도해주세요."
TTS_GENERATION_FAILED_DETAIL = "TTS 음성 생성에 실패했습니다"


class GeneratedTtsAudio(Protocol):
    audio: bytes
    provider: str
    model: str


type TtsGenerator = Callable[[str], Awaitable[GeneratedTtsAudio]]
type TtsUploader = Callable[[str, bytes], Awaitable[str]]


class TtsServiceError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@contextmanager
def tts_generation_lock(
    generation_key: str,
    active_generations: set[str],
    *,
    error_cls: type[TtsServiceError],
) -> Iterator[None]:
    if generation_key in active_generations:
        raise error_cls(status_code=409, detail=DUPLICATE_TTS_GENERATION_DETAIL)

    active_generations.add(generation_key)
    try:
        yield
    finally:
        active_generations.discard(generation_key)


def stable_tts_key(text: str) -> str:
    return hashlib.md5(text.encode()).hexdigest()  # noqa: S324
