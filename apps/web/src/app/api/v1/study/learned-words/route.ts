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
    const sort = searchParams.get('sort') || 'recent';
    const search = searchParams.get('search') || '';
    const filter = searchParams.get('filter') || 'ALL'; // ALL | MASTERED | LEARNING

    // Build where clause
    const where: Record<string, unknown> = { userId: user.id };

    if (filter === 'MASTERED') {
      where.mastered = true;
    } else if (filter === 'LEARNING') {
      where.mastered = false;
    }

    // Search across joined vocabulary fields
    const searchFilter = search
      ? {
          vocabulary: {
            OR: [
              { word: { contains: search, mode: 'insensitive' as const } },
              { reading: { contains: search, mode: 'insensitive' as const } },
              { meaningKo: { contains: search, mode: 'insensitive' as const } },
            ],
          },
        }
      : {};

    const orderBy =
      sort === 'alphabetical'
        ? { vocabulary: { word: 'asc' as const } }
        : sort === 'most-studied'
          ? { correctCount: 'desc' as const }
          : { lastReviewedAt: 'desc' as const };

    const [entries, total, summaryByMastered] = await Promise.all([
      prisma.userVocabProgress.findMany({
        where: { ...where, ...searchFilter },
        include: { vocabulary: true },
        orderBy,
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.userVocabProgress.count({
        where: { ...where, ...searchFilter },
      }),
      prisma.userVocabProgress.groupBy({
        by: ['mastered'],
        where: { userId: user.id },
        _count: true,
      }),
    ]);

    const masteredCount = summaryByMastered.find((s) => s.mastered)?._count ?? 0;
    const totalAll = summaryByMastered.reduce((sum, s) => sum + s._count, 0);

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
        streak: e.streak,
        mastered: e.mastered,
        lastReviewedAt: e.lastReviewedAt?.toISOString() ?? null,
      })),
      total,
      page,
      totalPages: Math.ceil(total / limit),
      summary: {
        totalLearned: totalAll,
        mastered: masteredCount,
        learning: totalAll - masteredCount,
      },
    });
  } catch (err) {
    console.error('Learned words GET error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
