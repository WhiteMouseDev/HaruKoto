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

    const favorites = await prisma.userFavoriteCharacter.findMany({
      where: { userId: user.id },
      select: { characterId: true },
    });

    return NextResponse.json({
      favoriteIds: favorites.map((f) => f.characterId),
    });
  } catch (err) {
    console.error('Character favorites GET error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const { characterId } = (await request.json()) as { characterId: string };
    if (!characterId) {
      return NextResponse.json(
        { error: 'characterId is required' },
        { status: 400 }
      );
    }

    const existing = await prisma.userFavoriteCharacter.findUnique({
      where: {
        userId_characterId: { userId: user.id, characterId },
      },
    });

    if (existing) {
      await prisma.userFavoriteCharacter.delete({
        where: { id: existing.id },
      });
      return NextResponse.json({ favorited: false });
    }

    await prisma.userFavoriteCharacter.create({
      data: { userId: user.id, characterId },
    });

    return NextResponse.json({ favorited: true });
  } catch (err) {
    console.error('Character favorites POST error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
