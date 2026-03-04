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
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const body = await request.json();
    const { sessionId, questionId, selectedOptionId, timeSpentSeconds = 0 } = body;

    if (!sessionId || !questionId || !selectedOptionId) {
      return NextResponse.json(
        { error: 'sessionId, questionId, and selectedOptionId are required' },
        { status: 400 }
      );
    }

    // Verify session
    const session = await prisma.quizSession.findUnique({
      where: { id: sessionId, userId: user.id },
    });

    if (!session || session.completedAt) {
      return NextResponse.json(
        { error: 'Invalid or completed session' },
        { status: 400 }
      );
    }

    // Verify answer from questionsData
    const questions = session.questionsData as Array<{
      questionId: string;
      correctOptionId: string;
    }>;
    const question = questions.find((q) => q.questionId === questionId);
    if (!question) {
      return NextResponse.json(
        { error: 'Question not found in session' },
        { status: 400 }
      );
    }

    const isCorrect = selectedOptionId === question.correctOptionId;

    // Create quiz answer
    await prisma.quizAnswer.create({
      data: {
        sessionId,
        questionId,
        questionType: 'KANA',
        selectedOptionId,
        isCorrect,
        timeSpentSeconds,
      },
    });

    // Update session correct count
    if (isCorrect) {
      await prisma.quizSession.update({
        where: { id: sessionId },
        data: { correctCount: { increment: 1 } },
      });
    }

    // Update UserKanaProgress
    await prisma.userKanaProgress.upsert({
      where: {
        userId_kanaId: { userId: user.id, kanaId: questionId },
      },
      update: {
        lastReviewedAt: new Date(),
        ...(isCorrect
          ? { correctCount: { increment: 1 }, streak: { increment: 1 } }
          : { incorrectCount: { increment: 1 }, streak: 0 }),
      },
      create: {
        userId: user.id,
        kanaId: questionId,
        correctCount: isCorrect ? 1 : 0,
        incorrectCount: isCorrect ? 0 : 1,
        streak: isCorrect ? 1 : 0,
        lastReviewedAt: new Date(),
      },
    });

    // Check mastery
    if (isCorrect) {
      const progress = await prisma.userKanaProgress.findUnique({
        where: { userId_kanaId: { userId: user.id, kanaId: questionId } },
      });
      if (progress && progress.streak >= 3 && !progress.mastered) {
        await prisma.userKanaProgress.update({
          where: { id: progress.id },
          data: { mastered: true },
        });
      }
    }

    return NextResponse.json({
      isCorrect,
      correctOptionId: question.correctOptionId,
    });
  } catch (err) {
    console.error('Kana quiz answer error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
