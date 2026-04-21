from __future__ import annotations

import hashlib
from dataclasses import dataclass
from types import SimpleNamespace
from typing import Any

import pytest

from app.models.tts import TtsAudio
from app.services.kana_tts import KanaTtsServiceError, generate_kana_tts


@dataclass(frozen=True)
class FakeTtsResult:
    audio: bytes
    provider: str
    model: str


@pytest.mark.asyncio
async def test_generate_kana_tts_returns_cached_audio() -> None:
    cached = SimpleNamespace(audio_url="https://cdn.example.com/kana-cached.mp3")
    db = _FakeDb([_ScalarOneOrNoneResult(cached)])

    async def fake_generate(text: str) -> FakeTtsResult:
        raise AssertionError("generator should not be called")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        raise AssertionError("upload should not be called")

    result = await generate_kana_tts(
        db,  # type: ignore[arg-type]
        text="あ",
        tts_generator=fake_generate,
        upload_to_gcs=fake_upload,
    )

    assert result.audio_url == "https://cdn.example.com/kana-cached.mp3"
    assert db.execute_calls == 1
    assert db.commit_calls == 0


@pytest.mark.asyncio
async def test_generate_kana_tts_generates_uploads_and_persists() -> None:
    db = _FakeDb([_ScalarOneOrNoneResult(None)])
    generated_texts: list[str] = []
    uploads: list[tuple[str, bytes]] = []
    generating: set[str] = set()
    expected_hash = _kana_hash("あ")

    async def fake_generate(text: str) -> FakeTtsResult:
        generated_texts.append(text)
        return FakeTtsResult(audio=b"fake-mp3", provider="elevenlabs", model="eleven_multilingual_v2")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        uploads.append((gcs_path, audio))
        return "https://cdn.example.com/tts/kana/a.mp3"

    result = await generate_kana_tts(
        db,  # type: ignore[arg-type]
        text="あ",
        tts_generator=fake_generate,
        upload_to_gcs=fake_upload,
        generating=generating,
    )

    assert result.audio_url == "https://cdn.example.com/tts/kana/a.mp3"
    assert generated_texts == ["あ"]
    assert uploads == [(f"tts/kana/{expected_hash}.mp3", b"fake-mp3")]
    assert db.execute_calls == 1
    assert db.commit_calls == 1
    assert generating == set()
    assert isinstance(db.added[0], TtsAudio)
    assert db.added[0].target_type == "kana"
    assert db.added[0].target_id == expected_hash
    assert db.added[0].text == "あ"


@pytest.mark.asyncio
async def test_generate_kana_tts_rejects_duplicate_generation() -> None:
    text_hash = _kana_hash("あ")
    db = _FakeDb([_ScalarOneOrNoneResult(None)])
    generating = {text_hash}

    async def fake_generate(text: str) -> FakeTtsResult:
        raise AssertionError("generator should not be called")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        raise AssertionError("upload should not be called")

    with pytest.raises(KanaTtsServiceError) as exc_info:
        await generate_kana_tts(
            db,  # type: ignore[arg-type]
            text="あ",
            tts_generator=fake_generate,
            upload_to_gcs=fake_upload,
            generating=generating,
        )

    assert exc_info.value.status_code == 409
    assert exc_info.value.detail == "TTS 생성 중입니다. 잠시 후 다시 시도해주세요."
    assert generating == {text_hash}
    assert db.execute_calls == 1
    assert db.commit_calls == 0


@pytest.mark.asyncio
async def test_generate_kana_tts_maps_generation_failure_and_clears_lock() -> None:
    db = _FakeDb([_ScalarOneOrNoneResult(None)])
    generating: set[str] = set()

    async def fail_generate(text: str) -> FakeTtsResult:
        raise RuntimeError("provider down")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        raise AssertionError("upload should not be called")

    with pytest.raises(KanaTtsServiceError) as exc_info:
        await generate_kana_tts(
            db,  # type: ignore[arg-type]
            text="あ",
            tts_generator=fail_generate,
            upload_to_gcs=fake_upload,
            generating=generating,
        )

    assert exc_info.value.status_code == 502
    assert exc_info.value.detail == "TTS 음성 생성에 실패했습니다"
    assert generating == set()
    assert db.execute_calls == 1
    assert db.commit_calls == 0


def _kana_hash(text: str) -> str:
    return hashlib.md5(text.encode()).hexdigest()  # noqa: S324


class _FakeDb:
    def __init__(self, results: list[Any]) -> None:
        self._results = results
        self.execute_calls = 0
        self.commit_calls = 0
        self.added: list[Any] = []

    async def execute(self, *args: Any, **kwargs: Any) -> Any:
        self.execute_calls += 1
        if not self._results:
            raise AssertionError("Unexpected execute call")
        return self._results.pop(0)

    def add(self, obj: Any) -> None:
        self.added.append(obj)

    async def commit(self) -> None:
        self.commit_calls += 1


class _ScalarOneOrNoneResult:
    def __init__(self, value: Any) -> None:
        self._value = value

    def scalar_one_or_none(self) -> Any:
        return self._value
