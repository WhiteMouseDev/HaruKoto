"""Require the critical real-PostgreSQL cases to execute successfully in CI."""

import argparse
import xml.etree.ElementTree as ET
from pathlib import Path

# Keep exact parameter IDs so deleting a regression or skipping one variant fails
# closed. Unrelated optional AI integration skips remain permitted.
REQUIRED_CASES = frozenset(
    {
        (
            "tests.test_lesson_review_targets_postgres",
            "test_seeded_first_lesson_updates_student_and_grammar_instead_of_display_order_words",
        ),
        (
            "tests.test_lesson_review_targets_postgres",
            "test_seed_adds_reviewed_non_core_target_and_preserves_intro_and_client_contract",
        ),
        (
            "tests.test_lesson_review_targets_postgres",
            "test_reviewed_exclusion_grades_without_fabricating_an_srs_answer",
        ),
        (
            "tests.test_lesson_review_targets_postgres",
            "test_invalid_lesson_mapping_keeps_existing_learning_records_unchanged[missing]",
        ),
        (
            "tests.test_lesson_review_targets_postgres",
            "test_invalid_lesson_mapping_keeps_existing_learning_records_unchanged[outside-lesson]",
        ),
        (
            "tests.test_lesson_review_targets_postgres",
            "test_invalid_lesson_mapping_keeps_existing_learning_records_unchanged[wrong-type]",
        ),
        (
            "tests.test_lesson_review_targets_postgres",
            "test_invalid_lesson_mapping_keeps_existing_learning_records_unchanged[conflicting]",
        ),
        (
            "tests.test_lesson_review_targets_postgres",
            "test_invalid_lesson_mapping_keeps_existing_learning_records_unchanged[malformed]",
        ),
        (
            "tests.test_lesson_review_targets_postgres",
            "test_invalid_lesson_mapping_keeps_existing_learning_records_unchanged[duplicate-link]",
        ),
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
        ("tests.test_review_event_partition_repair_postgres", "test_repair_preserves_records_security_boundaries_and_repeat_application"),
        ("tests.test_review_event_partition_repair_postgres", "test_repair_lock_timeout_rolls_back_and_allows_bounded_retry"),
        ("tests.test_review_event_partition_repair_postgres", "test_repair_preserves_auth_quiz_resume_and_atomic_lesson_srs_events"),
        ("tests.test_review_event_partition_repair_postgres", "test_repair_accepts_only_an_exact_existing_target_partition"),
        ("tests.test_review_event_partition_repair_postgres", "test_reviewed_offline_sql_replays_as_one_transaction"),
        (
            "tests.test_review_event_partition_repair_postgres",
            "test_repair_fails_atomically_on_conflicting_catalog_or_security[table-name]",
        ),
        ("tests.test_review_event_partition_repair_postgres", "test_repair_fails_atomically_on_conflicting_catalog_or_security[view-name]"),
        (
            "tests.test_review_event_partition_repair_postgres",
            "test_repair_fails_atomically_on_conflicting_catalog_or_security[wrong-bounds]",
        ),
        (
            "tests.test_review_event_partition_repair_postgres",
            "test_repair_fails_atomically_on_conflicting_catalog_or_security[unexpected-child]",
        ),
        (
            "tests.test_review_event_partition_repair_postgres",
            "test_repair_fails_atomically_on_conflicting_catalog_or_security[default-partition]",
        ),
        (
            "tests.test_review_event_partition_repair_postgres",
            "test_repair_fails_atomically_on_conflicting_catalog_or_security[wrong-owner]",
        ),
        (
            "tests.test_review_event_partition_repair_postgres",
            "test_repair_fails_atomically_on_conflicting_catalog_or_security[parent-rls]",
        ),
        ("tests.test_review_event_partition_repair_postgres", "test_repair_fails_atomically_on_conflicting_catalog_or_security[ddl-guard]"),
        (
            "tests.test_review_event_partition_repair_postgres",
            "test_repair_fails_atomically_on_conflicting_catalog_or_security[missing-index]",
        ),
        (
            "tests.test_review_event_partition_repair_postgres",
            "test_repair_fails_atomically_on_conflicting_catalog_or_security[column-privilege]",
        ),
        ("tests.test_review_partition_check_postgres", "test_healthy_check_is_catalog_only_and_preserves_learning_and_security"),
        ("tests.test_review_partition_check_postgres", "test_middle_gap_is_detected_even_with_later_future_partition"),
        ("tests.test_review_partition_check_postgres", "test_rolling_horizon_requires_february_on_november_first"),
        ("tests.test_review_partition_check_postgres", "test_valid_extra_future_partitions_are_accepted"),
        ("tests.test_review_partition_check_postgres", "test_minimal_catalog_role_cannot_read_learning_rows_or_execute_ddl"),
        ("tests.test_review_partition_check_postgres", "test_read_only_repeatable_snapshot_rejects_writes"),
        ("tests.test_review_partition_check_postgres", "test_connection_errors_are_sanitized"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[renamed]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[detached]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[wrong-bounds]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[default-partition]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[missing-index]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[parent-rls]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[child-rls]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[table-grant]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[column-grant]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[inherited-grant]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[public-grant]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[policy]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[ddl-guard]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[missing-placeholder]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[placeholder-grant]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[authenticator-override]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[database-override]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[missing-role]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[guard-search-path]"),
        ("tests.test_review_partition_check_postgres", "test_metadata_and_security_fail_closed[guard-tags]"),
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
