import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { z } from 'zod';

const historyQuerySchema = z.object({
  year: z.coerce.number().int().min(2020).max(2100),
  month: z.coerce.number().int().min(1).max(12),
});

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
    const parseResult = historyQuerySchema.safeParse({
      year: searchParams.get('year'),
      month: searchParams.get('month'),
    });

    if (!parseResult.success) {
      return NextResponse.json(
        { error: 'Invalid query parameters: year and month are required' },
        { status: 400 }
      );
    }

    const { year, month } = parseResult.data;

    // Calculate start and end of the month (UTC)
    const startDate = new Date(Date.UTC(year, month - 1, 1));
    const endDate = new Date(Date.UTC(year, month, 0)); // last day of month

    const records = await prisma.dailyProgress.findMany({
      where: {
        userId: user.id,
        date: { gte: startDate, lte: endDate },
      },
      orderBy: { date: 'asc' },
      select: {
        date: true,
        wordsStudied: true,
        quizzesCompleted: true,
        correctAnswers: true,
        totalAnswers: true,
        conversationCount: true,
        studyTimeSeconds: true,
        xpEarned: true,
      },
    });

    const now = new Date();
    const isCurrentMonth =
      year === now.getFullYear() && month === now.getMonth() + 1;
    const cacheMaxAge = isCurrentMonth ? 60 : 86400;

    return NextResponse.json(
      {
        year,
        month,
        records: records.map((r) => ({
          ...r,
          date: r.date.toISOString().split('T')[0],
        })),
      },
      {
        headers: {
          'Cache-Control': `private, max-age=${cacheMaxAge}`,
        },
      }
    );
  } catch (err) {
    console.error('Stats history error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
