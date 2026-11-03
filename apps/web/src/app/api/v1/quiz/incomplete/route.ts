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

    const session = await prisma.quizSession.findFirst({
      where: {
        userId: user.id,
        completedAt: null,
        quizType: { not: 'KANA' },
        answers: { some: {} },
      },
      orderBy: [{ startedAt: 'desc' }, { id: 'desc' }],
      include: {
        answers: { select: { questionId: true }, distinct: ['questionId'] },
      },
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
        answeredCount: session.answers.length,
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
