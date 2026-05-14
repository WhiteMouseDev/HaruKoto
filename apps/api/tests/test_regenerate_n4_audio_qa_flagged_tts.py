from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from types import SimpleNamespace
from typing import Any
from uuid import UUID

import pytest

from scripts.regenerate_n4_audio_qa_flagged_tts import (
    FlaggedTtsTask,
    RegenerationResult,
    execute_task,
    read_manifest,
    run_regeneration,
    write_result_csv,
)


@dataclass(frozen=True)
class FakeTtsResult:
    audio: bytes
    provider: str
    model: str


def test_read_manifest_extracts_flag_tasks_and_validates_target_id(tmp_path: Path) -> None:
    lesson_id = "11111111-1111-1111-1111-111111111111"
    manifest = tmp_path / "manifest.csv"
    manifest.write_text(
        "\n".join(
            [
                _manifest_header(),
                f"HN4-001 script:3,{lesson_id},script,3,lesson_script_line,script_line,{lesson_id}:script:3,丁寧に確認します。,https://old.example/1.mp3,FLAG,,,,",
                f"HN4-002 script:0,{lesson_id},script,0,lesson_script_line,script_line,{lesson_id}:script:0,心配ですね。,https://old.example/2.mp3,PENDING,,,,",
                "",
            ]
        ),
        encoding="utf-8",
    )

    tasks = read_manifest(manifest)

    assert tasks == [
        FlaggedTtsTask(
            target_key="HN4-001 script:3",
            lesson_id=lesson_id,
            target_kind="script",
            target_order=3,
            target_type="lesson_script_line",
            field="script_line",
            target_id=f"{lesson_id}:script:3",
            source_text="丁寧に確認します。",
            current_audio_url="https://old.example/1.mp3",
        )
    ]


def test_read_manifest_accepts_cwd_relative_paths(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    lesson_id = "11111111-1111-1111-1111-111111111111"
    manifest_dir = tmp_path / "nested"
    manifest_dir.mkdir()
    manifest = manifest_dir / "manifest.csv"
    manifest.write_text(
        "\n".join(
            [
                _manifest_header(),
                f"HN4-001 script:3,{lesson_id},script,3,lesson_script_line,script_line,{lesson_id}:script:3,丁寧に確認します。,https://old.example/1.mp3,FLAG,,,,",
                "",
            ]
        ),
        encoding="utf-8",
    )
    monkeypatch.chdir(tmp_path)

    tasks = read_manifest(Path("nested/manifest.csv"))

    assert [task.target_key for task in tasks] == ["HN4-001 script:3"]


def test_read_manifest_rejects_prefilled_post_regeneration_columns(tmp_path: Path) -> None:
    lesson_id = "11111111-1111-1111-1111-111111111111"
    manifest = tmp_path / "manifest.csv"
    manifest.write_text(
        "\n".join(
            [
                _manifest_header(),
                f"HN4-001 script:3,{lesson_id},script,3,lesson_script_line,script_line,{lesson_id}:script:3,丁寧に確認します。,https://old.example/1.mp3,FLAG,,https://new.example/1.mp3,,",
                "",
            ]
        ),
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="new_audio_url must be blank"):
        read_manifest(manifest)


@pytest.mark.asyncio
async def test_run_regeneration_dry_run_does_not_call_external_dependencies() -> None:
    task = _make_task()

    async def fake_generate(text: str) -> FakeTtsResult:
        raise AssertionError("generator should not be called in dry-run")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        raise AssertionError("uploader should not be called in dry-run")

    results = await run_regeneration(
        [task],
        execute=False,
        continue_on_error=False,
        sleep_seconds=0,
        run_id="RUN",
        tts_generator=fake_generate,
        uploader=fake_upload,
        session_factory=_factory(_FakeSession([])),  # type: ignore[arg-type]
    )

    assert len(results) == 1
    assert results[0].status == "planned"
    assert results[0].gcs_path == f"tts/lesson/{task.lesson_id}/script-line-1-regen-RUN.mp3"


def test_write_result_csv_records_planned_dry_run_rows(tmp_path: Path) -> None:
    task = _make_task()
    output = tmp_path / "results.csv"

    count = write_result_csv(output, [run_result := _planned_result(task)])

    assert count == 1
    assert output.read_text(encoding="utf-8").splitlines()[1] == (
        f"{task.target_key},{task.target_id},{task.source_text},{task.current_audio_url},"
        f"{run_result.status},{run_result.gcs_path},,,,,"
    )


@pytest.mark.asyncio
async def test_execute_task_updates_existing_record_after_generation_and_upload() -> None:
    lesson_id = UUID("11111111-1111-1111-1111-111111111111")
    task = _make_task(lesson_id=str(lesson_id))
    lesson = SimpleNamespace(
        id=lesson_id,
        content_jsonb={"reading": {"script": [{"text": "unused"}, {"text": "丁寧に確認します。"}]}, "questions": []},
    )
    existing = SimpleNamespace(
        audio_url="https://old.example/script-line-1.mp3",
        text="old",
        provider="elevenlabs",
        model="eleven_multilingual_v2",
        field="script_line",
    )
    session = _FakeSession([_ScalarOneOrNoneResult(lesson), _ScalarOneOrNoneResult(existing)])
    generated_texts: list[str] = []
    uploads: list[tuple[str, bytes]] = []

    async def fake_generate(text: str) -> FakeTtsResult:
        generated_texts.append(text)
        return FakeTtsResult(audio=b"new-mp3", provider="elevenlabs", model="eleven_multilingual_v2")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        uploads.append((gcs_path, audio))
        return "https://new.example/script-line-1.mp3"

    result = await execute_task(
        task,
        run_id="20260514T000000Z",
        tts_generator=fake_generate,
        uploader=fake_upload,
        session_factory=_factory(session),  # type: ignore[arg-type]
    )

    assert result.status == "regenerated"
    assert result.gcs_path == f"tts/lesson/{lesson_id}/script-line-1-regen-20260514T000000Z.mp3"
    assert result.old_audio_url == "https://old.example/script-line-1.mp3"
    assert result.new_audio_url == "https://new.example/script-line-1.mp3"
    assert generated_texts == ["丁寧に確認します。"]
    assert uploads == [(f"tts/lesson/{lesson_id}/script-line-1-regen-20260514T000000Z.mp3", b"new-mp3")]
    assert existing.text == "丁寧に確認します。"
    assert existing.audio_url == "https://new.example/script-line-1.mp3"
    assert session.commit_calls == 1


@pytest.mark.asyncio
async def test_execute_task_fails_before_generation_when_audio_url_drifted() -> None:
    lesson_id = UUID("11111111-1111-1111-1111-111111111111")
    task = _make_task(lesson_id=str(lesson_id))
    lesson = SimpleNamespace(
        id=lesson_id,
        content_jsonb={"reading": {"script": [{"text": "unused"}, {"text": "丁寧に確認します。"}]}, "questions": []},
    )
    existing = SimpleNamespace(audio_url="https://different.example/script-line-1.mp3")
    session = _FakeSession([_ScalarOneOrNoneResult(lesson), _ScalarOneOrNoneResult(existing)])

    async def fake_generate(text: str) -> FakeTtsResult:
        raise AssertionError("generator should not be called after drift detection")

    async def fake_upload(gcs_path: str, audio: bytes) -> str:
        raise AssertionError("uploader should not be called after drift detection")

    result = await execute_task(
        task,
        run_id="RUN",
        tts_generator=fake_generate,
        uploader=fake_upload,
        session_factory=_factory(session),  # type: ignore[arg-type]
    )

    assert result.status == "failed"
    assert "current audio URL drift" in str(result.error)
    assert session.commit_calls == 0


def _make_task(*, lesson_id: str = "11111111-1111-1111-1111-111111111111") -> FlaggedTtsTask:
    return FlaggedTtsTask(
        target_key="HN4-001 script:1",
        lesson_id=lesson_id,
        target_kind="script",
        target_order=1,
        target_type="lesson_script_line",
        field="script_line",
        target_id=f"{lesson_id}:script:1",
        source_text="丁寧に確認します。",
        current_audio_url="https://old.example/script-line-1.mp3",
    )


def _manifest_header() -> str:
    return (
        "target_key,lesson_id,target_kind,target_order,target_type,field,target_id,source_text,"
        "current_audio_url,current_verdict,regeneration_status,new_audio_url,post_regen_verdict,post_regen_notes"
    )


def _planned_result(task: FlaggedTtsTask) -> RegenerationResult:
    return RegenerationResult(task=task, status="planned", gcs_path=task.gcs_path("RUN"))


class _FakeSession:
    def __init__(self, results: list[Any]) -> None:
        self._results = results
        self.commit_calls = 0

    async def execute(self, *args: Any, **kwargs: Any) -> Any:
        if not self._results:
            raise AssertionError("Unexpected execute call")
        return self._results.pop(0)

    async def commit(self) -> None:
        self.commit_calls += 1


class _SessionContext:
    def __init__(self, session: _FakeSession) -> None:
        self._session = session

    async def __aenter__(self) -> _FakeSession:
        return self._session

    async def __aexit__(self, exc_type: object, exc: object, traceback: object) -> None:
        return None


def _factory(session: _FakeSession) -> Any:
    def create() -> _SessionContext:
        return _SessionContext(session)

    return create


class _ScalarOneOrNoneResult:
    def __init__(self, value: Any) -> None:
        self._value = value

    def scalar_one_or_none(self) -> Any:
        return self._value
