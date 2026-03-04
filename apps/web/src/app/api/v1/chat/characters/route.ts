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
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const id = request.nextUrl.searchParams.get('id');

    // Single character detail (includes personality, voiceName)
    if (id) {
      const character = await prisma.aiCharacter.findUnique({
        where: { id },
        select: {
          id: true,
          name: true,
          nameJa: true,
          nameRomaji: true,
          gender: true,
          ageDescription: true,
          description: true,
          relationship: true,
          backgroundStory: true,
          personality: true,
          voiceName: true,
          voiceBackup: true,
          speechStyle: true,
          targetLevel: true,
          silenceMs: true,
          tier: true,
          unlockCondition: true,
          isDefault: true,
          avatarEmoji: true,
          avatarUrl: true,
          gradient: true,
          order: true,
        },
      });

      if (!character) {
        return NextResponse.json(
          { error: 'Character not found' },
          { status: 404 }
        );
      }

      return NextResponse.json(
        { character },
        { headers: { 'Cache-Control': 'private, max-age=300' } }
      );
    }

    // All characters (list — excludes personality for lighter payload)
    const characters = await prisma.aiCharacter.findMany({
      where: { isActive: true },
      orderBy: { order: 'asc' },
      select: {
        id: true,
        name: true,
        nameJa: true,
        nameRomaji: true,
        gender: true,
        description: true,
        relationship: true,
        speechStyle: true,
        targetLevel: true,
        tier: true,
        unlockCondition: true,
        isDefault: true,
        avatarEmoji: true,
        avatarUrl: true,
        gradient: true,
        order: true,
      },
    });

    return NextResponse.json(
      { characters },
      { headers: { 'Cache-Control': 'private, max-age=300' } }
    );
  } catch (err) {
    console.error('Characters API error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
