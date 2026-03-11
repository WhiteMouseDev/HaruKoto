from __future__ import annotations

from datetime import timedelta
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
    TodayStats,
    WeeklyStats,
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
        xp_earned=dp.xp_earned if dp else 0,
        goal_progress=goal_progress,
    )

    # Weekly stats (last 7 days)
    week_start = today - timedelta(days=6)
    weekly_result = await db.execute(
        select(DailyProgress).where(DailyProgress.user_id == user.id, DailyProgress.date >= week_start).order_by(DailyProgress.date)
    )
    weekly_data = {str(dp.date): dp for dp in weekly_result.scalars().all()}

    dates, words_list, xp_list = [], [], []
    for i in range(7):
        d = week_start + timedelta(days=i)
        dates.append(str(d))
        dp_day = weekly_data.get(str(d))
        words_list.append(dp_day.words_studied if dp_day else 0)
        xp_list.append(dp_day.xp_earned if dp_day else 0)

    weekly = WeeklyStats(dates=dates, words_studied=words_list, xp_earned=xp_list)

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
        today=today_stats,
        streak=user.streak_count,
        weekly=weekly,
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
    days: int = Query(default=30, le=90),
    user: Annotated[User, Depends(get_current_user)] = None,
    db: AsyncSession = Depends(get_db),
):
    today = get_today_kst()
    start_date = today - timedelta(days=days - 1)

    result = await db.execute(
        select(DailyProgress).where(DailyProgress.user_id == user.id, DailyProgress.date >= start_date).order_by(DailyProgress.date.desc())
    )
    progress_list = result.scalars().all()

    return HistoryResponse(
        days=[
            DailyProgressItem(
                date=str(dp.date),
                words_studied=dp.words_studied,
                quizzes_completed=dp.quizzes_completed,
                xp_earned=dp.xp_earned,
            )
            for dp in progress_list
        ]
    )
