from __future__ import annotations

import uuid
from dataclasses import dataclass
from types import SimpleNamespace
from typing import Any
from unittest.mock import AsyncMock, Mock

import pytest

from app.models.enums import JlptLevel
from app.models.tts import TtsAudio
from app.services import lesson_script_tts, lesson_voice_tts
from app.services.lesson_script_tts import (
    LessonScriptTtsServiceError,
    _lesson_lookup_query,
    generate_lesson_question_prompt_tts,
    generate_lesson_script_line_tts,
)


@pytest.fixture(autouse=True)
def disable_optional_lesson_voices(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_FEMALE_VOICE_ID", "")
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_MALE_VOICE_ID", "")


@dataclass(frozen=True)
class FakeTtsResult:
    audio: bytes
    provider: str
    model: str


def test_lesson_lookup_query_keeps_published_filter_by_default() -> None:
    lesson_id = uuid.uuid4()

    default_query = str(_lesson_lookup_query(lesson_id, allow_unpublished=False))
    ops_query = str(_lesson_lookup_query(lesson_id, allow_unpublished=True))

    assert "lessons.is_published IS true" in default_query
    assert "lessons.is_published IS true" not in ops_query


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


@pytest.mark.asyncio
async def test_generate_lesson_question_prompt_tts_generates_uploads_and_persists() -> None:
    lesson = _make_lesson(questions=[{"order": 2, "prompt": "厚いの意味は何ですか。"}])
    db = _FakeDb([_ScalarOneOrNoneResult(lesson), _ScalarOneOrNoneResult(None)])
    generated_texts: list[str] = []
    uploads: list[tuple[str, bytes]] = []
    generating: set[str] = set()

    async def fake_generate(text: str) -> FakeTtsResult:
        generated_texts.append(text)
        return FakeTtsResult(audio=b"fake-mp3", provider="elevenlabs", model="eleven_multilingual_v2")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        uploads.append((gcs_path, audio))
        return "https://cdn.example.com/tts/lesson/question.mp3"

    result = await generate_lesson_question_prompt_tts(
        db,  # type: ignore[arg-type]
        lesson_id=lesson.id,
        question_order=2,
        tts_generator=fake_generate,
        upload_to_gcs=fake_upload,
        generating=generating,
    )

    assert result.audio_url == "https://cdn.example.com/tts/lesson/question.mp3"
    assert generated_texts == ["厚いの意味は何ですか。"]
    assert uploads == [(f"tts/lesson/{lesson.id}/question-2.mp3", b"fake-mp3")]
    assert db.execute_calls == 2
    assert db.commit_calls == 1
    assert generating == set()
    assert isinstance(db.added[0], TtsAudio)
    assert db.added[0].target_type == "lesson_question_prompt"
    assert db.added[0].target_id == f"{lesson.id}:question:2"
    assert db.added[0].text == "厚いの意味は何ですか。"
    assert db.added[0].field == "question_prompt"


def _enable_lesson_voices(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_API_KEY", "test-api-key")
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_MODEL_ID", "eleven_multilingual_v2")
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_FEMALE_VOICE_ID", "female-voice")
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_MALE_VOICE_ID", "male-voice")


@pytest.mark.asyncio
@pytest.mark.parametrize(("alias", "voice_id"), [("japanese_female_1", "female-voice"), ("japanese_male_1", "male-voice")])
async def test_n5_new_audio_routes_content_role_and_versions_only_new_file(
    monkeypatch: pytest.MonkeyPatch, alias: str, voice_id: str
) -> None:
    _enable_lesson_voices(monkeypatch)
    script = [{"text": "学生です。", "voice_id": alias}]
    lesson = _make_lesson(script=script)
    lesson.jlpt_level = JlptLevel.N5
    db = _FakeDb([_ScalarOneOrNoneResult(lesson), _ScalarOneOrNoneResult(None)])
    role_generator = AsyncMock(return_value=FakeTtsResult(b"role-audio", "elevenlabs", "eleven_multilingual_v2"))
    monkeypatch.setattr(lesson_script_tts, "generate_lesson_voice_tts", role_generator)
    legacy = AsyncMock(side_effect=AssertionError("must use role generator"))
    uploader = AsyncMock(return_value="https://cdn.example.com/new-version.mp3")

    result = await generate_lesson_script_line_tts(
        db,
        lesson_id=lesson.id,
        line_index=0,
        tts_generator=legacy,
        upload_to_gcs=uploader,  # type: ignore[arg-type]
    )

    profile = role_generator.await_args.args[0]
    assert profile.voice_alias == alias and profile.voice_id == voice_id
    uploader.assert_awaited_once()
    path, audio = uploader.await_args.args
    prefix = f"tts/lesson/{lesson.id}/script-line-0-voice-{profile.fingerprint}-gen-"
    assert path.startswith(prefix) and audio == b"role-audio"
    generation_id = path.removeprefix(prefix).removesuffix(".mp3")
    assert uuid.UUID(generation_id).hex == generation_id
    assert result.audio_url == "https://cdn.example.com/new-version.mp3"
    assert db.added[0].target_type == "lesson_script_line"
    assert db.added[0].target_id == f"{lesson.id}:script:0"
    assert db.added[0].field == "script_line" and db.added[0].speed == 1.0
    assert db.commit_calls == 1 and db.execute_calls == 2
    assert lesson.content_jsonb["reading"]["script"] == script
    legacy.assert_not_awaited()


@pytest.mark.asyncio
async def test_legacy_cache_precedes_even_invalid_active_profile(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_MALE_VOICE_ID", "only-partial-setting")
    lesson = _make_lesson(script=[{"text": "学生です。", "voice_id": "unknown"}])
    db = _FakeDb([_ScalarOneOrNoneResult(lesson), _ScalarOneOrNoneResult(SimpleNamespace(audio_url="https://cdn.example/legacy.mp3"))])
    profile = AsyncMock(side_effect=AssertionError("cached audio needs no profile"))
    monkeypatch.setattr(lesson_script_tts, "build_lesson_voice_profile", profile)
    generator, uploader = AsyncMock(), AsyncMock()
    result = await generate_lesson_script_line_tts(
        db,
        lesson_id=lesson.id,
        line_index=0,
        tts_generator=generator,
        upload_to_gcs=uploader,  # type: ignore[arg-type]
    )
    assert result.audio_url == "https://cdn.example/legacy.mp3"
    assert db.commit_calls == 0 and not db.added
    profile.assert_not_called()
    generator.assert_not_called()
    uploader.assert_not_called()


@pytest.mark.asyncio
async def test_n4_cache_miss_keeps_legacy_generation_despite_active_role_settings(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_lesson_voices(monkeypatch)
    lesson = _make_lesson(jlpt_level="N4", script=[{"text": "学生です。", "voice_id": "unknown"}])
    db = _FakeDb([_ScalarOneOrNoneResult(lesson), _ScalarOneOrNoneResult(None)])
    role_generator = AsyncMock(side_effect=AssertionError("N4 must keep its existing policy"))
    monkeypatch.setattr(lesson_script_tts, "generate_lesson_voice_tts", role_generator)
    legacy = AsyncMock(return_value=FakeTtsResult(b"legacy", "gemini", "legacy-model"))
    uploader = AsyncMock(return_value="https://cdn.example/legacy-new.mp3")
    await generate_lesson_script_line_tts(
        db,
        lesson_id=lesson.id,
        line_index=0,
        tts_generator=legacy,
        upload_to_gcs=uploader,  # type: ignore[arg-type]
    )
    legacy.assert_awaited_once_with("学生です。")
    role_generator.assert_not_awaited()
    uploader.assert_awaited_once_with(f"tts/lesson/{lesson.id}/script-line-0.mp3", b"legacy")


@pytest.mark.asyncio
@pytest.mark.parametrize("failure", ["unknown-role", "missing-role", "partial-setting", "same-voices", "missing-key", "provider"])
async def test_n5_role_failures_use_existing_502_and_do_not_persist(monkeypatch: pytest.MonkeyPatch, failure: str) -> None:
    _enable_lesson_voices(monkeypatch)
    line = {"text": "学生です。", "voice_id": "japanese_male_1"}
    if failure == "unknown-role":
        line["voice_id"] = "unknown"
    elif failure == "missing-role":
        del line["voice_id"]
    elif failure == "partial-setting":
        monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_FEMALE_VOICE_ID", "")
    elif failure == "same-voices":
        monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_FEMALE_VOICE_ID", "male-voice")
    elif failure == "missing-key":
        monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_API_KEY", "")
    role_generator = AsyncMock(side_effect=RuntimeError("provider down"))
    monkeypatch.setattr(lesson_script_tts, "generate_lesson_voice_tts", role_generator)
    lesson = _make_lesson(script=[line])
    db = _FakeDb([_ScalarOneOrNoneResult(lesson), _ScalarOneOrNoneResult(None)])
    legacy, uploader = AsyncMock(), AsyncMock()
    generating: set[str] = set()
    with pytest.raises(LessonScriptTtsServiceError) as exc:
        await generate_lesson_script_line_tts(
            db,  # type: ignore[arg-type]
            lesson_id=lesson.id,
            line_index=0,
            tts_generator=legacy,
            upload_to_gcs=uploader,
            generating=generating,
        )
    assert exc.value.status_code == 502 and exc.value.detail == "TTS 음성 생성에 실패했습니다"
    assert db.commit_calls == 0 and not db.added and not generating
    legacy.assert_not_called()
    uploader.assert_not_called()
    assert role_generator.await_count == (1 if failure == "provider" else 0)


@pytest.mark.asyncio
async def test_question_prompt_ignores_even_invalid_new_voice_settings(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(lesson_voice_tts.settings, "ELEVENLABS_LESSON_MALE_VOICE_ID", "partial")
    lesson = _make_lesson()
    db = _FakeDb([_ScalarOneOrNoneResult(lesson), _ScalarOneOrNoneResult(None)])
    legacy = AsyncMock(return_value=FakeTtsResult(b"question", "gemini", "question-model"))
    uploader = AsyncMock(return_value="https://cdn.example/question.mp3")
    await generate_lesson_question_prompt_tts(
        db,
        lesson_id=lesson.id,
        question_order=1,
        tts_generator=legacy,
        upload_to_gcs=uploader,  # type: ignore[arg-type]
    )
    legacy.assert_awaited_once_with("問題です。")
    uploader.assert_awaited_once_with(f"tts/lesson/{lesson.id}/question-1.mp3", b"question")


@pytest.mark.asyncio
async def test_same_profile_retry_after_commit_failure_uploads_to_a_new_object(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_lesson_voices(monkeypatch)
    lesson = _make_lesson(script=[{"text": "学生です。", "voice_id": "japanese_male_1"}])

    class FailingCommitDb(_FakeDb):
        async def commit(self) -> None:
            self.commit_calls += 1
            raise RuntimeError("commit failed")

    first_db = FailingCommitDb([_ScalarOneOrNoneResult(lesson), _ScalarOneOrNoneResult(None)])
    retry_db = _FakeDb([_ScalarOneOrNoneResult(lesson), _ScalarOneOrNoneResult(None)])
    role_generator = AsyncMock(return_value=FakeTtsResult(b"role-audio", "elevenlabs", "eleven_multilingual_v2"))
    monkeypatch.setattr(lesson_script_tts, "generate_lesson_voice_tts", role_generator)
    uploaded_paths: list[str] = []

    async def upload(path: str, audio: bytes) -> str:
        uploaded_paths.append(path)
        return f"https://cdn.example/{path}"

    generating: set[str] = set()
    legacy = AsyncMock(side_effect=AssertionError("no legacy fallback"))
    with pytest.raises(RuntimeError, match="commit failed"):
        await generate_lesson_script_line_tts(
            first_db,  # type: ignore[arg-type]
            lesson_id=lesson.id,
            line_index=0,
            tts_generator=legacy,
            upload_to_gcs=upload,
            generating=generating,
        )
    assert not generating
    result = await generate_lesson_script_line_tts(
        retry_db,  # type: ignore[arg-type]
        lesson_id=lesson.id,
        line_index=0,
        tts_generator=legacy,
        upload_to_gcs=upload,
        generating=generating,
    )
    first_profile, retry_profile = [call.args[0] for call in role_generator.await_args_list]
    assert first_profile.fingerprint == retry_profile.fingerprint
    assert len(set(uploaded_paths)) == 2
    prefix = f"tts/lesson/{lesson.id}/script-line-0-voice-{first_profile.fingerprint}-gen-"
    assert all(path.startswith(prefix) and path.endswith(".mp3") for path in uploaded_paths)
    assert result.audio_url == f"https://cdn.example/{uploaded_paths[1]}"
    assert retry_db.commit_calls == 1 and not generating


@pytest.mark.asyncio
async def test_role_provider_error_body_is_suppressed_in_service_logs(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    _enable_lesson_voices(monkeypatch)
    sentinel = "sensitive-provider-body-test-sentinel"
    monkeypatch.setattr(lesson_voice_tts, "_generate_lesson_audio", Mock(side_effect=RuntimeError(sentinel)))
    lesson = _make_lesson(script=[{"text": "学生です。", "voice_id": "japanese_male_1"}])
    db = _FakeDb([_ScalarOneOrNoneResult(lesson), _ScalarOneOrNoneResult(None)])
    legacy, uploader = AsyncMock(), AsyncMock()
    with pytest.raises(LessonScriptTtsServiceError) as exc:
        await generate_lesson_script_line_tts(
            db,
            lesson_id=lesson.id,
            line_index=0,
            tts_generator=legacy,
            upload_to_gcs=uploader,  # type: ignore[arg-type]
        )
    assert exc.value.status_code == 502 and exc.value.detail == "TTS 음성 생성에 실패했습니다"
    assert "Lesson speaker TTS generation failed" in caplog.text
    assert sentinel not in caplog.text and sentinel not in str(exc.value)
    assert not db.added and db.commit_calls == 0
    legacy.assert_not_called()
    uploader.assert_not_called()


def _make_lesson(
    *,
    text: str = "こんにちは。",
    script: list[dict[str, str]] | None = None,
    questions: list[dict[str, object]] | None = None,
    jlpt_level: str = "N5",
) -> SimpleNamespace:
    return SimpleNamespace(
        id=uuid.uuid4(),
        jlpt_level=jlpt_level,
        content_jsonb={
            "reading": {
                "script": script if script is not None else [{"text": text}],
            },
            "questions": questions if questions is not None else [{"order": 1, "prompt": "問題です。"}],
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
