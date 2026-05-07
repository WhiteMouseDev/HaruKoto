from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    DailyProgress,
    Grammar,
    KanaCharacter,
    UserGrammarProgress,
    UserKanaProgress,
    UserVocabProgress,
    Vocabulary,
)
from app.models.enums import KanaType
from app.models.user import User
from app.schemas.kana import KanaProgressResponse, KanaStat
from app.schemas.stats import (
    DashboardResponse,
    LevelProgress,
    ProgressStat,
    StreakInfo,
    TodayStats,
    WeeklyStatItem,
)
from app.utils.date import KST, get_today_kst


async def get_dashboard_data(
    db: AsyncSession,
    user: User,
) -> DashboardResponse:
    today = get_today_kst()
    today_progress = await _get_daily_progress(db, user_id=user.id, day=today)
    weekly_stats = await _get_weekly_stats(db, user_id=user.id, today=today)
    level_progress = await _get_level_progress(db, user=user)
    kana_progress = await _get_kana_progress(db, user_id=user.id)

    return DashboardResponse(
        show_kana=user.show_kana,
        today=_build_today_stats(today_progress, daily_goal=user.daily_goal),
        streak=_build_streak_info(user=user, today_progress=today_progress, today=today),
        weekly_stats=weekly_stats,
        level_progress=level_progress,
        kana_progress=kana_progress,
    )


async def _get_daily_progress(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    day: date,
) -> DailyProgress | None:
    result = await db.execute(
        select(DailyProgress).where(
            DailyProgress.user_id == user_id,
            DailyProgress.date == day,
        )
    )
    return result.scalar_one_or_none()


def _build_today_stats(
    progress: DailyProgress | None,
    *,
    daily_goal: int,
) -> TodayStats:
    goal_progress = 0.0
    if progress and daily_goal > 0:
        goal_progress = min(1.0, progress.xp_earned / (daily_goal * 10))

    return TodayStats(
        words_studied=progress.words_studied if progress else 0,
        quizzes_completed=progress.quizzes_completed if progress else 0,
        correct_answers=progress.correct_answers if progress else 0,
        total_answers=progress.total_answers if progress else 0,
        xp_earned=progress.xp_earned if progress else 0,
        goal_progress=goal_progress,
        has_studied=_has_study_activity(progress),
    )


def _build_streak_info(
    *,
    user: Any,
    today_progress: DailyProgress | None,
    today: date,
) -> StreakInfo:
    last_study_day = _last_study_day(getattr(user, "last_study_date", None))
    studied_today = _has_study_activity(today_progress) or last_study_day == today
    current_streak = _effective_current_streak(
        current_streak=getattr(user, "streak_count", 0),
        last_study_day=last_study_day,
        today=today,
    )

    return StreakInfo(
        current=current_streak,
        longest=getattr(user, "longest_streak", 0),
        studied_today=studied_today,
        needs_action_today=current_streak > 0 and not studied_today,
    )


def _last_study_day(value: date | datetime | None) -> date | None:
    if isinstance(value, datetime):
        if value.tzinfo is not None:
            return value.astimezone(KST).date()
        return value.date()
    return value


def _effective_current_streak(
    *,
    current_streak: int,
    last_study_day: date | None,
    today: date,
) -> int:
    if last_study_day is None:
        return 0
    return current_streak if (today - last_study_day).days <= 1 else 0


def _has_study_activity(progress: DailyProgress | None) -> bool:
    if progress is None:
        return False

    return any(
        (getattr(progress, field, 0) or 0) > 0
        for field in (
            "words_studied",
            "quizzes_completed",
            "conversation_count",
            "xp_earned",
            "kana_learned",
            "grammar_studied",
            "sentences_studied",
            "study_time_seconds",
            "study_minutes",
        )
    )


async def _get_weekly_stats(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    today: date,
) -> list[WeeklyStatItem]:
    week_start = today - timedelta(days=6)
    result = await db.execute(
        select(DailyProgress)
        .where(
            DailyProgress.user_id == user_id,
            DailyProgress.date >= week_start,
        )
        .order_by(DailyProgress.date)
    )
    weekly_data = {str(row.date): row for row in result.scalars().all()}

    stats: list[WeeklyStatItem] = []
    for i in range(7):
        day = week_start + timedelta(days=i)
        progress = weekly_data.get(str(day))
        stats.append(
            WeeklyStatItem(
                date=str(day),
                words_studied=progress.words_studied if progress else 0,
                xp_earned=progress.xp_earned if progress else 0,
                has_studied=_has_study_activity(progress),
            )
        )
    return stats


async def _get_level_progress(
    db: AsyncSession,
    *,
    user: User,
) -> LevelProgress:
    vocab_total = await _count_content_total(db, Vocabulary, user.jlpt_level)
    vocab_counts = await _count_progress_by_mastery(
        db,
        progress_model=UserVocabProgress,
        content_model=Vocabulary,
        user_id=user.id,
        jlpt_level=user.jlpt_level,
    )
    grammar_total = await _count_content_total(db, Grammar, user.jlpt_level)
    grammar_counts = await _count_progress_by_mastery(
        db,
        progress_model=UserGrammarProgress,
        content_model=Grammar,
        user_id=user.id,
        jlpt_level=user.jlpt_level,
    )

    return LevelProgress(
        vocabulary=_build_progress_stat(total=vocab_total, counts=vocab_counts),
        grammar=_build_progress_stat(total=grammar_total, counts=grammar_counts),
    )


async def _count_content_total(
    db: AsyncSession,
    model: type[Vocabulary] | type[Grammar],
    jlpt_level: str,
) -> int:
    result = await db.execute(select(func.count(model.id)).where(model.jlpt_level == jlpt_level))
    return result.scalar() or 0


async def _count_progress_by_mastery(
    db: AsyncSession,
    *,
    progress_model: type[UserVocabProgress] | type[UserGrammarProgress],
    content_model: type[Vocabulary] | type[Grammar],
    user_id: uuid.UUID,
    jlpt_level: str,
) -> dict[bool, int]:
    result = await db.execute(
        select(
            progress_model.mastered,
            func.count(progress_model.id),
        )
        .join(content_model)
        .where(
            progress_model.user_id == user_id,
            content_model.jlpt_level == jlpt_level,
        )
        .group_by(progress_model.mastered)
    )
    return {row[0]: row[1] for row in result.all()}


def _build_progress_stat(
    *,
    total: int,
    counts: dict[bool, int],
) -> ProgressStat:
    return ProgressStat(
        total=total,
        mastered=counts.get(True, 0),
        in_progress=counts.get(False, 0),
    )


async def _get_kana_progress(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
) -> KanaProgressResponse:
    total_result = await db.execute(select(KanaCharacter.kana_type, func.count(KanaCharacter.id)).group_by(KanaCharacter.kana_type))
    totals = {row[0]: row[1] for row in total_result.all()}

    mastered_result = await db.execute(
        select(KanaCharacter.kana_type, func.count(UserKanaProgress.id))
        .join(KanaCharacter)
        .where(
            UserKanaProgress.user_id == user_id,
            UserKanaProgress.mastered.is_(True),
        )
        .group_by(KanaCharacter.kana_type)
    )
    mastered_map = {row[0]: row[1] for row in mastered_result.all()}

    learned_result = await db.execute(
        select(KanaCharacter.kana_type, func.count(UserKanaProgress.id))
        .join(KanaCharacter)
        .where(UserKanaProgress.user_id == user_id)
        .group_by(KanaCharacter.kana_type)
    )
    learned_map = {row[0]: row[1] for row in learned_result.all()}

    return KanaProgressResponse(
        hiragana=_build_kana_stat(
            kana_type=KanaType.HIRAGANA,
            totals=totals,
            learned_map=learned_map,
            mastered_map=mastered_map,
        ),
        katakana=_build_kana_stat(
            kana_type=KanaType.KATAKANA,
            totals=totals,
            learned_map=learned_map,
            mastered_map=mastered_map,
        ),
    )


def _build_kana_stat(
    *,
    kana_type: KanaType,
    totals: dict[KanaType, int],
    learned_map: dict[KanaType, int],
    mastered_map: dict[KanaType, int],
) -> KanaStat:
    return KanaStat(
        learned=learned_map.get(kana_type, 0),
        mastered=mastered_map.get(kana_type, 0),
        total=totals.get(kana_type, 0),
    )
