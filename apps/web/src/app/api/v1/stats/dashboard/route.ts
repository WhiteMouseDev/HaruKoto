import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { getTodayKST } from '@/lib/date';

// 정적 콘텐츠 개수 — DB에서 매번 조회할 필요 없음
const KANA_TOTAL_HIRAGANA = 46;
const KANA_TOTAL_KATAKANA = 46;

export async function GET() {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const today = getTodayKST();

    // Fetch user, today's progress, and weekly stats in parallel
    const [dbUser, todayProgress, weeklyStats, vocabProgress, grammarProgress, kanaLearnedHiragana, kanaLearnedKatakana, totalVocab, totalGrammar] =
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
        prisma.userKanaProgress.count({
          where: { userId: user.id, kana: { kanaType: 'HIRAGANA', category: 'basic' } },
        }),
        prisma.userKanaProgress.count({
          where: { userId: user.id, kana: { kanaType: 'KATAKANA', category: 'basic' } },
        }),
        prisma.vocabulary.count(),
        prisma.grammar.count(),
      ]);

    if (!dbUser) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }

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

    const headers = {
      'Cache-Control': 'private, no-cache',
    };

    const kanaProgress = {
      hiragana: {
        learned: kanaLearnedHiragana,
        total: KANA_TOTAL_HIRAGANA,
        pct: Math.round((kanaLearnedHiragana / KANA_TOTAL_HIRAGANA) * 100),
      },
      katakana: {
        learned: kanaLearnedKatakana,
        total: KANA_TOTAL_KATAKANA,
        pct: Math.round((kanaLearnedKatakana / KANA_TOTAL_KATAKANA) * 100),
      },
    };

    return NextResponse.json({
      kanaProgress,
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
    }, { headers });
  } catch (err) {
    console.error('Dashboard stats error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

async function getWeeklyStats(userId: string, today: Date) {
  // Start from Monday of the current week
  const dayOfWeek = today.getDay(); // 0=Sun, 1=Mon, ..., 6=Sat
  const monday = new Date(today);
  monday.setDate(today.getDate() - ((dayOfWeek + 6) % 7)); // shift so Mon=0

  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);

  const records = await prisma.dailyProgress.findMany({
    where: {
      userId,
      date: { gte: monday, lte: sunday },
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

  // Fill in Mon–Sun (7 days)
  const result: { date: string; wordsStudied: number; xpEarned: number }[] = [];
  for (let i = 0; i < 7; i++) {
    const d = new Date(monday);
    d.setDate(monday.getDate() + i);
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
