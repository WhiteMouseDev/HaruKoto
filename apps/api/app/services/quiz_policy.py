from __future__ import annotations

from datetime import datetime, timedelta

from app.models import UserGrammarProgress, UserVocabProgress
from app.utils.constants import SMART_QUIZ, SRS_CONFIG


def apply_srs_update(
    progress: UserVocabProgress | UserGrammarProgress,
    is_correct: bool,
    time_spent_seconds: int,
    now: datetime,
) -> None:
    """Apply the current SM-2-based review policy to a progress record."""
    if is_correct:
        if time_spent_seconds <= SRS_CONFIG.SPEED_THRESHOLDS.INSTANT:
            quality = 5
        elif time_spent_seconds <= SRS_CONFIG.SPEED_THRESHOLDS.QUICK:
            quality = 4
        else:
            quality = 3
    else:
        quality = 1 if progress.streak > 0 else 0

    ef = progress.ease_factor
    ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
    ef = max(SRS_CONFIG.MIN_EASE_FACTOR, ef)
    progress.ease_factor = round(ef, 2)

    if quality < 3:
        progress.incorrect_count += 1
        if progress.interval > 0:
            progress.interval = min(
                SRS_CONFIG.LAPSE_MAX_INTERVAL,
                max(1, round(progress.interval * SRS_CONFIG.LAPSE_MULTIPLIER)),
            )
        else:
            progress.interval = 0
        progress.streak = 0
    else:
        progress.correct_count += 1
        progress.streak += 1
        if progress.streak == 1:
            progress.interval = SRS_CONFIG.INITIAL_INTERVALS[0]
        elif progress.streak == 2:
            progress.interval = SRS_CONFIG.INITIAL_INTERVALS[1]
        else:
            progress.interval = round(progress.interval * ef)
        if quality == 5 and progress.interval > 3:
            progress.interval = round(progress.interval * SRS_CONFIG.INSTANT_BONUS)

    progress.next_review_at = (
        now + timedelta(days=progress.interval) if progress.interval > 0 else now + timedelta(minutes=SRS_CONFIG.REVIEW_DELAY_MINUTES)
    )
    progress.last_reviewed_at = now
    progress.mastered = progress.interval >= SRS_CONFIG.MASTERY_INTERVAL

    current_state = getattr(progress, "state", None) or "UNSEEN"
    if current_state == "UNSEEN":
        progress.state = "PROVISIONAL"
        if not getattr(progress, "introduced_by", None):
            progress.introduced_by = "QUIZ"
        progress.learning_step = 1 if is_correct else 0
    elif current_state == "PROVISIONAL":
        if is_correct:
            step = getattr(progress, "learning_step", 0) or 0
            if step >= 1:
                progress.state = "LEARNING"
                progress.learning_step = 1
            else:
                progress.learning_step = (step or 0) + 1
        else:
            progress.learning_step = 0
    elif current_state == "LEARNING":
        if is_correct:
            step = getattr(progress, "learning_step", 0) or 0
            if step >= 2 or progress.interval >= 6:
                progress.state = "REVIEW"
            else:
                progress.learning_step = step + 1
        else:
            progress.learning_step = 0
    elif current_state == "RELEARNING":
        if is_correct:
            progress.state = "REVIEW"
        else:
            progress.learning_step = 0
    elif current_state == "REVIEW":
        if is_correct and progress.mastered:
            progress.state = "MASTERED"
        elif not is_correct:
            progress.state = "RELEARNING"
            progress.learning_step = 0
    elif current_state == "MASTERED" and not is_correct:
        progress.state = "RELEARNING"
        progress.learning_step = 0


def calculate_smart_distribution(daily_goal: int, review_due: int, retry_due: int) -> dict[str, int]:
    """Calculate the new/review/retry mix for a smart quiz session."""
    goal = daily_goal
    min_new = max(2, goal // 10)

    retry = min(retry_due, goal // 5)
    remaining = goal - retry

    review = min(review_due, int(remaining * SMART_QUIZ.MAX_REVIEW_RATIO))
    remaining -= review

    new = remaining

    if review_due > review + SMART_QUIZ.DEBT_SEVERE_THRESHOLD:
        extra = new - min_new
        review += extra
        new = min_new
    elif review_due > review + SMART_QUIZ.DEBT_MILD_THRESHOLD:
        extra_review = min(review_due - review, new // 2)
        review += extra_review
        new -= extra_review

    return {"new": max(new, min_new), "review": review, "retry": retry}
