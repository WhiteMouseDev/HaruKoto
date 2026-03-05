import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { z } from 'zod';
import { calculateLevel } from '@/lib/gamification';

export async function GET() {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const [dbUser, dailyStats, totalQuizzes, userAchievements] =
      await Promise.all([
        prisma.user.findUnique({
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
            callSettings: true,
            createdAt: true,
          },
        }),
        prisma.dailyProgress.aggregate({
          where: { userId: user.id },
          _sum: { wordsStudied: true, xpEarned: true },
          _count: true,
        }),
        prisma.quizSession.count({
          where: { userId: user.id, completedAt: { not: null } },
        }),
        prisma.userAchievement.findMany({
          where: { userId: user.id },
          select: { achievementType: true, achievedAt: true },
        }),
      ]);

    if (!dbUser) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }

    const levelProgress = calculateLevel(dbUser.experiencePoints);

    return NextResponse.json(
      {
        profile: {
          ...dbUser,
          levelProgress: {
            currentXp: levelProgress.currentXp,
            xpForNext: levelProgress.xpForNext,
          },
        },
        summary: {
          totalWordsStudied: dailyStats._sum.wordsStudied ?? 0,
          totalQuizzesCompleted: totalQuizzes,
          totalStudyDays: dailyStats._count,
          totalXpEarned: dailyStats._sum.xpEarned ?? 0,
        },
        achievements: userAchievements.map((a) => ({
          achievementType: a.achievementType,
          achievedAt: a.achievedAt.toISOString(),
        })),
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

const callSettingsSchema = z.object({
  silenceDurationMs: z.number().int().min(0).max(5000).optional(),
  aiResponseSpeed: z.number().min(0.8).max(1.2).optional(),
  subtitleEnabled: z.boolean().optional(),
  autoAnalysis: z.boolean().optional(),
});

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
  callSettings: callSettingsSchema.optional(),
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

    // For callSettings, merge with existing instead of replacing
    let updateData: Record<string, unknown> = { ...data };
    if (data.callSettings) {
      const existing = await prisma.user.findUnique({
        where: { id: user.id },
        select: { callSettings: true },
      });
      const existingSettings = (existing?.callSettings as Record<string, unknown>) ?? {};
      updateData = {
        ...data,
        callSettings: { ...existingSettings, ...data.callSettings },
      };
    }

    const updated = await prisma.user.update({
      where: { id: user.id },
      data: updateData,
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
        callSettings: true,
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
