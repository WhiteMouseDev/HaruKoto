from __future__ import annotations

import hashlib

import pytest

from app.services.tts_generation import TtsServiceError, stable_tts_key, tts_generation_lock


class FakeTtsServiceError(TtsServiceError):
    pass


def test_stable_tts_key_returns_md5_hash_for_storage_paths() -> None:
    assert stable_tts_key("あ") == hashlib.md5("あ".encode()).hexdigest()  # noqa: S324


def test_tts_generation_lock_adds_and_releases_generation_key() -> None:
    active_generations: set[str] = set()

    with tts_generation_lock("key-1", active_generations, error_cls=FakeTtsServiceError):
        assert active_generations == {"key-1"}

    assert active_generations == set()


def test_tts_generation_lock_rejects_duplicate_generation() -> None:
    active_generations = {"key-1"}

    with pytest.raises(FakeTtsServiceError) as exc_info, tts_generation_lock("key-1", active_generations, error_cls=FakeTtsServiceError):
        raise AssertionError("lock should not be acquired")

    assert exc_info.value.status_code == 409
    assert exc_info.value.detail == "TTS 생성 중입니다. 잠시 후 다시 시도해주세요."
    assert active_generations == {"key-1"}


def test_tts_generation_lock_releases_generation_key_on_error() -> None:
    active_generations: set[str] = set()

    with pytest.raises(RuntimeError), tts_generation_lock("key-1", active_generations, error_cls=FakeTtsServiceError):
        raise RuntimeError("generation failed")

    assert active_generations == set()
