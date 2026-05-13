from __future__ import annotations

import argparse
import asyncio
import logging
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Literal

import httpx
from sqlalchemy import String, select

from app.db.session import async_session_factory, engine
from app.models.lesson import Chapter, Lesson
from app.models.tts import TtsAudio
from app.services.tts_target_resolver import (
    LESSON_QUESTION_PROMPT_TTS_FIELD,
    LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE,
    LESSON_SCRIPT_LINE_TTS_FIELD,
    LESSON_SCRIPT_LINE_TTS_TARGET_TYPE,
)

TargetKind = Literal["script", "question"]


@dataclass(frozen=True)
class LessonSource:
    lesson_id: str
    lesson_no: int
    chapter_no: int
    chapter_title: str
    title: str
    topic: str
    content: dict[str, Any]

    @property
    def label(self) -> str:
        return f"HN4-{self.lesson_no:03d}"


@dataclass(frozen=True)
class AudioQaTarget:
    lesson_label: str
    lesson_title: str
    chapter_no: int
    chapter_title: str
    kind: TargetKind
    order: int
    target_type: str
    target_id: str
    field: str
    text: str
    speaker: str | None = None
    translation: str | None = None
    provider: str | None = None
    model: str | None = None
    audio_url: str | None = None
    url_status: str = "not_checked"

    @property
    def display_target(self) -> str:
        if self.kind == "script":
            return f"script {self.order}"
        return f"question {self.order}"


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _clean_text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).replace("\n", " ").strip()


def _target_key(target: AudioQaTarget) -> tuple[str, str, str]:
    return (target.target_type, target.target_id, target.field)


def build_targets_for_lesson(lesson: LessonSource) -> list[AudioQaTarget]:
    content = lesson.content or {}
    targets: list[AudioQaTarget] = []

    reading = content.get("reading")
    script = reading.get("script") if isinstance(reading, dict) else None
    if isinstance(script, list):
        for index, line in enumerate(script):
            if not isinstance(line, dict):
                continue
            text = _clean_text(line.get("text"))
            if not text:
                continue
            targets.append(
                AudioQaTarget(
                    lesson_label=lesson.label,
                    lesson_title=lesson.title,
                    chapter_no=lesson.chapter_no,
                    chapter_title=lesson.chapter_title,
                    kind="script",
                    order=index,
                    target_type=LESSON_SCRIPT_LINE_TTS_TARGET_TYPE,
                    target_id=f"{lesson.lesson_id}:script:{index}",
                    field=LESSON_SCRIPT_LINE_TTS_FIELD,
                    text=text,
                    speaker=_clean_text(line.get("speaker")) or None,
                    translation=_clean_text(line.get("translation")) or None,
                )
            )

    questions = content.get("questions")
    if isinstance(questions, list):
        for fallback_order, question in enumerate(questions, start=1):
            if not isinstance(question, dict):
                continue
            text = _clean_text(question.get("prompt"))
            if not text:
                continue
            raw_order = question.get("order")
            order = raw_order if isinstance(raw_order, int) else fallback_order
            targets.append(
                AudioQaTarget(
                    lesson_label=lesson.label,
                    lesson_title=lesson.title,
                    chapter_no=lesson.chapter_no,
                    chapter_title=lesson.chapter_title,
                    kind="question",
                    order=order,
                    target_type=LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE,
                    target_id=f"{lesson.lesson_id}:question:{order}",
                    field=LESSON_QUESTION_PROMPT_TTS_FIELD,
                    text=text,
                )
            )

    return targets


def attach_audio_records(
    targets: list[AudioQaTarget],
    records: dict[tuple[str, str, str], tuple[str, str, str]],
) -> list[AudioQaTarget]:
    attached: list[AudioQaTarget] = []
    for target in targets:
        record = records.get(_target_key(target))
        if record is None:
            attached.append(target)
            continue
        provider, model, audio_url = record
        attached.append(
            AudioQaTarget(
                lesson_label=target.lesson_label,
                lesson_title=target.lesson_title,
                chapter_no=target.chapter_no,
                chapter_title=target.chapter_title,
                kind=target.kind,
                order=target.order,
                target_type=target.target_type,
                target_id=target.target_id,
                field=target.field,
                text=target.text,
                speaker=target.speaker,
                translation=target.translation,
                provider=provider,
                model=model,
                audio_url=audio_url,
                url_status=target.url_status,
            )
        )
    return attached


async def attach_url_statuses(targets: list[AudioQaTarget], *, timeout_seconds: float) -> list[AudioQaTarget]:
    async with httpx.AsyncClient(timeout=timeout_seconds, follow_redirects=True) as client:
        checked: list[AudioQaTarget] = []
        for target in targets:
            status = "missing_url"
            if target.audio_url:
                try:
                    response = await client.get(target.audio_url, headers={"Range": "bytes=0-4095"})
                    content_type = response.headers.get("content-type", "")
                    if response.status_code in (200, 206) and response.content and ("audio" in content_type or "mpeg" in content_type):
                        status = "ok"
                    else:
                        status = f"failed_http_{response.status_code}"
                except httpx.HTTPError as exc:
                    status = f"failed_{exc.__class__.__name__}"
            checked.append(
                AudioQaTarget(
                    lesson_label=target.lesson_label,
                    lesson_title=target.lesson_title,
                    chapter_no=target.chapter_no,
                    chapter_title=target.chapter_title,
                    kind=target.kind,
                    order=target.order,
                    target_type=target.target_type,
                    target_id=target.target_id,
                    field=target.field,
                    text=target.text,
                    speaker=target.speaker,
                    translation=target.translation,
                    provider=target.provider,
                    model=target.model,
                    audio_url=target.audio_url,
                    url_status=status,
                )
            )
    return checked


def _markdown_escape(value: str) -> str:
    return value.replace("|", "\\|")


def _audio_link(target: AudioQaTarget) -> str:
    if not target.audio_url:
        return "MISSING"
    return f"[audio]({target.audio_url})"


def render_packet_markdown(
    *,
    generated_at: str,
    level: str,
    chapter_no: int,
    targets: list[AudioQaTarget],
) -> str:
    lesson_labels = sorted({target.lesson_label for target in targets})
    script_count = sum(1 for target in targets if target.kind == "script")
    question_count = sum(1 for target in targets if target.kind == "question")
    missing_audio = [target for target in targets if not target.audio_url]
    failed_urls = [target for target in targets if target.url_status not in {"ok", "not_checked"}]
    chapter_title = targets[0].chapter_title if targets else ""

    lines = [
        f"# {level} Pilot Human Audio QA Packet - Chapter {chapter_no}",
        "",
        f"> Date: {generated_at[:10]}",
        f"> Scope: {level} chapter {chapter_no} `{chapter_title}`, {', '.join(lesson_labels)}",
        "> Status: REVIEW PACKET - human verdict pending",
        "",
        "## Boundary",
        "",
        "This packet is for human audio-quality review. It does not regenerate audio,",
        "change lesson content, update rollout status, or claim native-speaker approval.",
        "",
        "ASSUMPTION: One full chapter is the minimum representative playback QA gate",
        "before considering broader N4 rollout. A flagged or failed item should block",
        "broad rollout until regenerated or explicitly waived.",
        "",
        "## Reviewer Instructions",
        "",
        "1. Open each audio link.",
        "2. Compare the audio against the Japanese text.",
        "3. Mark reviewer verdict as `PASS`, `FLAG`, or `FAIL`.",
        "4. Use notes for misread text, clipped audio, unnatural pacing, wrong language,",
        "   distracting pronunciation, or content/text mismatch.",
        "",
        "## Verdict Rubric",
        "",
        "| Verdict | Meaning | Broad-rollout impact |",
        "|---|---|---|",
        "| PASS | Text is complete, intelligible, and acceptable for learner playback | Can proceed for this item |",
        "| FLAG | Understandable but has noticeable pacing, accent, or prompt-shape issue | Review before rollout; may need waiver |",
        "| FAIL | Wrong text, clipped audio, wrong language, missing audio, or unusable pronunciation | Regenerate or fix before rollout |",
        "",
        "## Summary",
        "",
        "| Metric | Result |",
        "|---|---:|",
        f"| Generated at | `{generated_at}` |",
        f"| Lessons | {len(lesson_labels)} |",
        f"| Script-line targets | {script_count} |",
        f"| Question-prompt targets | {question_count} |",
        f"| Total review targets | {len(targets)} |",
        f"| Missing audio URLs | {len(missing_audio)} |",
        f"| Failed URL checks | {len(failed_urls)} |",
        "",
        "## Review Items",
        "",
    ]

    current_lesson = None
    for target in targets:
        if target.lesson_label != current_lesson:
            current_lesson = target.lesson_label
            lines.extend(
                [
                    f"### {target.lesson_label} - {target.lesson_title}",
                    "",
                    "| Target | Speaker | Japanese text | Korean/context | Provider/model | URL check | Audio | Reviewer verdict | Notes |",
                    "|---|---|---|---|---|---|---|---|---|",
                ]
            )
        provider_model = ""
        if target.provider or target.model:
            provider_model = f"{target.provider or '?'} / {target.model or '?'}"
        lines.append(
            "| "
            + " | ".join(
                [
                    _markdown_escape(target.display_target),
                    _markdown_escape(target.speaker or ""),
                    _markdown_escape(target.text),
                    _markdown_escape(target.translation or ""),
                    _markdown_escape(provider_model),
                    _markdown_escape(target.url_status),
                    _audio_link(target),
                    "PENDING",
                    "",
                ]
            )
            + " |"
        )
        lines.append("")

    lines.extend(
        [
            "## Result",
            "",
            "Human verdict is pending. This packet closes only the preparation step for",
            "representative full-chapter playback review.",
        ]
    )
    return "\n".join(lines) + "\n"


async def _load_lessons(level: str, chapter_no: int) -> list[LessonSource]:
    async with async_session_factory() as session:
        result = await session.execute(
            select(Lesson, Chapter)
            .join(Chapter, Lesson.chapter_id == Chapter.id)
            .where(
                Lesson.jlpt_level.cast(String) == level,
                Lesson.is_published.is_(True),
                Chapter.chapter_no == chapter_no,
            )
            .order_by(Lesson.lesson_no)
        )
        return [
            LessonSource(
                lesson_id=str(lesson.id),
                lesson_no=lesson.lesson_no,
                chapter_no=chapter.chapter_no,
                chapter_title=chapter.title,
                title=lesson.title,
                topic=lesson.topic,
                content=lesson.content_jsonb or {},
            )
            for lesson, chapter in result
        ]


async def _load_audio_records(targets: list[AudioQaTarget]) -> dict[tuple[str, str, str], tuple[str, str, str]]:
    records: dict[tuple[str, str, str], tuple[str, str, str]] = {}
    target_ids_by_type: dict[str, set[str]] = {
        LESSON_SCRIPT_LINE_TTS_TARGET_TYPE: set(),
        LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE: set(),
    }
    for target in targets:
        target_ids_by_type[target.target_type].add(target.target_id)

    async with async_session_factory() as session:
        for target_type, target_ids in target_ids_by_type.items():
            if not target_ids:
                continue
            field = LESSON_SCRIPT_LINE_TTS_FIELD
            if target_type == LESSON_QUESTION_PROMPT_TTS_TARGET_TYPE:
                field = LESSON_QUESTION_PROMPT_TTS_FIELD
            result = await session.execute(
                select(
                    TtsAudio.target_type,
                    TtsAudio.target_id,
                    TtsAudio.field,
                    TtsAudio.provider,
                    TtsAudio.model,
                    TtsAudio.audio_url,
                ).where(
                    TtsAudio.target_type == target_type,
                    TtsAudio.target_id.in_(target_ids),
                    TtsAudio.field == field,
                    TtsAudio.speed == 1.0,
                )
            )
            for target_type_value, target_id, field_value, provider, model, audio_url in result:
                records[(str(target_type_value), str(target_id), str(field_value))] = (
                    str(provider),
                    str(model),
                    str(audio_url),
                )
    return records


async def build_packet(*, level: str, chapter_no: int, check_audio_urls: bool, timeout_seconds: float) -> str:
    engine.echo = False
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)

    lessons = await _load_lessons(level, chapter_no)
    targets = [target for lesson in lessons for target in build_targets_for_lesson(lesson)]
    records = await _load_audio_records(targets)
    targets = attach_audio_records(targets, records)
    if check_audio_urls:
        targets = await attach_url_statuses(targets, timeout_seconds=timeout_seconds)
    return render_packet_markdown(
        generated_at=_utc_now().isoformat(),
        level=level,
        chapter_no=chapter_no,
        targets=targets,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a human audio QA packet for published N4 lesson TTS.")
    parser.add_argument("--level", default="N4", help="JLPT level, for example N4")
    parser.add_argument("--chapter-no", type=int, default=1, help="Published chapter number to review")
    parser.add_argument("--check-audio-urls", action="store_true", help="Read-only HTTP check for each audio URL")
    parser.add_argument("--timeout-seconds", type=float, default=10.0, help="Timeout for each audio URL HTTP check")
    parser.add_argument("--output", type=Path, default=None, help="Write markdown to this path instead of stdout")
    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    markdown = await build_packet(
        level=args.level.upper(),
        chapter_no=args.chapter_no,
        check_audio_urls=args.check_audio_urls,
        timeout_seconds=args.timeout_seconds,
    )
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(markdown, encoding="utf-8")
    else:
        print(markdown)


if __name__ == "__main__":
    asyncio.run(main())
