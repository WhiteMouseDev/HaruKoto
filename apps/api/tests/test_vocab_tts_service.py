from __future__ import annotations

import uuid
from dataclasses import dataclass
from types import SimpleNamespace
from typing import Any

import pytest

from app.models.tts import TtsAudio
from app.services.vocab_tts import VocabTtsServiceError, generate_vocabulary_tts


@dataclass(frozen=True)
class FakeTtsResult:
    audio: bytes
    provider: str
    model: str


@pytest.mark.asyncio
async def test_generate_vocabulary_tts_returns_cached_tts_audio() -> None:
    vocab = _make_vocab(audio_url=None)
    cached = SimpleNamespace(audio_url="https://cdn.example.com/cached.mp3")
    db = _FakeDb([_ScalarOneOrNoneResult(vocab), _ScalarOneOrNoneResult(cached)])

    async def fake_generate(text: str) -> FakeTtsResult:
        raise AssertionError("generator should not be called")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        raise AssertionError("upload should not be called")

    result = await generate_vocabulary_tts(
        db,  # type: ignore[arg-type]
        vocabulary_id=str(vocab.id),
        tts_generator=fake_generate,
        upload_to_gcs=fake_upload,
    )

    assert result.audio_url == "https://cdn.example.com/cached.mp3"
    assert db.execute_calls == 2
    assert db.commit_calls == 0


@pytest.mark.asyncio
async def test_generate_vocabulary_tts_returns_legacy_audio_url() -> None:
    vocab = _make_vocab(audio_url="https://cdn.example.com/legacy.mp3")
    db = _FakeDb([_ScalarOneOrNoneResult(vocab), _ScalarOneOrNoneResult(None)])

    async def fake_generate(text: str) -> FakeTtsResult:
        raise AssertionError("generator should not be called")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        raise AssertionError("upload should not be called")

    result = await generate_vocabulary_tts(
        db,  # type: ignore[arg-type]
        vocabulary_id=str(vocab.id),
        tts_generator=fake_generate,
        upload_to_gcs=fake_upload,
    )

    assert result.audio_url == "https://cdn.example.com/legacy.mp3"
    assert db.execute_calls == 2
    assert db.commit_calls == 0


@pytest.mark.asyncio
async def test_generate_vocabulary_tts_generates_uploads_and_persists() -> None:
    vocab = _make_vocab(word="テスト", reading="テスト読み", audio_url=None)
    db = _FakeDb([_ScalarOneOrNoneResult(vocab), _ScalarOneOrNoneResult(None)])
    generated_texts: list[str] = []
    uploads: list[tuple[str, bytes]] = []
    generating: set[str] = set()

    async def fake_generate(text: str) -> FakeTtsResult:
        generated_texts.append(text)
        return FakeTtsResult(audio=b"fake-mp3", provider="elevenlabs", model="eleven_multilingual_v2")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        uploads.append((gcs_path, audio))
        return "https://cdn.example.com/tts/vocab/item.mp3"

    result = await generate_vocabulary_tts(
        db,  # type: ignore[arg-type]
        vocabulary_id=str(vocab.id),
        tts_generator=fake_generate,
        upload_to_gcs=fake_upload,
        generating=generating,
    )

    assert result.audio_url == "https://cdn.example.com/tts/vocab/item.mp3"
    assert generated_texts == ["テスト読み"]
    assert uploads == [(f"tts/vocab/{vocab.id}.mp3", b"fake-mp3")]
    assert db.execute_calls == 2
    assert db.commit_calls == 1
    assert generating == set()
    assert vocab.audio_url == "https://cdn.example.com/tts/vocab/item.mp3"
    assert isinstance(db.added[0], TtsAudio)
    assert db.added[0].target_type == "vocabulary"
    assert db.added[0].target_id == str(vocab.id)
    assert db.added[0].text == "テスト読み"
    assert db.added[0].field == "reading"


@pytest.mark.asyncio
async def test_generate_vocabulary_tts_rejects_duplicate_generation() -> None:
    vocab = _make_vocab(audio_url=None)
    db = _FakeDb([_ScalarOneOrNoneResult(vocab), _ScalarOneOrNoneResult(None)])
    generating = {str(vocab.id)}

    async def fake_generate(text: str) -> FakeTtsResult:
        raise AssertionError("generator should not be called")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        raise AssertionError("upload should not be called")

    with pytest.raises(VocabTtsServiceError) as exc_info:
        await generate_vocabulary_tts(
            db,  # type: ignore[arg-type]
            vocabulary_id=str(vocab.id),
            tts_generator=fake_generate,
            upload_to_gcs=fake_upload,
            generating=generating,
        )

    assert exc_info.value.status_code == 409
    assert exc_info.value.detail == "TTS 생성 중입니다. 잠시 후 다시 시도해주세요."
    assert generating == {str(vocab.id)}
    assert db.execute_calls == 2
    assert db.commit_calls == 0


@pytest.mark.asyncio
async def test_generate_vocabulary_tts_maps_generation_failure_and_clears_lock() -> None:
    vocab = _make_vocab(audio_url=None)
    db = _FakeDb([_ScalarOneOrNoneResult(vocab), _ScalarOneOrNoneResult(None)])
    generating: set[str] = set()

    async def fail_generate(text: str) -> FakeTtsResult:
        raise RuntimeError("provider down")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        raise AssertionError("upload should not be called")

    with pytest.raises(VocabTtsServiceError) as exc_info:
        await generate_vocabulary_tts(
            db,  # type: ignore[arg-type]
            vocabulary_id=str(vocab.id),
            tts_generator=fail_generate,
            upload_to_gcs=fake_upload,
            generating=generating,
        )

    assert exc_info.value.status_code == 502
    assert exc_info.value.detail == "TTS 음성 생성에 실패했습니다"
    assert generating == set()
    assert db.execute_calls == 2
    assert db.commit_calls == 0


@pytest.mark.asyncio
async def test_generate_vocabulary_tts_rejects_missing_vocabulary() -> None:
    db = _FakeDb([_ScalarOneOrNoneResult(None)])

    async def fake_generate(text: str) -> FakeTtsResult:
        raise AssertionError("generator should not be called")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        raise AssertionError("upload should not be called")

    with pytest.raises(VocabTtsServiceError) as exc_info:
        await generate_vocabulary_tts(
            db,  # type: ignore[arg-type]
            vocabulary_id="missing",
            tts_generator=fake_generate,
            upload_to_gcs=fake_upload,
        )

    assert exc_info.value.status_code == 404
    assert exc_info.value.detail == "단어를 찾을 수 없습니다"
    assert db.execute_calls == 1
    assert db.commit_calls == 0


def _make_vocab(
    *,
    word: str = "テスト",
    reading: str = "テスト",
    audio_url: str | None,
) -> SimpleNamespace:
    return SimpleNamespace(
        id=uuid.uuid4(),
        word=word,
        reading=reading,
        audio_url=audio_url,
    )


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
