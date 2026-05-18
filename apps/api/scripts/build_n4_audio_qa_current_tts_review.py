from __future__ import annotations

import argparse
import asyncio
import csv
from contextlib import AbstractAsyncContextManager
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import async_session_factory
from app.models.tts import TtsAudio
from scripts.audit_n4_flag_post_regeneration_audio import APPLY_CSV_COLUMNS
from scripts.build_n4_audio_qa_review_queue import _display_path
from scripts.regenerate_n4_audio_qa_flagged_tts import RESULT_COLUMNS

DEFAULT_PRIORITY = "P0_MACHINE_WARNING_PROVIDER_FALLBACK_POST_REGEN_REVIEW"
DEFAULT_NOTES = "P0 machine-warning provider fallback TTS resolved to current DB audio; run STT-assisted audit before setting PASS or FLAG."
MANIFEST_REQUIRED_COLUMNS = {
    "target_key",
    "packet",
    "target_type",
    "field",
    "target_id",
    "source_text",
    "korean_context",
    "review_signals",
    "current_audio_url",
    "current_verdict",
    "current_notes",
}
GCS_PUBLIC_PREFIX = "https://storage.googleapis.com/harukoto-storage/"


class SessionFactory(Protocol):
    def __call__(self) -> AbstractAsyncContextManager[AsyncSession]: ...


@dataclass(frozen=True)
class ManifestReviewItem:
    target_key: str
    packet: str
    target_type: str
    field: str
    target_id: str
    source_text: str
    korean_context: str
    review_signals: str
    current_audio_url: str
    current_verdict: str
    current_notes: str


@dataclass(frozen=True)
class CurrentTtsRecord:
    target_type: str
    target_id: str
    field: str
    text: str
    provider: str
    model: str
    audio_url: str


@dataclass(frozen=True)
class CurrentTtsReviewRow:
    item: ManifestReviewItem
    record: CurrentTtsRecord
    priority: str
    notes: str


def read_manifest_items(csv_input: Path, *, current_verdicts: set[str] | None = None) -> list[ManifestReviewItem]:
    allowed_verdicts = current_verdicts or {"PENDING"}
    items: list[ManifestReviewItem] = []
    seen_target_keys: set[str] = set()
    seen_target_ids: set[str] = set()

    with csv_input.open("r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)
        missing_columns = MANIFEST_REQUIRED_COLUMNS - set(reader.fieldnames or [])
        if missing_columns:
            raise ValueError(f"manifest is missing required columns: {', '.join(sorted(missing_columns))}")

        for row_number, row in enumerate(reader, start=2):
            verdict = (row.get("current_verdict") or "").strip().upper()
            if verdict not in allowed_verdicts:
                continue

            item = ManifestReviewItem(
                target_key=(row.get("target_key") or "").strip(),
                packet=(row.get("packet") or "").strip(),
                target_type=(row.get("target_type") or "").strip(),
                field=(row.get("field") or "").strip(),
                target_id=(row.get("target_id") or "").strip(),
                source_text=(row.get("source_text") or "").strip(),
                korean_context=(row.get("korean_context") or "").strip(),
                review_signals=(row.get("review_signals") or "").strip(),
                current_audio_url=(row.get("current_audio_url") or "").strip(),
                current_verdict=verdict,
                current_notes=(row.get("current_notes") or "").strip(),
            )
            missing_values = [
                name
                for name, value in {
                    "target_key": item.target_key,
                    "packet": item.packet,
                    "target_type": item.target_type,
                    "field": item.field,
                    "target_id": item.target_id,
                    "source_text": item.source_text,
                    "current_audio_url": item.current_audio_url,
                }.items()
                if not value
            ]
            if missing_values:
                raise ValueError(f"row {row_number}: missing required values: {', '.join(missing_values)}")
            if item.target_key in seen_target_keys:
                raise ValueError(f"row {row_number}: duplicate target_key {item.target_key!r}")
            if item.target_id in seen_target_ids:
                raise ValueError(f"row {row_number}: duplicate target_id {item.target_id!r}")

            seen_target_keys.add(item.target_key)
            seen_target_ids.add(item.target_id)
            items.append(item)

    return items


async def fetch_current_tts_records(
    items: list[ManifestReviewItem],
    *,
    session_factory: SessionFactory = async_session_factory,
) -> dict[str, CurrentTtsRecord]:
    records: dict[str, CurrentTtsRecord] = {}
    async with session_factory() as session:
        for item in items:
            result = await session.execute(
                select(TtsAudio).where(
                    TtsAudio.target_type == item.target_type,
                    TtsAudio.target_id == item.target_id,
                    TtsAudio.speed == 1.0,
                    TtsAudio.field == item.field,
                )
            )
            record = result.scalar_one_or_none()
            if record is None:
                raise ValueError(f"current tts_audio row not found for {item.target_key}: {item.target_id}")
            records[item.target_id] = CurrentTtsRecord(
                target_type=record.target_type,
                target_id=record.target_id,
                field=record.field,
                text=record.text,
                provider=record.provider,
                model=record.model,
                audio_url=record.audio_url,
            )
    return records


def build_review_rows(
    items: list[ManifestReviewItem],
    records_by_target_id: dict[str, CurrentTtsRecord],
    *,
    priority: str = DEFAULT_PRIORITY,
    notes: str = DEFAULT_NOTES,
    require_regenerated_url: bool = True,
) -> list[CurrentTtsReviewRow]:
    rows: list[CurrentTtsReviewRow] = []
    for item in items:
        record = records_by_target_id.get(item.target_id)
        if record is None:
            raise ValueError(f"current TTS record missing for {item.target_key}: {item.target_id}")
        if record.text != item.source_text:
            raise ValueError(
                f"{item.target_key}: current TTS text {record.text!r} does not match manifest source_text {item.source_text!r}"
            )
        if record.target_type != item.target_type or record.field != item.field:
            raise ValueError(f"{item.target_key}: current TTS target metadata does not match manifest")
        if require_regenerated_url:
            if record.audio_url == item.current_audio_url:
                raise ValueError(f"{item.target_key}: current DB audio_url still matches manifest current_audio_url")
            if "-regen-" not in record.audio_url:
                raise ValueError(f"{item.target_key}: current DB audio_url does not look regenerated: {record.audio_url}")

        rows.append(CurrentTtsReviewRow(item=item, record=record, priority=priority, notes=notes))
    return rows


def _review_signal_text(item: ManifestReviewItem) -> str:
    if item.review_signals:
        return f"PROVIDER_FALLBACK_REGENERATED, {item.review_signals}"
    return "PROVIDER_FALLBACK_REGENERATED"


def _gcs_path_from_url(audio_url: str) -> str:
    if audio_url.startswith(GCS_PUBLIC_PREFIX):
        return audio_url.removeprefix(GCS_PUBLIC_PREFIX)
    return ""


def write_review_csv(csv_output: Path, rows: list[CurrentTtsReviewRow]) -> int:
    csv_output.parent.mkdir(parents=True, exist_ok=True)
    with csv_output.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=APPLY_CSV_COLUMNS, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    "target_key": row.item.target_key,
                    "packet": row.item.packet,
                    "priority": row.priority,
                    "review_signals": _review_signal_text(row.item),
                    "japanese_text": row.item.source_text,
                    "korean_context": row.item.korean_context,
                    "provider_model": f"{row.record.provider} / {row.record.model}",
                    "audio_url": row.record.audio_url,
                    "current_verdict": row.item.current_verdict,
                    "current_notes": row.item.current_notes or row.notes,
                    "new_verdict": "",
                    "new_notes": "",
                }
            )
    return len(rows)


def write_regeneration_results_csv(csv_output: Path, rows: list[CurrentTtsReviewRow]) -> int:
    csv_output.parent.mkdir(parents=True, exist_ok=True)
    with csv_output.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=RESULT_COLUMNS, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    "target_key": row.item.target_key,
                    "target_id": row.item.target_id,
                    "source_text": row.item.source_text,
                    "current_audio_url": row.item.current_audio_url,
                    "status": "regenerated",
                    "gcs_path": _gcs_path_from_url(row.record.audio_url),
                    "old_audio_url": row.item.current_audio_url,
                    "new_audio_url": row.record.audio_url,
                    "provider": row.record.provider,
                    "model": row.record.model,
                    "error": "",
                }
            )
    return len(rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build post-regeneration review CSVs from current N4 TTS DB rows.")
    parser.add_argument("--manifest", type=Path, required=True, help="Regeneration manifest CSV path.")
    parser.add_argument("--current-verdict", action="append", default=None, help="Include this manifest verdict. Defaults to PENDING.")
    parser.add_argument("--priority", default=DEFAULT_PRIORITY, help="Priority label for the review CSV.")
    parser.add_argument("--notes", default=DEFAULT_NOTES, help="Fallback current_notes when manifest notes are blank.")
    parser.add_argument(
        "--allow-original-url",
        action="store_true",
        help="Allow current DB audio_url to match the manifest current_audio_url. Default requires a regenerated URL.",
    )
    parser.add_argument("--review-csv-output", type=Path, required=True, help="Audit-compatible post-regeneration review CSV output.")
    parser.add_argument("--regeneration-results-output", type=Path, required=True, help="Audit-compatible regeneration results CSV output.")
    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    items = read_manifest_items(
        args.manifest,
        current_verdicts={verdict.upper() for verdict in args.current_verdict} if args.current_verdict else None,
    )
    records = await fetch_current_tts_records(items)
    rows = build_review_rows(
        items,
        records,
        priority=args.priority,
        notes=args.notes,
        require_regenerated_url=not args.allow_original_url,
    )
    review_count = write_review_csv(args.review_csv_output, rows)
    result_count = write_regeneration_results_csv(args.regeneration_results_output, rows)
    print(f"current_tts_review_csv {_display_path(args.review_csv_output)} rows={review_count}")
    print(f"current_tts_regeneration_results_csv {_display_path(args.regeneration_results_output)} rows={result_count}")


if __name__ == "__main__":
    asyncio.run(main())
