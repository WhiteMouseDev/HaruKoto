from __future__ import annotations

import calendar
from datetime import date, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.dependencies import get_current_user
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
from app.schemas.kana import KanaStat
from app.schemas.stats import (
    DailyProgressItem,
    DashboardResponse,
    HistoryResponse,
    KanaProgressResponse,
    LevelProgress,
    ProgressStat,
    StreakInfo,
    TodayStats,
    WeeklyStatItem,
)
from app.utils.date import get_today_kst

router = APIRouter(prefix="/api/v1/stats", tags=["stats"])


@router.get("/dashboard", response_model=DashboardResponse)
async def get_dashboard(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    today = get_today_kst()

    # Today's progress
    dp_result = await db.execute(select(DailyProgress).where(DailyProgress.user_id == user.id, DailyProgress.date == today))
    dp = dp_result.scalar_one_or_none()

    goal_progress = 0.0
    if dp and user.daily_goal > 0:
        goal_progress = min(1.0, dp.xp_earned / (user.daily_goal * 10))

    today_stats = TodayStats(
        words_studied=dp.words_studied if dp else 0,
        quizzes_completed=dp.quizzes_completed if dp else 0,
        correct_answers=dp.correct_answers if dp else 0,
        total_answers=dp.total_answers if dp else 0,
        xp_earned=dp.xp_earned if dp else 0,
        goal_progress=goal_progress,
    )

    # Streak as object
    streak = StreakInfo(current=user.streak_count, longest=user.longest_streak)

    # Weekly stats (last 7 days) as array of objects
    week_start = today - timedelta(days=6)
    weekly_result = await db.execute(
        select(DailyProgress).where(DailyProgress.user_id == user.id, DailyProgress.date >= week_start).order_by(DailyProgress.date)
    )
    weekly_data = {str(dp_row.date): dp_row for dp_row in weekly_result.scalars().all()}

    weekly_stats: list[WeeklyStatItem] = []
    for i in range(7):
        d = week_start + timedelta(days=i)
        dp_day = weekly_data.get(str(d))
        weekly_stats.append(
            WeeklyStatItem(
                date=str(d),
                words_studied=dp_day.words_studied if dp_day else 0,
                xp_earned=dp_day.xp_earned if dp_day else 0,
            )
        )

    # Level progress
    vocab_total = (await db.execute(select(func.count(Vocabulary.id)).where(Vocabulary.jlpt_level == user.jlpt_level))).scalar() or 0
    vocab_mastered = (
        await db.execute(
            select(func.count(UserVocabProgress.id))
            .join(Vocabulary)
            .where(UserVocabProgress.user_id == user.id, Vocabulary.jlpt_level == user.jlpt_level, UserVocabProgress.mastered.is_(True))
        )
    ).scalar() or 0
    vocab_in_progress = (
        await db.execute(
            select(func.count(UserVocabProgress.id))
            .join(Vocabulary)
            .where(UserVocabProgress.user_id == user.id, Vocabulary.jlpt_level == user.jlpt_level, UserVocabProgress.mastered.is_(False))
        )
    ).scalar() or 0

    grammar_total = (await db.execute(select(func.count(Grammar.id)).where(Grammar.jlpt_level == user.jlpt_level))).scalar() or 0
    grammar_mastered = (
        await db.execute(
            select(func.count(UserGrammarProgress.id))
            .join(Grammar)
            .where(UserGrammarProgress.user_id == user.id, Grammar.jlpt_level == user.jlpt_level, UserGrammarProgress.mastered.is_(True))
        )
    ).scalar() or 0
    grammar_in_progress = (
        await db.execute(
            select(func.count(UserGrammarProgress.id))
            .join(Grammar)
            .where(UserGrammarProgress.user_id == user.id, Grammar.jlpt_level == user.jlpt_level, UserGrammarProgress.mastered.is_(False))
        )
    ).scalar() or 0

    # Kana progress
    async def kana_stat(kt: KanaType) -> KanaStat:
        t = (await db.execute(select(func.count(KanaCharacter.id)).where(KanaCharacter.kana_type == kt))).scalar() or 0
        learned = (
            await db.execute(
                select(func.count(UserKanaProgress.id))
                .join(KanaCharacter)
                .where(UserKanaProgress.user_id == user.id, KanaCharacter.kana_type == kt)
            )
        ).scalar() or 0
        m = (
            await db.execute(
                select(func.count(UserKanaProgress.id))
                .join(KanaCharacter)
                .where(UserKanaProgress.user_id == user.id, KanaCharacter.kana_type == kt, UserKanaProgress.mastered.is_(True))
            )
        ).scalar() or 0
        return KanaStat(learned=learned, mastered=m, total=t)

    return DashboardResponse(
        show_kana=user.show_kana,
        today=today_stats,
        streak=streak,
        weekly_stats=weekly_stats,
        level_progress=LevelProgress(
            vocabulary=ProgressStat(total=vocab_total, mastered=vocab_mastered, in_progress=vocab_in_progress),
            grammar=ProgressStat(total=grammar_total, mastered=grammar_mastered, in_progress=grammar_in_progress),
        ),
        kana_progress=KanaProgressResponse(
            hiragana=await kana_stat(KanaType.HIRAGANA),
            katakana=await kana_stat(KanaType.KATAKANA),
        ),
    )


@router.get("/history", response_model=HistoryResponse)
async def get_history(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    year: int | None = Query(default=None),
    month: int | None = Query(default=None),
):
    today = get_today_kst()

    if year is None:
        year = today.year
    if month is None:
        month = today.month

    start_date = date(year, month, 1)
    _, last_day = calendar.monthrange(year, month)
    end_date = date(year, month, last_day)

    result = await db.execute(
        select(DailyProgress)
        .where(
            DailyProgress.user_id == user.id,
            DailyProgress.date >= start_date,
            DailyProgress.date <= end_date,
        )
        .order_by(DailyProgress.date)
    )
    progress_list = result.scalars().all()

    return HistoryResponse(
        year=year,
        month=month,
        records=[
            DailyProgressItem(
                date=str(dp.date),
                words_studied=dp.words_studied,
                quizzes_completed=dp.quizzes_completed,
                correct_answers=dp.correct_answers,
                total_answers=dp.total_answers,
                conversation_count=dp.conversation_count,
                study_time_seconds=dp.study_time_seconds,
                xp_earned=dp.xp_earned,
            )
            for dp in progress_list
        ],
    )
