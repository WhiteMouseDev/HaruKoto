from __future__ import annotations

from dataclasses import dataclass
from typing import Any
from unittest.mock import MagicMock

import pytest

from app.models.tts import TtsAudio
from app.services.admin_tts import AdminTtsServiceError, regenerate_admin_tts_audio, resolve_tts_text


@dataclass(frozen=True)
class FakeTtsResult:
    audio: bytes
    provider: str
    model: str


def _scalar_result(obj: object | None) -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = obj
    return result


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
