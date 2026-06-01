from __future__ import annotations

import argparse
import asyncio
import json
import logging
from dataclasses import asdict, dataclass
from typing import Any

from sqlalchemy import String, select

from app.db.session import async_session_factory, engine
from app.models.lesson import Lesson
from scripts.report_lesson_pilot_feedback import LessonTarget, PilotFeedbackReport, _score_text, build_report


@dataclass(frozen=True)
class LevelPilotFeedbackSummary:
    lesson_count: int
    lessons_with_progress: int
    waiting_lessons: int
    completed_users: int
    review_events: int
    tts_ready_lessons: int
    blocker_count: int


@dataclass(frozen=True)
class LevelPilotFeedbackReport:
    generated_at: str
    level: str
    since_days: int
    include_smoke: bool
    summary: LevelPilotFeedbackSummary
    signals: list[str]
    blockers: list[str]
    lessons: list[PilotFeedbackReport]


def _lesson_label(level: str, lesson_no: int) -> str:
    return f"H{level.upper()}-{lesson_no:03d}"


async def _load_published_targets(level: str) -> list[LessonTarget]:
    normalized_level = level.upper()
    async with async_session_factory() as session:
        result = await session.execute(
            select(Lesson.lesson_no)
            .where(Lesson.jlpt_level.cast(String) == normalized_level, Lesson.is_published.is_(True))
            .order_by(Lesson.lesson_no)
        )
        lesson_numbers = [int(lesson_no) for lesson_no in result.scalars().all()]
    return [
        LessonTarget(
            jlpt_level=normalized_level,
            lesson_no=lesson_no,
            label=_lesson_label(normalized_level, lesson_no),
        )
        for lesson_no in lesson_numbers
    ]


def _lesson_tts_ready(report: PilotFeedbackReport) -> bool:
    tts = report.tts
    return (
        tts.generated_script_line_records == tts.expected_script_line_records
        and tts.generated_question_prompt_records == tts.expected_question_prompt_targets
    )


def summarize_reports(reports: list[PilotFeedbackReport]) -> LevelPilotFeedbackSummary:
    blockers = aggregate_blockers(reports)
    lessons_with_progress = sum(1 for report in reports if report.progress.total_users > 0)
    return LevelPilotFeedbackSummary(
        lesson_count=len(reports),
        lessons_with_progress=lessons_with_progress,
        waiting_lessons=sum(1 for report in reports if report.progress.total_users == 0),
        completed_users=sum(report.progress.completed_users for report in reports),
        review_events=sum(report.review_events.total_events for report in reports),
        tts_ready_lessons=sum(1 for report in reports if _lesson_tts_ready(report)),
        blocker_count=len(blockers),
    )


def aggregate_blockers(reports: list[PilotFeedbackReport]) -> list[str]:
    blockers: list[str] = []
    for report in reports:
        blockers.extend(f"{report.target.label}: {blocker}" for blocker in report.blockers)
    if not reports:
        blockers.append("NO_PUBLISHED_LESSONS: no published lessons were found for the selected level")
    return blockers


def build_level_signals(summary: LevelPilotFeedbackSummary) -> list[str]:
    signals = [
        f"PUBLISHED_LESSONS: {summary.lesson_count}",
        f"LESSONS_WITH_PROGRESS: {summary.lessons_with_progress}",
        f"WAITING_FOR_TRAFFIC: {summary.waiting_lessons}",
        f"COMPLETED_USERS: {summary.completed_users}",
        f"REVIEW_EVENTS: {summary.review_events}",
        f"TTS_READY_LESSONS: {summary.tts_ready_lessons}/{summary.lesson_count}",
    ]
    if summary.blocker_count == 0:
        signals.append("NO_AUTOMATIC_ROLLBACK_TRIGGER: no aggregate monitor blocker found")
    return signals


async def build_level_report(level: str, *, since_days: int, include_smoke: bool) -> LevelPilotFeedbackReport:
    engine.echo = False
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)

    targets = await _load_published_targets(level)
    reports = [await build_report(target, since_days=since_days, include_smoke=include_smoke) for target in targets]
    summary = summarize_reports(reports)
    blockers = aggregate_blockers(reports)
    return LevelPilotFeedbackReport(
        generated_at=reports[0].generated_at if reports else "",
        level=level.upper(),
        since_days=since_days,
        include_smoke=include_smoke,
        summary=summary,
        signals=build_level_signals(summary),
        blockers=blockers,
        lessons=reports,
    )


def _markdown_cell(value: Any) -> str:
    return " ".join(str(value).split()).replace("|", "\\|")


def _lesson_progress_text(report: PilotFeedbackReport) -> str:
    progress = report.progress
    if progress.total_users == 0:
        return "waiting"
    return f"{progress.completed_users}/{progress.total_users} completed; avg {_score_text(progress.average_score_percent)}"


def _lesson_tts_text(report: PilotFeedbackReport) -> str:
    tts = report.tts
    return (
        f"script {tts.generated_script_line_records}/{tts.expected_script_line_records}; "
        f"questions {tts.generated_question_prompt_records}/{tts.expected_question_prompt_targets}"
    )


def render_markdown(report: LevelPilotFeedbackReport) -> str:
    lines = [
        f"# {report.level} Level Pilot Feedback Monitor",
        "",
        f"> Generated: {report.generated_at or 'n/a'}",
        f"> Window: last {report.since_days} day(s)",
        f"> Include smoke users: {str(report.include_smoke).lower()}",
        "> Boundary: aggregate runtime/content monitor; not native-speaker review",
        "",
        "## Summary",
        "",
        "| Metric | Result |",
        "|---|---:|",
        f"| Published lessons | {report.summary.lesson_count} |",
        f"| Lessons with progress | {report.summary.lessons_with_progress} |",
        f"| Waiting for traffic | {report.summary.waiting_lessons} |",
        f"| Completed users | {report.summary.completed_users} |",
        f"| Review events | {report.summary.review_events} |",
        f"| TTS-ready lessons | {report.summary.tts_ready_lessons}/{report.summary.lesson_count} |",
        f"| Blockers | {report.summary.blocker_count} |",
        "",
        "## Lesson Signals",
        "",
        "| Lesson | Title | Published | Progress | Review events | TTS | Blockers |",
        "|---|---|---:|---|---:|---|---|",
    ]
    for lesson_report in report.lessons:
        blockers = "<br>".join(_markdown_cell(blocker) for blocker in lesson_report.blockers) if lesson_report.blockers else "None"
        lines.append(
            "| "
            + " | ".join(
                [
                    _markdown_cell(lesson_report.target.label),
                    _markdown_cell(lesson_report.lesson.title),
                    _markdown_cell(str(lesson_report.lesson.is_published).lower()),
                    _markdown_cell(_lesson_progress_text(lesson_report)),
                    _markdown_cell(lesson_report.review_events.total_events),
                    _markdown_cell(_lesson_tts_text(lesson_report)),
                    blockers,
                ]
            )
            + " |"
        )

    lines.extend(["", "## Signals", ""])
    lines.extend(f"- {signal}" for signal in report.signals)
    lines.extend(["", "## Blockers", ""])
    if report.blockers:
        lines.extend(f"- {blocker}" for blocker in report.blockers)
    else:
        lines.append("- None")
    lines.append("")
    return "\n".join(lines)


def _print_human(report: LevelPilotFeedbackReport) -> None:
    print(f"level {report.level}")
    print(f"lessons {report.summary.lesson_count}")
    print(f"lessons_with_progress {report.summary.lessons_with_progress}")
    print(f"waiting_for_traffic {report.summary.waiting_lessons}")
    print(f"completed_users {report.summary.completed_users}")
    print(f"review_events {report.summary.review_events}")
    print(f"tts_ready_lessons {report.summary.tts_ready_lessons}/{report.summary.lesson_count}")
    print("blockers")
    if report.blockers:
        for blocker in report.blockers:
            print(f"- {blocker}")
    else:
        print("- none")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Report read-only learner pilot signals for all published lessons in one level.")
    parser.add_argument("--level", default="N4", help="JLPT level, for example N4")
    parser.add_argument("--since-days", type=int, default=14, help="Lookback window for progress/review-event rows")
    parser.add_argument("--include-smoke", action="store_true", help="Include codex smoke users in progress/review aggregates")
    parser.add_argument("--json", action="store_true", help="Print JSON instead of the default line-oriented report")
    parser.add_argument("--markdown-output", default=None, help="Write a markdown evidence report")
    parser.add_argument("--fail-on-blocker", action="store_true", help="Exit 1 when any aggregate blocker remains")
    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    report = await build_level_report(args.level, since_days=args.since_days, include_smoke=args.include_smoke)
    if args.markdown_output:
        from pathlib import Path

        output_path = Path(args.markdown_output)
        if not output_path.is_absolute():
            output_path = (Path.cwd() / output_path).resolve()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(render_markdown(report), encoding="utf-8")
        print(f"markdown_report {output_path}")

    if args.json:
        print(json.dumps(asdict(report), ensure_ascii=False, indent=2))
    else:
        _print_human(report)

    if args.fail_on_blocker and report.blockers:
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
