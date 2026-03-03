import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { z } from 'zod';

export async function GET() {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const dbUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: {
        id: true,
        email: true,
        nickname: true,
        avatarUrl: true,
        jlptLevel: true,
        goal: true,
        dailyGoal: true,
        experiencePoints: true,
        level: true,
        streakCount: true,
        longestStreak: true,
        lastStudyDate: true,
        isPremium: true,
        createdAt: true,
      },
    });

    if (!dbUser) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }

    // Summary stats
    const [totalWordsStudied, totalQuizzes, totalXp, studyDays] =
      await Promise.all([
        prisma.dailyProgress.aggregate({
          where: { userId: user.id },
          _sum: { wordsStudied: true },
        }),
        prisma.quizSession.count({
          where: { userId: user.id, completedAt: { not: null } },
        }),
        prisma.dailyProgress.aggregate({
          where: { userId: user.id },
          _sum: { xpEarned: true },
        }),
        prisma.dailyProgress.count({
          where: { userId: user.id },
        }),
      ]);

    return NextResponse.json(
      {
        profile: dbUser,
        summary: {
          totalWordsStudied: totalWordsStudied._sum.wordsStudied ?? 0,
          totalQuizzesCompleted: totalQuizzes,
          totalStudyDays: studyDays,
          totalXpEarned: totalXp._sum.xpEarned ?? 0,
        },
      },
      {
        headers: {
          'Cache-Control': 'private, no-cache',
        },
      }
    );
  } catch (err) {
    console.error('User profile GET error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

const updateProfileSchema = z.object({
  nickname: z.string().min(1).max(20).optional(),
  jlptLevel: z.enum(['N5', 'N4', 'N3', 'N2', 'N1']).optional(),
  dailyGoal: z.number().int().min(1).max(100).optional(),
  goal: z
    .enum([
      'JLPT_N5',
      'JLPT_N4',
      'JLPT_N3',
      'JLPT_N2',
      'JLPT_N1',
      'TRAVEL',
      'BUSINESS',
      'HOBBY',
    ])
    .optional(),
});

export async function PATCH(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const body = await request.json();
    const parseResult = updateProfileSchema.safeParse(body);

    if (!parseResult.success) {
      return NextResponse.json(
        {
          error: 'Invalid request body',
          details: parseResult.error.flatten().fieldErrors,
        },
        { status: 400 }
      );
    }

    const data = parseResult.data;

    // Only update fields that were provided
    if (Object.keys(data).length === 0) {
      return NextResponse.json(
        { error: 'No fields to update' },
        { status: 400 }
      );
    }

    const updated = await prisma.user.update({
      where: { id: user.id },
      data,
      select: {
        id: true,
        email: true,
        nickname: true,
        avatarUrl: true,
        jlptLevel: true,
        goal: true,
        dailyGoal: true,
        experiencePoints: true,
        level: true,
        streakCount: true,
        longestStreak: true,
        lastStudyDate: true,
        isPremium: true,
        createdAt: true,
      },
    });

    return NextResponse.json({ profile: updated });
  } catch (err) {
    console.error('User profile PATCH error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
