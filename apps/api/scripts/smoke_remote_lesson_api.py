from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import httpx

SCRIPT_DIR = Path(__file__).resolve().parent
API_DIR = SCRIPT_DIR.parent
REPO_ROOT = API_DIR.parent.parent
DEFAULT_API_BASE_URL = "https://harukoto-api-842843944454.asia-northeast3.run.app"
DEFAULT_TARGET_LESSONS = [12, 13, 14, 15, 16]


@dataclass(frozen=True)
class LessonRef:
    lesson_no: int
    lesson_id: str
    chapter_no: int | None
    chapter_lesson_no: int | None
    title: str


@dataclass(frozen=True)
class DetailCheck:
    lesson_no: int
    lesson_id: str
    status: str
    script_lines: int
    questions: int
    vocab_items: int
    grammar_items: int
    answer_keys_stripped: bool
    blockers: list[str]


@dataclass(frozen=True)
class RemoteLessonApiSmokeReport:
    generated_at: str
    api_base_url: str
    level: str
    account_label: str
    status: str
    chapter_count: int
    lesson_count: int
    target_lessons: list[LessonRef]
    detail_checks: list[DetailCheck]
    blockers: list[str]
    assumptions: list[str]


def _utc_now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")


def _load_env_defaults(paths: list[Path]) -> None:
    for path in paths:
        if not path.exists():
            continue
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip("'\"")
            if key and key not in os.environ:
                os.environ[key] = value


def _mask_email(email: str) -> str:
    if "@" not in email:
        return "***"
    local, domain = email.split("@", 1)
    if not local:
        return f"***@{domain}"
    return f"{local[0]}***@{domain}"


def _normalize_base_url(value: str) -> str:
    return value.rstrip("/")


def _request_json(
    client: httpx.Client,
    method: str,
    url: str,
    *,
    headers: dict[str, str],
    json_body: dict[str, Any] | None = None,
    label: str,
) -> dict[str, Any]:
    try:
        response = client.request(method, url, headers=headers, json=json_body)
    except httpx.HTTPError as error:
        raise RuntimeError(f"{label} request failed: {error.__class__.__name__}") from error

    if response.status_code >= 400:
        body = response.text[:300].replace("\n", " ")
        raise RuntimeError(f"{label} returned HTTP {response.status_code}: {body}")

    try:
        payload = response.json()
    except json.JSONDecodeError as error:
        raise RuntimeError(f"{label} returned non-JSON response") from error
    if not isinstance(payload, dict):
        raise RuntimeError(f"{label} returned unsupported JSON root")
    return payload


def _sign_in(
    client: httpx.Client,
    *,
    supabase_url: str,
    supabase_anon_key: str,
    email: str,
    password: str,
) -> str:
    payload = _request_json(
        client,
        "POST",
        f"{_normalize_base_url(supabase_url)}/auth/v1/token?grant_type=password",
        headers={
            "apikey": supabase_anon_key,
            "Content-Type": "application/json",
        },
        json_body={"email": email, "password": password},
        label="supabase_password_sign_in",
    )
    token = payload.get("access_token")
    if not isinstance(token, str) or not token:
        raise RuntimeError("supabase_password_sign_in did not return an access token")
    return token


def _extract_lessons(chapters_payload: dict[str, Any]) -> tuple[list[dict[str, Any]], list[str]]:
    chapters = chapters_payload.get("chapters")
    if not isinstance(chapters, list):
        return [], ["CHAPTERS_SHAPE: response root did not include a chapters list"]

    lessons: list[dict[str, Any]] = []
    blockers: list[str] = []
    for chapter in chapters:
        if not isinstance(chapter, dict):
            blockers.append("CHAPTERS_SHAPE: chapter entry was not an object")
            continue
        chapter_lessons = chapter.get("lessons")
        if not isinstance(chapter_lessons, list):
            blockers.append(f"CHAPTERS_SHAPE: chapter {chapter.get('chapterNo')} did not include a lessons list")
            continue
        for lesson in chapter_lessons:
            if isinstance(lesson, dict):
                lessons.append({**lesson, "_chapterNo": chapter.get("chapterNo")})
            else:
                blockers.append(f"CHAPTERS_SHAPE: chapter {chapter.get('chapterNo')} included a non-object lesson")
    return lessons, blockers


def validate_chapters(
    chapters_payload: dict[str, Any],
    *,
    expected_chapter_count: int,
    expected_lesson_count: int,
    expected_target_chapter_no: int,
    target_lesson_nos: list[int],
) -> tuple[int, int, list[LessonRef], list[str]]:
    chapters = chapters_payload.get("chapters")
    chapter_count = len(chapters) if isinstance(chapters, list) else 0
    lessons, blockers = _extract_lessons(chapters_payload)
    lesson_count = len(lessons)

    if expected_chapter_count > 0 and chapter_count != expected_chapter_count:
        blockers.append(f"CHAPTER_COUNT: expected {expected_chapter_count}, got {chapter_count}")
    if expected_lesson_count > 0 and lesson_count != expected_lesson_count:
        blockers.append(f"LESSON_COUNT: expected {expected_lesson_count}, got {lesson_count}")

    targets: list[LessonRef] = []
    lessons_by_no = {lesson.get("lessonNo"): lesson for lesson in lessons}
    for lesson_no in target_lesson_nos:
        lesson = lessons_by_no.get(lesson_no)
        if lesson is None:
            blockers.append(f"TARGET_LESSON_MISSING: HN4-{lesson_no:03d} was not returned by chapters API")
            continue
        lesson_id = lesson.get("id")
        if not isinstance(lesson_id, str) or not lesson_id:
            blockers.append(f"TARGET_LESSON_ID: HN4-{lesson_no:03d} did not include a usable id")
            continue
        chapter_no = lesson.get("_chapterNo")
        if expected_target_chapter_no > 0 and chapter_no != expected_target_chapter_no:
            blockers.append(f"TARGET_CHAPTER: HN4-{lesson_no:03d} expected chapter {expected_target_chapter_no}, got {chapter_no}")
        targets.append(
            LessonRef(
                lesson_no=lesson_no,
                lesson_id=lesson_id,
                chapter_no=chapter_no if isinstance(chapter_no, int) else None,
                chapter_lesson_no=lesson.get("chapterLessonNo") if isinstance(lesson.get("chapterLessonNo"), int) else None,
                title=str(lesson.get("title") or ""),
            )
        )
    return chapter_count, lesson_count, targets, blockers


def validate_detail(
    detail_payload: dict[str, Any],
    *,
    lesson_ref: LessonRef,
    expected_script_lines: int,
    expected_questions: int,
) -> DetailCheck:
    blockers: list[str] = []
    if detail_payload.get("id") != lesson_ref.lesson_id:
        blockers.append(f"DETAIL_ID: HN4-{lesson_ref.lesson_no:03d} detail id did not match chapters id")
    if detail_payload.get("lessonNo") != lesson_ref.lesson_no:
        blockers.append(f"DETAIL_LESSON_NO: expected {lesson_ref.lesson_no}, got {detail_payload.get('lessonNo')}")

    content = detail_payload.get("content")
    reading = content.get("reading") if isinstance(content, dict) else None
    script = reading.get("script") if isinstance(reading, dict) else None
    questions = content.get("questions") if isinstance(content, dict) else None
    vocab_items = detail_payload.get("vocabItems")
    grammar_items = detail_payload.get("grammarItems")

    script_count = len(script) if isinstance(script, list) else 0
    question_count = len(questions) if isinstance(questions, list) else 0
    vocab_count = len(vocab_items) if isinstance(vocab_items, list) else 0
    grammar_count = len(grammar_items) if isinstance(grammar_items, list) else 0

    if script_count != expected_script_lines:
        blockers.append(f"DETAIL_SCRIPT_LINES: HN4-{lesson_ref.lesson_no:03d} expected {expected_script_lines}, got {script_count}")
    if question_count != expected_questions:
        blockers.append(f"DETAIL_QUESTIONS: HN4-{lesson_ref.lesson_no:03d} expected {expected_questions}, got {question_count}")
    if vocab_count == 0:
        blockers.append(f"DETAIL_VOCAB_ITEMS: HN4-{lesson_ref.lesson_no:03d} returned no vocabItems")
    if grammar_count == 0:
        blockers.append(f"DETAIL_GRAMMAR_ITEMS: HN4-{lesson_ref.lesson_no:03d} returned no grammarItems")

    answer_keys_stripped = True
    if isinstance(questions, list):
        for question in questions:
            if not isinstance(question, dict):
                answer_keys_stripped = False
                blockers.append(f"DETAIL_QUESTION_SHAPE: HN4-{lesson_ref.lesson_no:03d} included a non-object question")
                continue
            if question.get("correctAnswer") is not None or question.get("correctOrder") is not None:
                answer_keys_stripped = False
            if "correct_answer" in question or "correct_order" in question:
                answer_keys_stripped = False
    else:
        answer_keys_stripped = False

    if not answer_keys_stripped:
        blockers.append(f"DETAIL_ANSWER_KEYS: HN4-{lesson_ref.lesson_no:03d} did not strip answer keys for client detail")

    return DetailCheck(
        lesson_no=lesson_ref.lesson_no,
        lesson_id=lesson_ref.lesson_id,
        status="PASS" if not blockers else "FAIL",
        script_lines=script_count,
        questions=question_count,
        vocab_items=vocab_count,
        grammar_items=grammar_count,
        answer_keys_stripped=answer_keys_stripped,
        blockers=blockers,
    )


def build_report(
    *,
    api_base_url: str,
    level: str,
    account_label: str,
    chapters_payload: dict[str, Any],
    detail_payloads: dict[int, dict[str, Any]],
    expected_chapter_count: int,
    expected_lesson_count: int,
    expected_target_chapter_no: int,
    target_lesson_nos: list[int],
    expected_script_lines: int,
    expected_questions: int,
) -> RemoteLessonApiSmokeReport:
    chapter_count, lesson_count, target_lessons, blockers = validate_chapters(
        chapters_payload,
        expected_chapter_count=expected_chapter_count,
        expected_lesson_count=expected_lesson_count,
        expected_target_chapter_no=expected_target_chapter_no,
        target_lesson_nos=target_lesson_nos,
    )

    detail_checks: list[DetailCheck] = []
    for lesson_ref in target_lessons:
        payload = detail_payloads.get(lesson_ref.lesson_no)
        if payload is None:
            check = DetailCheck(
                lesson_no=lesson_ref.lesson_no,
                lesson_id=lesson_ref.lesson_id,
                status="FAIL",
                script_lines=0,
                questions=0,
                vocab_items=0,
                grammar_items=0,
                answer_keys_stripped=False,
                blockers=[f"DETAIL_MISSING: HN4-{lesson_ref.lesson_no:03d} detail payload was not fetched"],
            )
        else:
            check = validate_detail(
                payload,
                lesson_ref=lesson_ref,
                expected_script_lines=expected_script_lines,
                expected_questions=expected_questions,
            )
        detail_checks.append(check)
        blockers.extend(check.blockers)

    return RemoteLessonApiSmokeReport(
        generated_at=_utc_now(),
        api_base_url=api_base_url,
        level=level,
        account_label=account_label,
        status="PASS" if not blockers else "BLOCKED",
        chapter_count=chapter_count,
        lesson_count=lesson_count,
        target_lessons=target_lessons,
        detail_checks=detail_checks,
        blockers=blockers,
        assumptions=[
            "This smoke is read-only after password sign-in; it only calls published chapters and lesson detail APIs.",
            "It does not call lesson start, submit, or TTS generation endpoints.",
            "The authenticated account label is masked so rollout evidence does not expose credentials or tokens.",
        ],
    )


def _fetch_report(args: argparse.Namespace) -> RemoteLessonApiSmokeReport:
    env_paths = args.env_file or [REPO_ROOT / "apps/mobile/.env", API_DIR / ".env"]
    _load_env_defaults(env_paths)

    api_base_url = _normalize_base_url(args.api_base_url or os.environ.get("API_BASE_URL") or DEFAULT_API_BASE_URL)
    supabase_url = args.supabase_url or os.environ.get("SUPABASE_URL")
    supabase_anon_key = args.supabase_anon_key or os.environ.get("SUPABASE_ANON_KEY")
    email = args.email or os.environ.get("HARUKOTO_SMOKE_EMAIL")
    password = os.environ.get("HARUKOTO_SMOKE_PASSWORD")

    missing = [
        name
        for name, value in [
            ("SUPABASE_URL", supabase_url),
            ("SUPABASE_ANON_KEY", supabase_anon_key),
            ("HARUKOTO_SMOKE_EMAIL", email),
            ("HARUKOTO_SMOKE_PASSWORD", password),
        ]
        if not value
    ]
    if missing:
        raise SystemExit(f"Missing required configuration: {', '.join(missing)}")

    level = args.level.upper()
    target_lesson_nos = args.lesson_no or DEFAULT_TARGET_LESSONS
    with httpx.Client(timeout=args.timeout_seconds) as client:
        token = _sign_in(
            client,
            supabase_url=str(supabase_url),
            supabase_anon_key=str(supabase_anon_key),
            email=str(email),
            password=str(password),
        )
        auth_headers = {"Authorization": f"Bearer {token}"}
        chapters_payload = _request_json(
            client,
            "GET",
            f"{api_base_url}/api/v1/lessons/chapters?jlptLevel={level}",
            headers=auth_headers,
            json_body=None,
            label=f"{level.lower()}_lesson_chapters",
        )

        _, _, target_lessons, chapter_blockers = validate_chapters(
            chapters_payload,
            expected_chapter_count=args.expected_chapter_count,
            expected_lesson_count=args.expected_lesson_count,
            expected_target_chapter_no=args.expected_target_chapter_no,
            target_lesson_nos=target_lesson_nos,
        )
        detail_payloads: dict[int, dict[str, Any]] = {}
        if not chapter_blockers:
            for lesson in target_lessons:
                detail_payloads[lesson.lesson_no] = _request_json(
                    client,
                    "GET",
                    f"{api_base_url}/api/v1/lessons/{lesson.lesson_id}",
                    headers=auth_headers,
                    json_body=None,
                    label=f"lesson_detail_hn4_{lesson.lesson_no:03d}",
                )

    return build_report(
        api_base_url=api_base_url,
        level=level,
        account_label=_mask_email(str(email)),
        chapters_payload=chapters_payload,
        detail_payloads=detail_payloads,
        expected_chapter_count=args.expected_chapter_count,
        expected_lesson_count=args.expected_lesson_count,
        expected_target_chapter_no=args.expected_target_chapter_no,
        target_lesson_nos=target_lesson_nos,
        expected_script_lines=args.expected_script_lines,
        expected_questions=args.expected_questions,
    )


def _render_markdown(report: RemoteLessonApiSmokeReport) -> str:
    lines = [
        f"# {report.level} Target API Lesson Smoke",
        "",
        f"> Generated: {report.generated_at}",
        f"> Status: {report.status}",
        "> Boundary: authenticated read-only list/detail API smoke; no start, submit, or TTS generation calls",
        "",
        "## Target",
        "",
        f"- API base: `{report.api_base_url}`",
        f"- Account: `{report.account_label}`",
        f"- Chapters: `{report.chapter_count}`",
        f"- Lessons: `{report.lesson_count}`",
        "",
        "## Target Lessons",
        "",
        "| Lesson | Chapter | Chapter lesson | Title | Detail ID |",
        "|---|---:|---:|---|---|",
    ]
    for lesson in report.target_lessons:
        lines.append(
            f"| `HN4-{lesson.lesson_no:03d}` | {lesson.chapter_no or ''} | "
            f"{lesson.chapter_lesson_no or ''} | {lesson.title} | `{lesson.lesson_id}` |"
        )

    lines.extend(
        [
            "",
            "## Detail Checks",
            "",
            "| Lesson | Result | Script lines | Questions | Vocab items | Grammar items | Answer keys stripped |",
            "|---|---|---:|---:|---:|---:|---|",
        ]
    )
    for check in report.detail_checks:
        lines.append(
            f"| `HN4-{check.lesson_no:03d}` | {check.status} | {check.script_lines} | {check.questions} | "
            f"{check.vocab_items} | {check.grammar_items} | {'yes' if check.answer_keys_stripped else 'no'} |"
        )

    lines.extend(["", "## Blockers", ""])
    if report.blockers:
        lines.extend(f"- `{blocker}`" for blocker in report.blockers)
    else:
        lines.append("- None")

    lines.extend(["", "## Assumptions", ""])
    lines.extend(f"- {assumption}" for assumption in report.assumptions)
    lines.append("")
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run an authenticated read-only lesson list/detail smoke against a remote API.")
    parser.add_argument("--api-base-url", default=None)
    parser.add_argument("--supabase-url", default=None)
    parser.add_argument("--supabase-anon-key", default=None)
    parser.add_argument("--email", default=None)
    parser.add_argument("--env-file", action="append", type=Path, default=None)
    parser.add_argument("--level", default="N4")
    parser.add_argument("--lesson-no", action="append", type=int, default=None)
    parser.add_argument("--expected-chapter-count", type=int, default=4)
    parser.add_argument("--expected-lesson-count", type=int, default=16)
    parser.add_argument("--expected-target-chapter-no", type=int, default=4)
    parser.add_argument("--expected-script-lines", type=int, default=4)
    parser.add_argument("--expected-questions", type=int, default=5)
    parser.add_argument("--timeout-seconds", type=float, default=20.0)
    parser.add_argument("--markdown-output", type=Path, default=None)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--fail-on-blocker", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = _fetch_report(args)
    if args.markdown_output:
        args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_output.write_text(_render_markdown(report), encoding="utf-8")
    if args.json:
        print(json.dumps(asdict(report), ensure_ascii=False, indent=2))
    else:
        print(f"{report.level} target API smoke {report.status}: {report.lesson_count} lessons, {len(report.blockers)} blockers")
    if args.fail_on_blocker and report.blockers:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
