import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

export async function GET() {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Fetch user, today's progress, and weekly stats in parallel
    const [dbUser, todayProgress, weeklyStats, vocabProgress, grammarProgress] =
      await Promise.all([
        prisma.user.findUnique({
          where: { id: user.id },
          select: {
            dailyGoal: true,
            streakCount: true,
            longestStreak: true,
          },
        }),
        prisma.dailyProgress.findUnique({
          where: { userId_date: { userId: user.id, date: today } },
        }),
        getWeeklyStats(user.id, today),
        prisma.userVocabProgress.groupBy({
          by: ['mastered'],
          where: { userId: user.id },
          _count: true,
        }),
        prisma.userGrammarProgress.groupBy({
          by: ['mastered'],
          where: { userId: user.id },
          _count: true,
        }),
      ]);

    if (!dbUser) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }

    // Count total vocab/grammar for user's level
    const [totalVocab, totalGrammar] = await Promise.all([
      prisma.vocabulary.count(),
      prisma.grammar.count(),
    ]);

    // Calculate vocab level progress
    const vocabMastered =
      vocabProgress.find((v) => v.mastered === true)?._count ?? 0;
    const vocabInProgress =
      vocabProgress.find((v) => v.mastered === false)?._count ?? 0;

    // Calculate grammar level progress
    const grammarMastered =
      grammarProgress.find((g) => g.mastered === true)?._count ?? 0;
    const grammarInProgress =
      grammarProgress.find((g) => g.mastered === false)?._count ?? 0;

    const wordsStudied = todayProgress?.wordsStudied ?? 0;

    return NextResponse.json({
      today: {
        wordsStudied,
        quizzesCompleted: todayProgress?.quizzesCompleted ?? 0,
        correctAnswers: todayProgress?.correctAnswers ?? 0,
        totalAnswers: todayProgress?.totalAnswers ?? 0,
        xpEarned: todayProgress?.xpEarned ?? 0,
        goalProgress:
          dbUser.dailyGoal > 0
            ? Math.min(wordsStudied / dbUser.dailyGoal, 1)
            : 0,
      },
      streak: {
        current: dbUser.streakCount,
        longest: dbUser.longestStreak,
      },
      weeklyStats,
      levelProgress: {
        vocabulary: {
          total: totalVocab,
          mastered: vocabMastered,
          inProgress: vocabInProgress,
        },
        grammar: {
          total: totalGrammar,
          mastered: grammarMastered,
          inProgress: grammarInProgress,
        },
      },
    });
  } catch (err) {
    console.error('Dashboard stats error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

async function getWeeklyStats(userId: string, today: Date) {
  const weekAgo = new Date(today);
  weekAgo.setDate(weekAgo.getDate() - 6);

  const records = await prisma.dailyProgress.findMany({
    where: {
      userId,
      date: { gte: weekAgo, lte: today },
    },
    orderBy: { date: 'asc' },
    select: {
      date: true,
      wordsStudied: true,
      xpEarned: true,
    },
  });

  // Build a map using local date string for consistent timezone handling
  const toLocalDateStr = (d: Date) => {
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  };

  const recordMap = new Map(
    records.map((r) => [toLocalDateStr(r.date), r])
  );

  // Fill in all 7 days (even if no data)
  const result: { date: string; wordsStudied: number; xpEarned: number }[] = [];
  for (let i = 0; i < 7; i++) {
    const d = new Date(weekAgo);
    d.setDate(d.getDate() + i);
    const dateStr = toLocalDateStr(d);
    const record = recordMap.get(dateStr);
    result.push({
      date: dateStr,
      wordsStudied: record?.wordsStudied ?? 0,
      xpEarned: record?.xpEarned ?? 0,
    });
  }

  return result;
}
