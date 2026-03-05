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

    // Get user's JLPT level
    const dbUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: { jlptLevel: true },
    });

    const jlptLevel = dbUser?.jlptLevel ?? 'N5';

    const now = new Date();

    // Count words due for review
    const reviewDueCount = await prisma.userVocabProgress.count({
      where: {
        userId: user.id,
        mastered: false,
        nextReviewAt: { lte: now },
      },
    });

    // Count new words not yet studied (user's level)
    const newWordsCount = await prisma.vocabulary.count({
      where: {
        jlptLevel,
        userProgress: { none: { userId: user.id } },
      },
    });

    // Count recently incorrect items
    const wrongCount = await prisma.userVocabProgress.count({
      where: {
        userId: user.id,
        incorrectCount: { gt: 0 },
        mastered: false,
      },
    });

    // Last review date
    const lastReview = await prisma.userVocabProgress.findFirst({
      where: { userId: user.id },
      orderBy: { lastReviewedAt: 'desc' },
      select: { lastReviewedAt: true },
    });

    return NextResponse.json({
      reviewDueCount,
      newWordsCount,
      wrongCount,
      lastReviewedAt: lastReview?.lastReviewedAt ?? null,
    });
  } catch (err) {
    console.error('Recommendations error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
