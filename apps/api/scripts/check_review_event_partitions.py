"""Catalog-only review-event coverage check.

Requires DATABASE_URL already in the process environment; never loads .env.
Exit codes: 0=OK, 1=ADVISORY, 2=ERROR, 3=UNKNOWN (including invalid input).
No HTTP endpoint, DDL, data reads or automatic remediation is performed.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
from datetime import UTC, datetime
from pathlib import Path

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.review_partition_check import inspect_review_partitions, unknown_result, validate_as_of


class SafeArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> None:
        raise ValueError("Invalid arguments")


def main(arguments: list[str] | None = None) -> int:
    parser = SafeArgumentParser(description=__doc__)
    parser.add_argument(
        "--as-of", metavar="AWARE_ISO_TIMESTAMP", help="Evaluate the catalog at an explicit aware timestamp (testing only)."
    )
    try:
        args = parser.parse_args(arguments)
        timestamp = validate_as_of(datetime.fromisoformat(args.as_of)) if args.as_of is not None else datetime.now(UTC)
    except (ValueError, argparse.ArgumentError, OverflowError):
        result = unknown_result(
            datetime.now(UTC), "ARGUMENTS_INVALID", "Arguments require an aware ISO timestamp within the inspection range."
        )
    else:
        database_url = os.environ.get("DATABASE_URL", "")
        if not database_url:
            result = unknown_result(timestamp, "DATABASE_URL_MISSING", "DATABASE_URL must already be set in the process environment.")
        else:
            result = asyncio.run(inspect_review_partitions(database_url, as_of=timestamp))
    print(json.dumps(result.to_dict(), ensure_ascii=False, sort_keys=True))
    return result.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
