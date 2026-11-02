import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { z } from 'zod';
import { lockStudyActivityUser } from '@/lib/study-activity-lock';
import {
  lockStudyQuizSession,
  recordAnsweredStudyDay,
} from '@/lib/answered-study-day';

const questionsSchema = z
  .array(
    z
      .object({
        questionId: z.string().uuid(),
        correctOptionId: z.string().min(1),
      })
      .passthrough()
      .refine(
        (question) => !Object.prototype.hasOwnProperty.call(question, 'id')
      )
  )
  .nonempty()
  .refine(
    (questions) =>
      new Set(questions.map((question) => question.questionId)).size ===
      questions.length
  );

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
    const {
      sessionId,
      questionId,
      selectedOptionId,
      timeSpentSeconds = 0,
    } = body;

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

    // Native kana snapshots use questionId, unlike API kana's own serializer.
    const parsed = questionsSchema.safeParse(session.questionsData);
    if (!parsed.success || session.quizType !== 'KANA') {
      return NextResponse.json(
        { error: 'Invalid kana quiz snapshot' },
        { status: 400 }
      );
    }
    if (!parsed.data.some((question) => question.questionId === questionId)) {
      return NextResponse.json(
        { error: 'Question not found in session' },
        { status: 400 }
      );
    }

    return await prisma.$transaction(async (tx) => {
      const currentUser = await lockStudyActivityUser(tx, user.id);
      const lockedSession = await lockStudyQuizSession(tx, sessionId);
      if (
        !lockedSession ||
        lockedSession.userId !== user.id ||
        lockedSession.completedAt
      ) {
        return NextResponse.json(
          { error: 'Invalid or completed session' },
          { status: 400 }
        );
      }
      const lockedQuestions = questionsSchema.safeParse(
        lockedSession.questionsData
      );
      if (!lockedQuestions.success || lockedSession.quizType !== 'KANA') {
        return NextResponse.json(
          { error: 'Invalid kana quiz snapshot' },
          { status: 400 }
        );
      }
      const question = lockedQuestions.data.find(
        (item) => item.questionId === questionId
      );
      if (!question) {
        return NextResponse.json(
          { error: 'Question not found in session' },
          { status: 400 }
        );
      }
      const isCorrect = selectedOptionId === question.correctOptionId;
      const previousAnswer = await tx.quizAnswer.findFirst({
        where: { sessionId, questionId },
        orderBy: [{ answeredAt: 'asc' }, { id: 'asc' }],
        select: { id: true },
      });
      const processedAt = new Date();
      // Create quiz answer
      await tx.quizAnswer.create({
        data: {
          sessionId,
          questionId,
          questionType: 'KANA',
          selectedOptionId,
          isCorrect,
          timeSpentSeconds,
          answeredAt: processedAt,
        },
      });

      // Update session correct count
      if (isCorrect) {
        await tx.quizSession.update({
          where: { id: sessionId },
          data: { correctCount: { increment: 1 } },
        });
      }

      // Update UserKanaProgress
      await tx.userKanaProgress.upsert({
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
        const progress = await tx.userKanaProgress.findUnique({
          where: { userId_kanaId: { userId: user.id, kanaId: questionId } },
        });
        if (progress && progress.streak >= 3 && !progress.mastered) {
          await tx.userKanaProgress.update({
            where: { id: progress.id },
            data: { mastered: true },
          });
        }
      }

      if (!previousAnswer) {
        await recordAnsweredStudyDay(tx, currentUser, processedAt);
      }
      return NextResponse.json({
        isCorrect,
        correctOptionId: question.correctOptionId,
      });
    });
  } catch (err) {
    console.error('Kana quiz answer error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
