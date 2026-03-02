import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

export async function GET(request: NextRequest) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const level = request.nextUrl.searchParams.get('level') || 'N5';
    const type = request.nextUrl.searchParams.get('type') || 'VOCABULARY';

    if (type === 'VOCABULARY') {
      const [totalCount, studiedCount] = await Promise.all([
        prisma.vocabulary.count({
          where: { jlptLevel: level as 'N5' | 'N4' | 'N3' | 'N2' | 'N1' },
        }),
        prisma.userVocabProgress.count({
          where: {
            userId: user.id,
            vocabulary: {
              jlptLevel: level as 'N5' | 'N4' | 'N3' | 'N2' | 'N1',
            },
          },
        }),
      ]);

      const progress =
        totalCount > 0 ? Math.round((studiedCount / totalCount) * 100) : 0;

      return NextResponse.json({ totalCount, studiedCount, progress });
    }

    // GRAMMAR
    const [totalCount, studiedCount] = await Promise.all([
      prisma.grammar.count({
        where: { jlptLevel: level as 'N5' | 'N4' | 'N3' | 'N2' | 'N1' },
      }),
      prisma.userGrammarProgress.count({
        where: {
          userId: user.id,
          grammar: {
            jlptLevel: level as 'N5' | 'N4' | 'N3' | 'N2' | 'N1',
          },
        },
      }),
    ]);

    const progress =
      totalCount > 0 ? Math.round((studiedCount / totalCount) * 100) : 0;

    return NextResponse.json({ totalCount, studiedCount, progress });
  } catch (err) {
    console.error('Quiz stats error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
