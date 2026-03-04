import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

export async function GET(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const { searchParams } = new URL(request.url);
    const type = searchParams.get('type');
    const category = searchParams.get('category');

    if (!type || (type !== 'HIRAGANA' && type !== 'KATAKANA')) {
      return NextResponse.json(
        { error: 'type must be HIRAGANA or KATAKANA' },
        { status: 400 }
      );
    }

    const characters = await prisma.kanaCharacter.findMany({
      where: {
        kanaType: type,
        ...(category ? { category } : {}),
      },
      include: {
        userProgress: {
          where: { userId: user.id },
          select: {
            correctCount: true,
            incorrectCount: true,
            streak: true,
            mastered: true,
            lastReviewedAt: true,
          },
        },
      },
      orderBy: { order: 'asc' },
    });

    const result = characters.map((char) => ({
      id: char.id,
      kanaType: char.kanaType,
      character: char.character,
      romaji: char.romaji,
      pronunciation: char.pronunciation,
      row: char.row,
      column: char.column,
      strokeCount: char.strokeCount,
      exampleWord: char.exampleWord,
      exampleReading: char.exampleReading,
      exampleMeaning: char.exampleMeaning,
      category: char.category,
      order: char.order,
      progress: char.userProgress[0] ?? null,
    }));

    return NextResponse.json({ characters: result });
  } catch (err) {
    console.error('Kana characters GET error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
