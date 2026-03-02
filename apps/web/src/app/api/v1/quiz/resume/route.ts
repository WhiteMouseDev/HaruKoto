import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { sessionId } = await request.json();
    if (!sessionId) {
      return NextResponse.json(
        { error: 'sessionId is required' },
        { status: 400 }
      );
    }

    const session = await prisma.quizSession.findUnique({
      where: { id: sessionId, userId: user.id },
      include: { answers: true },
    });

    if (!session) {
      return NextResponse.json(
        { error: 'Session not found' },
        { status: 404 }
      );
    }

    if (session.completedAt) {
      return NextResponse.json(
        { error: 'Session already completed' },
        { status: 400 }
      );
    }

    if (!session.questionsData) {
      return NextResponse.json(
        { error: 'No questions data available' },
        { status: 400 }
      );
    }

    const answeredQuestionIds = session.answers.map((a) => a.questionId);
    const correctCount = session.answers.filter((a) => a.isCorrect).length;

    return NextResponse.json({
      sessionId: session.id,
      questions: session.questionsData,
      answeredQuestionIds,
      totalQuestions: session.totalQuestions,
      correctCount,
    });
  } catch (err) {
    console.error('Quiz resume error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
