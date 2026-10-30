"""Require the critical real-PostgreSQL cases to execute successfully in CI."""

import argparse
import xml.etree.ElementTree as ET
from pathlib import Path

# Keep exact parameter IDs so deleting a regression or skipping one variant fails
# closed. Unrelated optional AI integration skips remain permitted.
REQUIRED_CASES = frozenset(
    {
        *{
            (
                "tests.test_special_quiz_resume_postgres",
                f"test_free_matching_uses_requested_level_and_cold_resume_keeps_first_answers_and_records[{category}]",
            )
            for category in ("VOCABULARY", "GRAMMAR")
        },
        *{
            (
                "tests.test_special_quiz_resume_postgres",
                f"test_stage_matching_keeps_content_id_scope_when_level_pool_has_other_items[{category}]",
            )
            for category in ("VOCABULARY", "GRAMMAR")
        },
        *{
            (
                "tests.test_special_quiz_resume_postgres",
                f"test_unsupported_free_matching_rolls_back_pending_completion_and_xp[{category}]",
            )
            for category in ("KANJI", "LISTENING", "SENTENCE_ARRANGE", "CLOZE")
        },
        *{
            (
                "tests.test_special_quiz_resume_postgres",
                f"test_conflicting_stage_matching_category_rolls_back_pending_completion_and_xp[{category}]",
            )
            for category in ("VOCABULARY", "GRAMMAR")
        },
        *{
            (
                "tests.test_special_quiz_resume_postgres",
                f"test_special_start_partial_resume_keeps_snapshot_saved_right_and_wrong_and_completes_once[{category}-{mode}]",
            )
            for category, mode in (
                ("VOCABULARY", "matching"),
                ("GRAMMAR", "matching"),
                ("SENTENCE", "matching"),
                ("SENTENCE", "arrange"),
            )
        },
        *{
            (
                "tests.test_special_quiz_resume_postgres",
                f"test_legacy_special_snapshots_resume_without_backfill_or_review_date_changes[{envelope}-{category}-{mode}]",
            )
            for envelope in ("array", "stage-envelope")
            for category, mode in (("VOCABULARY", "matching"), ("GRAMMAR", "matching"), ("SENTENCE", "arrange"))
        },
        *{
            (
                "tests.test_special_quiz_resume_postgres",
                f"test_unavailable_special_session_returns_409_without_mutating_learning_or_backfilling[{mutation}]",
            )
            for mutation in (
                "missing-japanese",
                "missing-side",
                "mixed-mode",
                "duplicate-id",
                "unknown-mode",
                "foreign-answer",
                "wrong-grade",
                "foreign-pair",
            )
        },
        *{
            (
                "tests.test_special_quiz_resume_postgres",
                f"test_study_capabilities_reads_text_and_enum_chapter_levels_without_rewriting_records[{storage}]",
            )
            for storage in ("text", "enum")
        },
        (
            "tests.test_special_quiz_resume_postgres",
            "test_special_retries_concurrent_answers_and_completion_apply_srs_and_xp_once",
        ),
        (
            "tests.test_special_quiz_resume_postgres",
            "test_legacy_duplicate_special_answers_keep_first_grade_and_no_read_side_effects",
        ),
        *{
            (
                "tests.test_special_quiz_resume_postgres",
                f"test_legacy_arrange_category_conflict_is_unavailable_without_regrading_or_srs_rewrite[{category}]",
            )
            for category in ("VOCABULARY", "GRAMMAR")
        },
        *{
            (
                "tests.test_special_quiz_resume_postgres",
                f"test_invalid_new_arrange_category_rolls_back_pending_auto_completion_and_xp[{category}]",
            )
            for category in ("VOCABULARY", "GRAMMAR")
        },
        *{
            (
                "tests.test_review_event_february_partition_postgres",
                f"test_february_preserves_existing_rows_security_and_routes_exact_utc_boundaries[{timezone}]",
            )
            for timezone in ("utc", "korea", "los-angeles")
        },
        (
            "tests.test_review_event_february_partition_postgres",
            "test_february_preserves_auth_saved_answers_and_partial_quiz_resume",
        ),
        (
            "tests.test_review_event_february_partition_postgres",
            "test_february_accepts_exact_existing_target_and_concurrent_reapplication",
        ),
        (
            "tests.test_review_event_february_partition_postgres",
            "test_february_lock_timeout_rolls_back_and_allows_bounded_retry",
        ),
        (
            "tests.test_review_event_february_partition_postgres",
            "test_february_offline_sql_is_atomic_and_downgrade_never_drops_data",
        ),
        *{
            (
                "tests.test_review_event_february_partition_postgres",
                f"test_february_rejects_conflicting_catalog_or_security_without_repairing_old_objects[{mutation}]",
            )
            for mutation in (
                "table-name",
                "view-name",
                "wrong-bounds",
                "unexpected-child",
                "default-partition",
                "wrong-owner",
                "parent-rls",
                "old-child-rls",
                "ddl-guard",
                "guard-search-path",
                "guard-tags",
                "missing-index",
                "column-privilege",
                "old-column-privilege",
                "public-privilege",
                "historical-gap",
                "target-rls",
                "target-privilege",
                "target-column-privilege",
                "target-owner",
            )
        },
        (
            "tests.test_stats_vocabulary_goal_postgres",
            "test_dashboard_vocabulary_goal_counts_distinct_saved_words_by_kst_answer_day[aware-korea]",
        ),
        (
            "tests.test_stats_vocabulary_goal_postgres",
            "test_dashboard_vocabulary_goal_counts_distinct_saved_words_by_kst_answer_day[aware-los-angeles]",
        ),
        (
            "tests.test_stats_vocabulary_goal_postgres",
            "test_dashboard_vocabulary_goal_counts_distinct_saved_words_by_kst_answer_day[legacy-korea]",
        ),
        (
            "tests.test_stats_vocabulary_goal_postgres",
            "test_dashboard_vocabulary_goal_counts_distinct_saved_words_by_kst_answer_day[legacy-los-angeles]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_wrong_review_uses_only_source_wrong_items_and_preserves_existing_records[VOCABULARY]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_wrong_review_uses_only_source_wrong_items_and_preserves_existing_records[GRAMMAR]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_wrong_review_uses_only_source_wrong_items_and_preserves_existing_records[KANJI]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_wrong_review_uses_only_source_wrong_items_and_preserves_existing_records[LISTENING]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_concurrent_wrong_review_starts_and_lost_response_retries_reuse_one_active_session",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_wrong_review_partial_resume_and_completion_apply_new_answers_once_without_stage_completion[VOCABULARY]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_wrong_review_partial_resume_and_completion_apply_new_answers_once_without_stage_completion[GRAMMAR]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_legacy_first_answers_and_snapshot_order_match_wrong_answer_display",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_invalid_wrong_review_source_fails_without_changing_learning_records[missing]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_invalid_wrong_review_source_fails_without_changing_learning_records[foreign]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_invalid_wrong_review_source_fails_without_changing_learning_records[unfinished]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_invalid_wrong_review_source_fails_without_changing_learning_records[partial]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_invalid_wrong_review_source_fails_without_changing_learning_records[no-wrong]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_invalid_wrong_review_source_fails_without_changing_learning_records[deleted-content]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_invalid_wrong_review_source_fails_without_changing_learning_records[bad-snapshot]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_invalid_wrong_review_source_fails_without_changing_learning_records[answer-type]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_invalid_wrong_review_source_fails_without_changing_learning_records[wrong-grade]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_invalid_wrong_review_source_fails_without_changing_learning_records[unknown-option]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_special_quiz_source_is_explicitly_unsupported_without_general_review_fallback[KANA]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_special_quiz_source_is_explicitly_unsupported_without_general_review_fallback[CLOZE]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_special_quiz_source_is_explicitly_unsupported_without_general_review_fallback[SENTENCE_ARRANGE]",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_completed_wrong_review_can_be_the_source_of_its_own_remaining_wrong_items",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_existing_general_start_policy_can_close_a_wrong_review_then_explicit_retry_creates_a_new_attempt",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_existing_incomplete_timeout_policy_remains_unchanged_for_wrong_reviews",
        ),
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
