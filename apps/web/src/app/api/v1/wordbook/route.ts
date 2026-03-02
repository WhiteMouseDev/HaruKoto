import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { WordbookSource } from '@harukoto/database';

export async function GET(request: NextRequest) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const searchParams = request.nextUrl.searchParams;
    const page = Math.max(1, Number(searchParams.get('page') || '1'));
    const limit = Math.min(50, Math.max(1, Number(searchParams.get('limit') || '20')));
    const sort = searchParams.get('sort') || 'recent';
    const search = searchParams.get('search') || '';
    const source = searchParams.get('source') as WordbookSource | null;

    const where: {
      userId: string;
      source?: WordbookSource;
      OR?: { word: { contains: string; mode: 'insensitive' }; reading?: never }[] | { word?: never; reading: { contains: string; mode: 'insensitive' }; meaningKo?: never }[] | Array<Record<string, unknown>>;
    } = { userId: user.id };

    if (source && Object.values(WordbookSource).includes(source)) {
      where.source = source;
    }

    const searchFilter = search
      ? {
          OR: [
            { word: { contains: search, mode: 'insensitive' as const } },
            { reading: { contains: search, mode: 'insensitive' as const } },
            { meaningKo: { contains: search, mode: 'insensitive' as const } },
          ],
        }
      : {};

    const orderBy =
      sort === 'alphabetical' ? { word: 'asc' as const } : { createdAt: 'desc' as const };

    const [entries, total] = await Promise.all([
      prisma.wordbookEntry.findMany({
        where: { ...where, ...searchFilter },
        orderBy,
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.wordbookEntry.count({
        where: { ...where, ...searchFilter },
      }),
    ]);

    return NextResponse.json({
      entries,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    console.error('Wordbook list error:', err);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();
    const { word, reading, meaningKo, source, note } = body;

    if (!word || !reading || !meaningKo) {
      return NextResponse.json(
        { error: 'word, reading, and meaningKo are required' },
        { status: 400 }
      );
    }

    const entry = await prisma.wordbookEntry.upsert({
      where: {
        userId_word: {
          userId: user.id,
          word,
        },
      },
      create: {
        userId: user.id,
        word,
        reading,
        meaningKo,
        source: source || 'MANUAL',
        note: note || null,
      },
      update: {
        reading,
        meaningKo,
        source: source || undefined,
        note: note !== undefined ? note : undefined,
      },
    });

    return NextResponse.json(entry, { status: 201 });
  } catch (err) {
    console.error('Wordbook add error:', err);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
