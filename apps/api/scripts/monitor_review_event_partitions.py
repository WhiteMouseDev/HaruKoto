"""Run the catalog-only inspector with acknowledged Sentry Cron check-ins.

DATABASE_URL and SENTRY_DSN must be injected into the process environment.
ENVIRONMENT defaults to production. Does not load .env or upsert a monitor.
Exit codes: 0=OK, 1=ADVISORY, 2=ERROR, 3=UNKNOWN or monitoring delivery failure.
The Cloud Run Job must enforce its own outer task deadline (at most 120s).
"""

from __future__ import annotations

import argparse
import json
import os
import signal
import sys
from datetime import datetime
from pathlib import Path
from types import FrameType
from typing import NoReturn

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.review_partition_monitor import monitor_configuration_error, run_partition_monitor
from scripts.check_review_event_partitions import SafeArgumentParser


def _interrupt(signum: int, frame: FrameType | None) -> NoReturn:
    raise KeyboardInterrupt


def main(arguments: list[str] | None = None) -> int:
    parser = SafeArgumentParser(description=__doc__)
    parser.add_argument("--monitor-slug", required=True, help="Existing Sentry Cron monitor slug; no automatic monitor creation.")
    parser.add_argument(
        "--as-of",
        metavar="AWARE_ISO_TIMESTAMP",
        help="Evaluate future coverage for a notification rehearsal; use a separate test monitor.",
    )
    try:
        args = parser.parse_args(arguments)
        timestamp = datetime.fromisoformat(args.as_of) if args.as_of is not None else None
    except (ValueError, argparse.ArgumentError, OverflowError):
        result = monitor_configuration_error("ARGUMENTS_INVALID")
    else:
        previous_alarm = signal.signal(signal.SIGALRM, _interrupt)
        previous_term = signal.signal(signal.SIGTERM, _interrupt)
        previous_timer = signal.setitimer(signal.ITIMER_REAL, 60)
        try:
            result = run_partition_monitor(
                os.environ.get("DATABASE_URL", ""),
                os.environ.get("SENTRY_DSN", ""),
                args.monitor_slug,
                environment=os.environ.get("ENVIRONMENT", "production"),
                as_of=timestamp,
            )
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, previous_alarm)
            signal.signal(signal.SIGTERM, previous_term)
            signal.setitimer(signal.ITIMER_REAL, *previous_timer)
    print(json.dumps(result.to_dict(), ensure_ascii=False, sort_keys=True))
    return result.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
