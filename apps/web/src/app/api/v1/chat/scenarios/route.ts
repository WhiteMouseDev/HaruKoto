import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import type { ScenarioCategory, Difficulty } from '@harukoto/database';
import { z } from 'zod';

const scenarioQuerySchema = z.object({
  category: z.enum(['TRAVEL', 'DAILY', 'BUSINESS', 'FREE'] as const).optional(),
  difficulty: z
    .enum(['BEGINNER', 'INTERMEDIATE', 'ADVANCED'] as const)
    .optional(),
});

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
    const parseResult = scenarioQuerySchema.safeParse({
      category: searchParams.get('category') || undefined,
      difficulty: searchParams.get('difficulty') || undefined,
    });

    if (!parseResult.success) {
      return NextResponse.json(
        { error: 'Invalid query parameters' },
        { status: 400 }
      );
    }

    const { category, difficulty } = parseResult.data;

    const where: {
      isActive: boolean;
      category?: ScenarioCategory;
      difficulty?: Difficulty;
    } = { isActive: true };

    if (category) {
      where.category = category as ScenarioCategory;
    }
    if (difficulty) {
      where.difficulty = difficulty as Difficulty;
    }

    const scenarios = await prisma.conversationScenario.findMany({
      where,
      orderBy: { order: 'asc' },
      select: {
        id: true,
        title: true,
        titleJa: true,
        description: true,
        category: true,
        difficulty: true,
        estimatedMinutes: true,
        keyExpressions: true,
        situation: true,
        yourRole: true,
        aiRole: true,
      },
    });

    return NextResponse.json({ scenarios });
  } catch (err) {
    console.error('Chat scenarios error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
