import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import {
  decodeWebQuizSnapshot,
  QuizSnapshotError,
  restoreWebQuizProgress,
} from '@/lib/quiz-session-snapshot';

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
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
      include: { answers: { orderBy: [{ answeredAt: 'asc' }, { id: 'asc' }] } },
    });

    if (!session) {
      return NextResponse.json({ error: 'Session not found' }, { status: 404 });
    }

    if (session.completedAt) {
      return NextResponse.json(
        { error: 'Session already completed' },
        { status: 400 }
      );
    }

    const snapshot = decodeWebQuizSnapshot(
      session.questionsData,
      session.totalQuestions,
      session.quizType
    );
    // Old rows can contain repeated submissions. Read the first saved answer
    // for each original question without changing or regrading those records.
    const firstAnswers = new Map<string, (typeof session.answers)[number]>();
    for (const answer of session.answers) {
      if (!firstAnswers.has(answer.questionId)) {
        firstAnswers.set(answer.questionId, answer);
      }
    }
    const answeredQuestionIds = [...firstAnswers.keys()];
    restoreWebQuizProgress(snapshot.questions, answeredQuestionIds);
    const correctCount = [...firstAnswers.values()].filter(
      (answer) => answer.isCorrect
    ).length;

    return NextResponse.json({
      sessionId: session.id,
      questions: snapshot.questions,
      answeredQuestionIds,
      totalQuestions: session.totalQuestions,
      correctCount,
      quizType: session.quizType,
      mode: snapshot.mode,
    });
  } catch (err) {
    if (err instanceof QuizSnapshotError) {
      return NextResponse.json({ error: err.message }, { status: 409 });
    }
    console.error('Quiz resume error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
