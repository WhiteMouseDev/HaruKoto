"""Require the critical real-PostgreSQL cases to execute successfully in CI."""

import argparse
import xml.etree.ElementTree as ET
from pathlib import Path

# Keep exact parameter IDs so deleting a regression or skipping one variant fails
# closed. Unrelated optional AI integration skips remain permitted.
REQUIRED_CASES = frozenset(
    {
        ("tests.test_quiz_answer_persistence_postgres", "test_missing_october_review_partition_does_not_erase_ten_correct_answers[normal]"),
        ("tests.test_quiz_answer_persistence_postgres", "test_missing_october_review_partition_does_not_erase_ten_correct_answers[smart]"),
        (
            "tests.test_quiz_answer_persistence_postgres",
            "test_unfinished_legacy_duplicates_use_first_answers_and_preserve_completed_results",
        ),
        ("tests.test_quiz_answer_persistence_postgres", "test_parallel_answers_and_retries_are_counted_once_and_completion_waits"),
        ("tests.test_quiz_answer_persistence_postgres", "test_legacy_naive_timestamp_session_can_be_found_resumed_and_completed[list]"),
        ("tests.test_quiz_answer_persistence_postgres", "test_legacy_naive_timestamp_session_can_be_found_resumed_and_completed[smart]"),
        ("tests.test_smart_quiz_distractor_postgres", "test_smart_start_reads_distractor_candidates_and_seen_ids_once[2]"),
        ("tests.test_smart_quiz_distractor_postgres", "test_smart_start_reads_distractor_candidates_and_seen_ids_once[10]"),
        (
            "tests.test_public_access_hardening_postgres",
            "test_public_boundary_migration_preserves_server_auth_and_learning_and_blocks_clients",
        ),
        (
            "tests.test_empty_postgrest_schema_postgres",
            "test_empty_postgrest_schema_is_fail_closed_and_preserves_auth_and_learning",
        ),
    }
)


def check_report(report_path: Path) -> list[str]:
    """Return CI failures for absent, duplicated, skipped, or failing cases."""
    try:
        root = ET.parse(report_path).getroot()
    except (OSError, ET.ParseError) as error:
        return [f"Cannot read pytest JUnit report: {error}"]

    results: dict[tuple[str, str], list[ET.Element]] = {case: [] for case in REQUIRED_CASES}
    for testcase in root.iter("testcase"):
        key = (testcase.get("classname", ""), testcase.get("name", ""))
        if key in results:
            results[key].append(testcase)

    errors = []
    for (classname, name), cases in sorted(results.items()):
        case_id = f"{classname}::{name}"
        if len(cases) != 1:
            errors.append(f"{case_id}: expected exactly one result, found {len(cases)}")
            continue
        for result in cases[0]:
            if result.tag in {"skipped", "failure", "error"}:
                errors.append(f"{case_id}: reported {result.tag}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path, help="pytest --junitxml output")
    args = parser.parse_args()
    errors = check_report(args.report)
    if errors:
        for error in errors:
            print(f"::error::{error}")
        return 1
    print(f"All {len(REQUIRED_CASES)} required PostgreSQL regression cases passed without skips.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
