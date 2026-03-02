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
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const session = await prisma.quizSession.findFirst({
      where: {
        userId: user.id,
        completedAt: null,
        startedAt: { gte: twentyFourHoursAgo },
      },
      orderBy: { startedAt: 'desc' },
      include: { _count: { select: { answers: true } } },
    });

    if (!session) {
      return NextResponse.json({ session: null });
    }

    return NextResponse.json({
      session: {
        id: session.id,
        quizType: session.quizType,
        jlptLevel: session.jlptLevel,
        totalQuestions: session.totalQuestions,
        answeredCount: session._count.answers,
        correctCount: session.correctCount,
        startedAt: session.startedAt,
      },
    });
  } catch (err) {
    console.error('Incomplete quiz check error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
