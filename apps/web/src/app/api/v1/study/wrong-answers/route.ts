import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { PAGINATION } from '@/lib/constants';

export async function GET(request: NextRequest) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const searchParams = request.nextUrl.searchParams;
    const page = Math.max(1, Number(searchParams.get('page') || '1'));
    const limit = Math.min(
      PAGINATION.MAX_PAGE_SIZE,
      Math.max(1, Number(searchParams.get('limit') || String(PAGINATION.DEFAULT_PAGE_SIZE)))
    );
    const sort = searchParams.get('sort') || 'most-wrong';
    const level = searchParams.get('level') || '';

    const where: Record<string, unknown> = {
      userId: user.id,
      incorrectCount: { gt: 0 },
    };

    if (level) {
      where.vocabulary = { jlptLevel: level };
    }

    const orderBy =
      sort === 'recent'
        ? { lastReviewedAt: 'desc' as const }
        : sort === 'alphabetical'
          ? { vocabulary: { word: 'asc' as const } }
          : { incorrectCount: 'desc' as const };

    const [entries, total, masteredCount] = await Promise.all([
      prisma.userVocabProgress.findMany({
        where,
        include: { vocabulary: true },
        orderBy,
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.userVocabProgress.count({ where }),
      prisma.userVocabProgress.count({
        where: { userId: user.id, incorrectCount: { gt: 0 }, mastered: true },
      }),
    ]);

    return NextResponse.json({
      entries: entries.map((e) => ({
        id: e.id,
        vocabularyId: e.vocabularyId,
        word: e.vocabulary.word,
        reading: e.vocabulary.reading,
        meaningKo: e.vocabulary.meaningKo,
        jlptLevel: e.vocabulary.jlptLevel,
        exampleSentence: e.vocabulary.exampleSentence,
        exampleTranslation: e.vocabulary.exampleTranslation,
        correctCount: e.correctCount,
        incorrectCount: e.incorrectCount,
        mastered: e.mastered,
        lastReviewedAt: e.lastReviewedAt?.toISOString() ?? null,
      })),
      total,
      page,
      totalPages: Math.ceil(total / limit),
      summary: {
        totalWrong: total,
        mastered: masteredCount,
        remaining: total - masteredCount,
      },
    });
  } catch (err) {
    console.error('Wrong answers study GET error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
