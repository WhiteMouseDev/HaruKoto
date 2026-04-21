from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any
from unittest.mock import MagicMock

import pytest

from app.models.tts import TtsAudio
from app.services.admin_tts import (
    AdminTtsServiceError,
    get_admin_tts_map,
    regenerate_admin_tts_audio,
    resolve_tts_text,
)


@dataclass(frozen=True)
class FakeTtsResult:
    audio: bytes
    provider: str
    model: str


def _scalar_result(obj: object | None) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = obj
    return result


@pytest.mark.asyncio
async def test_get_admin_tts_map_returns_all_supported_fields() -> None:
    created_at = datetime(2026, 4, 21, 12, 0, tzinfo=UTC)
    records = [
        SimpleNamespace(
            field="reading",
            audio_url="https://cdn.example.com/reading.mp3",
            provider="elevenlabs",
            created_at=created_at,
        ),
        SimpleNamespace(
            field="unsupported_field",
            audio_url="https://cdn.example.com/ignored.mp3",
            provider="elevenlabs",
            created_at=created_at,
        ),
    ]
    db = _FakeDb([_ScalarsResult(records)])

    result = await get_admin_tts_map(
        db,  # type: ignore[arg-type]
        content_type="vocabulary",
        item_id="item-1",
    )

    assert set(result.audios) == {"reading", "word", "example_sentence"}
    assert result.audios["reading"] is not None
    assert result.audios["reading"].audio_url == "https://cdn.example.com/reading.mp3"
    assert result.audios["reading"].provider == "elevenlabs"
    assert result.audios["word"] is None
    assert result.audios["example_sentence"] is None
    assert "unsupported_field" not in result.audios
    assert db.execute_calls == 1


@pytest.mark.asyncio
async def test_get_admin_tts_map_rejects_unknown_content_type() -> None:
    db = _FakeDb([])

    with pytest.raises(AdminTtsServiceError) as exc_info:
        await get_admin_tts_map(
            db,  # type: ignore[arg-type]
            content_type="unknown",
            item_id="item-1",
        )

    assert exc_info.value.status_code == 400
    assert "Unknown content_type" in exc_info.value.detail
    assert db.execute_calls == 0


def test_resolve_tts_text_uses_first_grammar_example_sentence() -> None:
    grammar = MagicMock()
    grammar.example_sentences = [{"japanese": "日本語の例文", "sentence": "fallback"}]
    grammar.pattern = "文法パターン"

    assert resolve_tts_text("grammar", "example_sentences", grammar) == "日本語の例文"


def test_resolve_tts_text_falls_back_to_grammar_pattern() -> None:
    grammar = MagicMock()
    grammar.example_sentences = []
    grammar.pattern = "文法パターン"

    assert resolve_tts_text("grammar", "example_sentences", grammar) == "文法パターン"


def test_resolve_tts_text_rejects_empty_field() -> None:
    vocab = MagicMock()
    vocab.reading = ""

    with pytest.raises(AdminTtsServiceError) as exc_info:
        resolve_tts_text("vocabulary", "reading", vocab)

    assert exc_info.value.status_code == 422
    assert "empty or unavailable" in exc_info.value.detail


@pytest.mark.asyncio
async def test_regenerate_admin_tts_audio_generates_uploads_and_persists() -> None:
    vocab = MagicMock()
    vocab.reading = "テスト"
    db = _FakeDb([_scalar_result(vocab), MagicMock()])
    generated_texts: list[str] = []
    uploads: list[tuple[str, bytes]] = []

    async def fake_generate(text: str) -> FakeTtsResult:
        generated_texts.append(text)
        return FakeTtsResult(audio=b"fake-mp3", provider="elevenlabs", model="eleven_multilingual_v2")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        uploads.append((gcs_path, audio))
        return "https://cdn.example.com/tts/admin/vocabulary/item-1/reading.mp3"

    result = await regenerate_admin_tts_audio(
        db,  # type: ignore[arg-type]
        content_type="vocabulary",
        item_id="item-1",
        field="reading",
        tts_generator=fake_generate,
        upload_to_gcs=fake_upload,
    )

    assert result.audio_url == "https://cdn.example.com/tts/admin/vocabulary/item-1/reading.mp3"
    assert result.field == "reading"
    assert result.provider == "elevenlabs"
    assert generated_texts == ["テスト"]
    assert uploads == [("tts/admin/vocabulary/item-1/reading.mp3", b"fake-mp3")]
    assert db.execute_calls == 2
    assert db.commit_calls == 1
    assert isinstance(db.added[0], TtsAudio)
    assert db.added[0].target_type == "vocabulary"
    assert db.added[0].target_id == "item-1"
    assert db.added[0].field == "reading"
    assert db.added[0].text == "テスト"


@pytest.mark.asyncio
async def test_regenerate_admin_tts_audio_maps_generation_failure() -> None:
    vocab = MagicMock()
    vocab.reading = "テスト"
    db = _FakeDb([_scalar_result(vocab), MagicMock()])

    async def fail_generate(text: str) -> FakeTtsResult:
        raise RuntimeError("provider down")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        raise AssertionError("upload should not be called")

    with pytest.raises(AdminTtsServiceError) as exc_info:
        await regenerate_admin_tts_audio(
            db,  # type: ignore[arg-type]
            content_type="vocabulary",
            item_id="item-1",
            field="reading",
            tts_generator=fail_generate,
            upload_to_gcs=fake_upload,
        )

    assert exc_info.value.status_code == 502
    assert exc_info.value.detail == "TTS生成に失敗しました"
    assert db.commit_calls == 0


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


class _ScalarsResult:
    def __init__(self, items: list[Any]) -> None:
        self._items = items

    def scalars(self) -> _ScalarsResult:
        return self

    def all(self) -> list[Any]:
        return self._items
