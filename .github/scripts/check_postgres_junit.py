"""Require the critical real-PostgreSQL cases to execute successfully in CI."""

import argparse
import xml.etree.ElementTree as ET
from pathlib import Path

# Keep exact parameter IDs so deleting a regression or skipping one variant fails
# closed. Unrelated optional AI integration skips remain permitted.
REQUIRED_CASES = frozenset(
    {
        *{
            ("tests.test_quiz_study_day_credit_postgres", name)
            for name in (
                "test_delayed_completion_rewards_once_without_new_day_goal_srs_or_replay_effect",
                "test_late_completion_preserves_preexisting_day_before_adding_rewards[empty-legacy]",
                "test_late_completion_preserves_preexisting_day_before_adding_rewards[positive-legacy]",
                "test_late_completion_preserves_preexisting_day_before_adding_rewards[existing-false]",
                "test_late_completion_preserves_preexisting_day_before_adding_rewards[existing-true]",
                "test_compatible_off_keeps_false_then_actual_answer_promotes_true",
                "test_compatible_off_completion_preserves_credit_decisions[new-day-keeps-legacy-credit]",
                "test_compatible_off_completion_preserves_credit_decisions[stored-false-preserved]",
                "test_compatible_off_completion_preserves_credit_decisions[stored-true-preserved]",
                "test_delayed_completion_and_fresh_answer_share_lock_without_credit_demotion[completion-first]",
                "test_delayed_completion_and_fresh_answer_share_lock_without_credit_demotion[answer-first]",
                "test_completion_credit_commit_failure_and_result_recovery_are_atomic[before-commit]",
                "test_completion_credit_commit_failure_and_result_recovery_are_atomic[response-lost]",
                "test_other_genuine_activity_writers_promote_false_without_losing_rewards[lesson]",
                "test_other_genuine_activity_writers_promote_false_without_losing_rewards[kana-answer]",
                "test_other_genuine_activity_writers_promote_false_without_losing_rewards[kana-quiz]",
                "test_other_genuine_activity_writers_promote_false_without_losing_rewards[kana-stage]",
                "test_other_genuine_activity_writers_promote_false_without_losing_rewards[kana-progress]",
                "test_other_genuine_activity_writers_promote_false_without_losing_rewards[conversation]",
                "test_recorded_credit_decisions_block_destructive_migration_rollback",
                "test_newer_duplicate_answer_does_not_create_completion_day_or_inflate_time",
            )
        },
        (
            "tests.test_lesson_study_day_postgres",
            "test_completion_credit_migration_is_nullable_private_and_keeps_legacy",
        ),
        *{
            ("tests.test_quiz_retention_postgres", name)
            for name in (
                "test_old_quiz_listing_and_cold_resume_do_not_change_any_learning_record[before-24h]",
                "test_old_quiz_listing_and_cold_resume_do_not_change_any_learning_record[exact-24h]",
                "test_old_quiz_listing_and_cold_resume_do_not_change_any_learning_record[after-24h]",
                "test_old_quiz_listing_and_cold_resume_do_not_change_any_learning_record[3-days]",
                "test_old_quiz_listing_and_cold_resume_do_not_change_any_learning_record[7-days]",
                "test_old_quiz_listing_and_cold_resume_do_not_change_any_learning_record[30-days]",
                "test_starting_another_regular_or_smart_quiz_preserves_saved_answers_srs_and_xp",
                "test_eligibility_before_limit_cursor_ties_filter_validation_and_owner_scope",
                "test_deleted_pending_catalogue_returns_preserving_conflict_but_saved_retry_stays_valid",
                "test_concurrent_completion_waits_for_answers_and_old_result_uses_saved_seconds_only",
                "test_complete_before_last_answer_is_retryable_and_does_not_close_session",
                "test_malformed_snapshot_rejects_new_writes_but_preserves_saved_answer_retry[legacy-question-id]",
                "test_malformed_snapshot_rejects_new_writes_but_preserves_saved_answer_retry[non-list]",
                "test_malformed_snapshot_rejects_new_writes_but_preserves_saved_answer_retry[non-object]",
                "test_completed_result_replay_does_not_require_unchanged_snapshot",
            )
        },
        *{
            ("tests.test_live_session_postgres", name)
            for name in (
                "test_parallel_start_and_lost_response_retry_share_one_persisted_session",
                "test_finish_concurrency_and_response_loss_award_and_count_once",
                "test_record_is_visible_and_unlocked_while_feedback_is_still_running",
                "test_completion_failure_rolls_back_without_false_saved_success",
                "test_ineligible_calls_are_saved_without_xp_and_only_connected_time_counts[0-]",
                "test_ineligible_calls_are_saved_without_xp_and_only_connected_time_counts[10-\\u3053\\u3093\\u306b\\u3061\\u306f]",
                "test_ineligible_calls_are_saved_without_xp_and_only_connected_time_counts[30-]",
                "test_parallel_expression_saves_preserve_personal_note_and_translation",
                "test_text_hotel_practice_persists_between_requests_and_keeps_roles",
                "test_live_completion_preserves_user_first_lock_order_and_existing_study_day",
                "test_completed_count_and_character_stats_require_actual_user_speech[json-null]",
                "test_completed_count_and_character_stats_require_actual_user_speech[legacy-object]",
                "test_completed_count_and_character_stats_require_actual_user_speech[empty]",
                "test_completed_count_and_character_stats_require_actual_user_speech[assistant-only]",
                "test_completed_count_and_character_stats_require_actual_user_speech[whitespace]",
                "test_completed_count_and_character_stats_require_actual_user_speech[missing-text]",
                "test_completed_count_and_character_stats_require_actual_user_speech[null-text]",
                "test_completed_count_and_character_stats_require_actual_user_speech[numeric-text]",
                "test_completed_count_and_character_stats_require_actual_user_speech[array-role]",
                "test_completed_count_and_character_stats_require_actual_user_speech[nested-array]",
                "test_completed_count_and_character_stats_require_actual_user_speech[invalid-items]",
                "test_completed_count_and_character_stats_require_actual_user_speech[user-japanese]",
                "test_completed_count_and_character_stats_require_actual_user_speech[user-korean]",
            )
        },
        *{
            ("tests.test_study_write_stop_integration_postgres", name)
            for name in (
                "test_p6_stop_preserves_existing_markers_receipts_history_and_security[feature-off]",
                "test_p6_stop_preserves_existing_markers_receipts_history_and_security[feature-on]",
                "test_p6_stop_allows_login_audio_receipt_get_and_reopens_same_activity_and_submission_ids[feature-off]",
                "test_p6_stop_allows_login_audio_receipt_get_and_reopens_same_activity_and_submission_ids[feature-on]",
                "test_p6_stop_rejects_before_mutex_then_reopens_concurrent_activity_and_submission_retries_once",
            )
        },
        *{
            ("tests.test_kana_completion_safety_postgres", name)
            for name in (
                "test_tagged_kana_completion_requires_all_durable_answers[no-answers-recognition-off]",
                "test_tagged_kana_completion_requires_all_durable_answers[no-answers-recognition-on]",
                "test_tagged_kana_completion_requires_all_durable_answers[partial-answers-recognition-off]",
                "test_tagged_kana_completion_requires_all_durable_answers[partial-answers-recognition-on]",
                "test_quiz_replay_next_day_preserves_original_completion_and_rewards[legacy-untagged]",
                "test_quiz_replay_next_day_preserves_original_completion_and_rewards[receipt-tagged]",
                "test_concurrent_kana_completion_applies_rewards_once[quiz]",
                "test_concurrent_kana_completion_applies_rewards_once[stage]",
                "test_completion_failure_rolls_back_state_and_retry_is_safe[daily-before-quiz]",
                "test_completion_failure_rolls_back_state_and_retry_is_safe[daily-before-stage]",
                "test_completion_failure_rolls_back_state_and_retry_is_safe[daily-after-quiz]",
                "test_completion_failure_rolls_back_state_and_retry_is_safe[daily-after-stage]",
                "test_completion_failure_rolls_back_state_and_retry_is_safe[commit-before-quiz]",
                "test_completion_failure_rolls_back_state_and_retry_is_safe[commit-before-stage]",
                "test_completion_response_loss_replays_without_new_day_or_reward[quiz]",
                "test_completion_response_loss_replays_without_new_day_or_reward[stage]",
                "test_stage_replay_keeps_score_timestamp_and_existing_unlock",
                "test_completed_legacy_quiz_does_not_require_new_receipts_or_repair_history",
                "test_new_tagged_quiz_grades_receipts_and_preserves_goal_due_and_security",
                "test_tagged_completion_fails_closed_for_inconsistent_evidence[mixed-version]",
                "test_tagged_completion_fails_closed_for_inconsistent_evidence[duplicate-question]",
                "test_tagged_completion_fails_closed_for_inconsistent_evidence[changed-source]",
                "test_tagged_completion_fails_closed_for_inconsistent_evidence[bad-receipt]",
            )
        },
        (
            "tests.test_weekly_vocabulary_projection_postgres",
            "test_weekly_projection_groups_saved_wrong_words_without_mutating_attendance_or_history[aware-kst-month-boundary]",
        ),
        (
            "tests.test_weekly_vocabulary_projection_postgres",
            "test_weekly_projection_groups_saved_wrong_words_without_mutating_attendance_or_history[aware-kst-year-boundary]",
        ),
        (
            "tests.test_weekly_vocabulary_projection_postgres",
            "test_weekly_projection_groups_saved_wrong_words_without_mutating_attendance_or_history[aware-la-month-boundary]",
        ),
        (
            "tests.test_weekly_vocabulary_projection_postgres",
            "test_weekly_projection_groups_saved_wrong_words_without_mutating_attendance_or_history[aware-la-year-boundary]",
        ),
        (
            "tests.test_weekly_vocabulary_projection_postgres",
            "test_weekly_projection_groups_saved_wrong_words_without_mutating_attendance_or_history[legacy-kst-month-boundary]",
        ),
        (
            "tests.test_weekly_vocabulary_projection_postgres",
            "test_weekly_projection_groups_saved_wrong_words_without_mutating_attendance_or_history[legacy-kst-year-boundary]",
        ),
        (
            "tests.test_weekly_vocabulary_projection_postgres",
            "test_weekly_projection_groups_saved_wrong_words_without_mutating_attendance_or_history[legacy-la-month-boundary]",
        ),
        (
            "tests.test_weekly_vocabulary_projection_postgres",
            "test_weekly_projection_groups_saved_wrong_words_without_mutating_attendance_or_history[legacy-la-year-boundary]",
        ),
        *{
            ("tests.test_lesson_study_day_postgres", name)
            for name in (
                "test_marker_migration_keeps_old_columns_private_and_rejects_existing_marker",
                "test_existing_trusted_service_role_grants_survive_without_reopening_clients",
                "test_preexisting_receipt_replay_never_backfills_a_study_day",
                "test_new_quiz_start_preserves_saved_session_during_conversation_reward[start-first]",
                "test_new_quiz_start_preserves_saved_session_during_conversation_reward[conversation-first]",
                "test_stage_timestamp_upserts_work_on_unchanged_not_null_schema",
                "test_first_lesson_answer_records_day_without_grading_srs_xp_or_goal[correct-RECOGNITION]",
                "test_first_lesson_answer_records_day_without_grading_srs_xp_or_goal[correct-SENTENCE_REORDER]",
                "test_first_lesson_answer_records_day_without_grading_srs_xp_or_goal[correct-MATCHING]",
                "test_first_lesson_answer_records_day_without_grading_srs_xp_or_goal[valid-wrong-RECOGNITION]",
                "test_first_lesson_answer_records_day_without_grading_srs_xp_or_goal[valid-wrong-SENTENCE_REORDER]",
                "test_first_lesson_answer_records_day_without_grading_srs_xp_or_goal[valid-wrong-MATCHING]",
                "test_activity_replays_next_day_even_after_source_deleted_without_new_day",
                "test_same_id_changed_payload_and_wrong_account_or_lesson_are_rejected",
                "test_content_version_changes_reject_new_event_but_not_old_receipt",
                "test_invalid_activity_creates_no_marker_receipt_or_learning_effect[unknown-option]",
                "test_invalid_activity_creates_no_marker_receipt_or_learning_effect[unknown-question]",
                "test_invalid_activity_creates_no_marker_receipt_or_learning_effect[unfinished-reorder]",
                "test_invalid_activity_creates_no_marker_receipt_or_learning_effect[invented-token]",
                "test_invalid_activity_creates_no_marker_receipt_or_learning_effect[excess-distractor-copy]",
                "test_invalid_activity_creates_no_marker_receipt_or_learning_effect[foreign-vocab]",
                "test_activity_receipt_marker_and_streak_rollback_together[marker-before]",
                "test_activity_receipt_marker_and_streak_rollback_together[marker-after]",
                "test_activity_receipt_marker_and_streak_rollback_together[receipt-flush]",
                "test_activity_receipt_marker_and_streak_rollback_together[commit-before]",
                "test_activity_commit_response_loss_is_recovered_without_posting_new_event",
                "test_activity_receipt_user_and_daily_share_processing_instant[before-midnight]",
                "test_activity_receipt_user_and_daily_share_processing_instant[after-midnight]",
                "test_activity_receipt_user_and_daily_share_processing_instant[before-month]",
                "test_activity_receipt_user_and_daily_share_processing_instant[after-month]",
                "test_activity_receipt_user_and_daily_share_processing_instant[before-year]",
                "test_activity_receipt_user_and_daily_share_processing_instant[after-year]",
                "test_first_offline_delivery_uses_delivery_day_and_replays_keep_that_day",
                "test_concurrent_same_and_new_lesson_answer_events_count_day_once",
                "test_completion_and_start_never_replace_answer_activity_receipt",
                "test_off_gate_does_not_backfill_saved_quiz_answer_after_activation",
                "test_one_saved_formal_quiz_answer_counts_day_and_only_vocabulary_goal[correct-normal]",
                "test_one_saved_formal_quiz_answer_counts_day_and_only_vocabulary_goal[correct-matching]",
                "test_one_saved_formal_quiz_answer_counts_day_and_only_vocabulary_goal[correct-arrange]",
                "test_one_saved_formal_quiz_answer_counts_day_and_only_vocabulary_goal[wrong-normal]",
                "test_one_saved_formal_quiz_answer_counts_day_and_only_vocabulary_goal[wrong-matching]",
                "test_one_saved_formal_quiz_answer_counts_day_and_only_vocabulary_goal[wrong-arrange]",
                "test_auth_loaded_stale_activity_snapshot_is_refreshed_without_losing_xp",
                "test_concurrent_other_completion_and_lesson_keep_one_day_and_both_effects[quiz-lesson-first]",
                "test_concurrent_other_completion_and_lesson_keep_one_day_and_both_effects[quiz-other-first]",
                "test_concurrent_other_completion_and_lesson_keep_one_day_and_both_effects[kana-quiz-lesson-first]",
                "test_concurrent_other_completion_and_lesson_keep_one_day_and_both_effects[kana-quiz-other-first]",
                "test_concurrent_other_completion_and_lesson_keep_one_day_and_both_effects[kana-stage-lesson-first]",
                "test_concurrent_other_completion_and_lesson_keep_one_day_and_both_effects[kana-stage-other-first]",
                "test_concurrent_other_completion_and_lesson_keep_one_day_and_both_effects[conversation-lesson-first]",
                "test_concurrent_other_completion_and_lesson_keep_one_day_and_both_effects[conversation-other-first]",
                "test_marker_upsert_preserves_other_daily_aggregates",
                "test_waiting_for_user_lock_across_midnight_uses_after_lock_processing_day",
                "test_tagged_kana_answer_atomic_receipt_and_next_day_replay_keep_progress_once[correct]",
                "test_tagged_kana_answer_atomic_receipt_and_next_day_replay_keep_progress_once[wrong]",
                "test_private_kana_receipt_cannot_be_read_as_lesson_activity",
                "test_tagged_kana_receipt_failure_rolls_back_progress_count_and_streak",
                "test_private_receipt_table_remains_owner_only_even_with_trusted_defaults",
                "test_populated_activity_receipts_and_markers_block_destructive_downgrade",
                "test_legacy_untagged_kana_preserves_original_repeat_effects_without_new_attendance",
                "test_tagged_kana_off_receipt_never_backfills_after_activation",
                "test_formal_answer_marker_failure_rolls_back_answer_and_srs",
                "test_answer_and_completion_share_lock_order_and_award_xp_once[completion-first]",
                "test_answer_and_completion_share_lock_order_and_award_xp_once[answer-first]",
                "test_exact_web_answer_sql_and_api_activity_share_user_session_mutex",
                "test_activity_http_contract_no_store_validation_auth_and_get_recovery",
                "test_off_gate_hides_capability_rejects_new_activity_but_keeps_old_receipt",
                "test_quiz_answer_waits_for_user_before_capturing_kst_day_and_goal_time",
                "test_kana_session_cutover_tags_only_new_active_snapshots_and_never_response",
                "test_answer_commit_response_loss_retry_does_not_repeat_day_or_learning_effects[quiz]",
                "test_answer_commit_response_loss_retry_does_not_repeat_day_or_learning_effects[kana]",
                "test_kana_receipt_replays_before_edited_or_deleted_source_without_regrading",
                "test_malformed_new_kana_snapshot_fails_before_any_learning_or_receipt_write[empty-options]",
                "test_malformed_new_kana_snapshot_fails_before_any_learning_or_receipt_write[duplicate-id]",
                "test_malformed_new_kana_snapshot_fails_before_any_learning_or_receipt_write[empty-id]",
                "test_malformed_new_kana_snapshot_fails_before_any_learning_or_receipt_write[numeric-id]",
                "test_malformed_new_kana_snapshot_fails_before_any_learning_or_receipt_write[missing-key]",
                "test_malformed_new_kana_snapshot_fails_before_any_learning_or_receipt_write[foreign-key]",
                "test_malformed_new_kana_snapshot_fails_before_any_learning_or_receipt_write[invalid-options]",
                "test_malformed_new_kana_snapshot_fails_before_any_learning_or_receipt_write[unknown-version]",
                "test_malformed_new_kana_snapshot_fails_before_any_learning_or_receipt_write[boolean-version]",
            )
        },
        *{
            ("tests.test_lesson_submissions_postgres", name)
            for name in (
                "test_receipt_migration_is_private_preserves_auth_and_fails_on_existing_object",
                "test_same_key_after_lost_response_and_separate_connections_never_reapplies",
                "test_twenty_concurrent_first_submissions_commit_one_attempt",
                "test_different_id_is_real_relearning_and_legacy_still_uses_same_policy",
                "test_get_race_does_not_treat_uncommitted_absence_as_a_new_attempt",
                "test_successful_commit_with_lost_ack_recovers_original_result",
                "test_replay_survives_edit_unpublish_and_content_deletion",
                "test_new_and_legacy_start_share_user_mutex_for_first_progress",
                "test_user_mutex_timeout_keeps_id_unprocessed_and_all_learning_unchanged",
                "test_other_users_continue_while_one_users_submission_is_in_flight",
                "test_other_users_cannot_read_receipts_and_owner_assertion_writes_nothing",
                "test_populated_receipts_block_destructive_downgrade",
            )
        },
        *{
            ("tests.test_lesson_submissions_postgres", f"test_same_key_conflict_changes_no_learning_rows[{mutation}]")
            for mutation in ("answer", "order", "time", "lesson")
        },
        *{
            (
                "tests.test_lesson_submissions_postgres",
                f"test_failed_processing_rolls_back_receipt_progress_srs_and_events[{failure}]",
            )
            for failure in ("registration", "second_answer", "after_apply", "receipt_flush", "precommit")
        },
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
                f"test_unsupported_free_matching_preserves_pending_session_and_xp[{category}]",
            )
            for category in ("KANJI", "LISTENING", "SENTENCE_ARRANGE", "CLOZE")
        },
        *{
            (
                "tests.test_special_quiz_resume_postgres",
                f"test_conflicting_stage_matching_category_preserves_pending_session_and_xp[{category}]",
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
                f"test_invalid_new_arrange_category_preserves_pending_session_and_xp[{category}]",
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
            "test_new_general_start_preserves_wrong_review_and_explicit_retry_reuses_it",
        ),
        (
            "tests.test_quiz_wrong_review_postgres",
            "test_old_empty_wrong_review_is_hidden_but_preserved_and_reused",
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
