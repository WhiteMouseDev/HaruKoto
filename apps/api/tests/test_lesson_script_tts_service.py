from __future__ import annotations

import uuid
from dataclasses import dataclass
from types import SimpleNamespace
from typing import Any

import pytest

from app.models.tts import TtsAudio
from app.services.lesson_script_tts import LessonScriptTtsServiceError, generate_lesson_script_line_tts


@dataclass(frozen=True)
class FakeTtsResult:
    audio: bytes
    provider: str
    model: str


@pytest.mark.asyncio
async def test_generate_lesson_script_line_tts_returns_cached_audio() -> None:
    lesson = _make_lesson()
    cached = SimpleNamespace(audio_url="https://cdn.example.com/cached.mp3")
    db = _FakeDb([_ScalarOneOrNoneResult(lesson), _ScalarOneOrNoneResult(cached)])

    async def fake_generate(text: str) -> FakeTtsResult:
        raise AssertionError("generator should not be called")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        raise AssertionError("upload should not be called")

    result = await generate_lesson_script_line_tts(
        db,  # type: ignore[arg-type]
        lesson_id=lesson.id,
        line_index=0,
        tts_generator=fake_generate,
        upload_to_gcs=fake_upload,
    )

    assert result.audio_url == "https://cdn.example.com/cached.mp3"
    assert db.execute_calls == 2
    assert db.commit_calls == 0


@pytest.mark.asyncio
async def test_generate_lesson_script_line_tts_generates_uploads_and_persists() -> None:
    lesson = _make_lesson(text="学生です。")
    db = _FakeDb([_ScalarOneOrNoneResult(lesson), _ScalarOneOrNoneResult(None)])
    generated_texts: list[str] = []
    uploads: list[tuple[str, bytes]] = []
    generating: set[str] = set()

    async def fake_generate(text: str) -> FakeTtsResult:
        generated_texts.append(text)
        return FakeTtsResult(audio=b"fake-mp3", provider="elevenlabs", model="eleven_multilingual_v2")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        uploads.append((gcs_path, audio))
        return "https://cdn.example.com/tts/lesson/script.mp3"

    result = await generate_lesson_script_line_tts(
        db,  # type: ignore[arg-type]
        lesson_id=lesson.id,
        line_index=0,
        tts_generator=fake_generate,
        upload_to_gcs=fake_upload,
        generating=generating,
    )

    assert result.audio_url == "https://cdn.example.com/tts/lesson/script.mp3"
    assert generated_texts == ["学生です。"]
    assert uploads == [(f"tts/lesson/{lesson.id}/script-line-0.mp3", b"fake-mp3")]
    assert db.execute_calls == 2
    assert db.commit_calls == 1
    assert generating == set()
    assert isinstance(db.added[0], TtsAudio)
    assert db.added[0].target_type == "lesson_script_line"
    assert db.added[0].target_id == f"{lesson.id}:script:0"
    assert db.added[0].text == "学生です。"
    assert db.added[0].field == "script_line"


@pytest.mark.asyncio
async def test_generate_lesson_script_line_tts_rejects_missing_line() -> None:
    lesson = _make_lesson(script=[])
    db = _FakeDb([_ScalarOneOrNoneResult(lesson)])

    async def fake_generate(text: str) -> FakeTtsResult:
        raise AssertionError("generator should not be called")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        raise AssertionError("upload should not be called")

    with pytest.raises(LessonScriptTtsServiceError) as exc_info:
        await generate_lesson_script_line_tts(
            db,  # type: ignore[arg-type]
            lesson_id=lesson.id,
            line_index=0,
            tts_generator=fake_generate,
            upload_to_gcs=fake_upload,
        )

    assert exc_info.value.status_code == 404
    assert db.execute_calls == 1
    assert db.commit_calls == 0


def _make_lesson(
    *,
    text: str = "こんにちは。",
    script: list[dict[str, str]] | None = None,
) -> SimpleNamespace:
    return SimpleNamespace(
        id=uuid.uuid4(),
        content_jsonb={
            "reading": {
                "script": script if script is not None else [{"text": text}],
            }
        },
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
