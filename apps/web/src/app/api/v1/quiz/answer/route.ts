import {
  QUIZ_REFRESH_REQUIRED,
  QUIZ_ATTEMPT_CONFLICT,
  QUIZ_ALREADY_COMPLETED,
  QUIZ_STATE_CHANGED,
  QUIZ_TYPE_MISMATCH,
  QUIZ_WRITE_CONFLICT,
} from '@/lib/quiz-submission-errors';
import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { calculateSM2 } from '@/lib/spaced-repetition';
import { SRS_CONFIG } from '@/lib/constants';
import { z } from 'zod';
import {
  assertQuizContentAvailable,
  QuizContentUnavailableError,
} from '@/lib/quiz-content-availability';
import { lockStudyActivityUser } from '@/lib/study-activity-lock';
import {
  lockStudyQuizSession,
  recordAnsweredStudyDay,
} from '@/lib/answered-study-day';
import {
  decodeWebQuizSnapshot,
  QuizSnapshotError,
} from '@/lib/quiz-session-snapshot';
import { earnedDailyGoalSettings } from '@/lib/daily-category-goal';
import { getTodayKST } from '@/lib/date';
import { ANSWERED_STUDY_DAY_RECOGNITION_ENABLED } from '@/lib/study-day-policy';

const quizAnswerSchema = z.object({
  sessionId: z.string().min(1),
  attemptId: z.string().uuid().optional(),
  previousAttemptId: z.string().uuid().nullable().optional(),
  questionId: z.string().min(1),
  selectedOptionId: z.string().min(1),
  timeSpentSeconds: z.number().int().min(0).default(0),
  questionType: z
    .enum(['VOCABULARY', 'GRAMMAR', 'CLOZE', 'SENTENCE_ARRANGE'])
    .default('VOCABULARY'),
});

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
    const parseResult = quizAnswerSchema.safeParse(body);

    if (!parseResult.success) {
      return NextResponse.json({ error: 'Invalid input' }, { status: 400 });
    }

    const {
      sessionId,
      attemptId,
      previousAttemptId,
      questionId,
      selectedOptionId,
      timeSpentSeconds,
      questionType,
    } = parseResult.data;

    // Verify session ownership
    const session = await prisma.quizSession.findUnique({
      where: { id: sessionId },
    });
    if (!session) {
      return NextResponse.json(
        { error: '세션을 찾을 수 없습니다' },
        { status: 404 }
      );
    }
    if (session.userId !== user.id) {
      return NextResponse.json({ error: '권한이 없습니다' }, { status: 403 });
    }

    // Validate the stored serializer before any answer/SRS write. API snapshots
    // must stay on their own canonical grading and retry path in the app.
    const snapshot = decodeWebQuizSnapshot(
      session.questionsData,
      session.totalQuestions,
      session.quizType
    );
    const questionData = snapshot.questions.find(
      (question) => question.questionId === questionId
    );
    if (!questionData) throw new QuizSnapshotError('invalid');

    if (!attemptId || previousAttemptId === undefined) {
      return NextResponse.json(
        {
          error: QUIZ_REFRESH_REQUIRED,
        },
        { status: 409 }
      );
    }

    return await prisma.$transaction(async (tx) => {
      const currentUser = await lockStudyActivityUser(tx, user.id);
      const lockedSession = await lockStudyQuizSession(tx, sessionId);
      if (!lockedSession) {
        return NextResponse.json(
          { error: '세션을 찾을 수 없습니다' },
          { status: 404 }
        );
      }
      if (lockedSession.userId !== user.id) {
        return NextResponse.json({ error: '권한이 없습니다' }, { status: 403 });
      }
      const lockedSnapshot = decodeWebQuizSnapshot(
        lockedSession.questionsData,
        lockedSession.totalQuestions,
        lockedSession.quizType
      );
      const question = lockedSnapshot.questions.find(
        (item) => item.questionId === questionId
      );
      if (!question) throw new QuizSnapshotError('invalid');
      const replay = await tx.quizAnswer.findUnique({
        where: { id: attemptId },
      });
      if (replay) {
        const same =
          replay.sessionId === sessionId &&
          replay.questionId === questionId &&
          replay.selectedOptionId === selectedOptionId &&
          replay.questionType === questionType &&
          replay.timeSpentSeconds === timeSpentSeconds;
        if (!same)
          return NextResponse.json(
            {
              error: QUIZ_ATTEMPT_CONFLICT,
            },
            { status: 409 }
          );
        return NextResponse.json({ success: true, answerId: replay.id });
      }
      if (lockedSession.completedAt)
        return NextResponse.json(
          { error: QUIZ_ALREADY_COMPLETED },
          { status: 409 }
        );
      if (questionType !== lockedSession.quizType)
        return NextResponse.json(
          { error: QUIZ_TYPE_MISMATCH },
          { status: 409 }
        );
      const isCorrect = selectedOptionId === question.correctOptionId;
      const previousAnswer = await tx.quizAnswer.findFirst({
        where: { sessionId, questionId },
        orderBy: [{ answeredAt: 'desc' }, { id: 'desc' }],
      });
      if (
        (previousAnswer?.id ?? null) !== previousAttemptId ||
        previousAnswer?.isCorrect
      ) {
        return NextResponse.json(
          {
            error: QUIZ_STATE_CHANGED,
          },
          { status: 409 }
        );
      }
      await assertQuizContentAvailable(tx, questionType, [questionId]);
      const processedAt = new Date();
      // Do not synthesize timestamps at a KST boundary. A same-millisecond
      // predecessor is retried after real server time advances.
      if (previousAnswer && processedAt <= previousAnswer.answeredAt) {
        return NextResponse.json(
          {
            error:
              '답안 저장 순서를 확인하고 있어요. 잠시 후 같은 답안을 다시 저장해 주세요.',
          },
          { status: 409 }
        );
      }
      // Save answer
      await tx.quizAnswer.create({
        data: {
          id: attemptId,
          sessionId,
          questionId,
          questionType,
          selectedOptionId,
          isCorrect,
          timeSpentSeconds,
          answeredAt: processedAt,
        },
      });

      // Update correct count on session
      if (isCorrect) {
        await tx.quizSession.update({
          where: { id: sessionId },
          data: { correctCount: { increment: 1 } },
        });
      }

      // Update spaced repetition progress
      if (questionType === 'VOCABULARY') {
        const existing = await tx.userVocabProgress.findUnique({
          where: {
            userId_vocabularyId: {
              userId: user.id,
              vocabularyId: questionId,
            },
          },
        });

        const sm2Result = calculateSM2({
          easeFactor: existing?.easeFactor ?? 2.5,
          interval: existing?.interval ?? 0,
          streak: existing?.streak ?? 0,
          isCorrect,
          timeSpentSeconds,
        });

        await tx.userVocabProgress.upsert({
          where: {
            userId_vocabularyId: {
              userId: user.id,
              vocabularyId: questionId,
            },
          },
          update: {
            correctCount: isCorrect ? { increment: 1 } : undefined,
            incorrectCount: !isCorrect ? { increment: 1 } : undefined,
            streak: sm2Result.streak,
            easeFactor: sm2Result.easeFactor,
            interval: sm2Result.interval,
            nextReviewAt: sm2Result.nextReviewAt,
            lastReviewedAt: new Date(),
            mastered: sm2Result.interval >= SRS_CONFIG.MASTERY_INTERVAL,
          },
          create: {
            userId: user.id,
            vocabularyId: questionId,
            correctCount: isCorrect ? 1 : 0,
            incorrectCount: isCorrect ? 0 : 1,
            streak: sm2Result.streak,
            easeFactor: sm2Result.easeFactor,
            interval: sm2Result.interval,
            nextReviewAt: sm2Result.nextReviewAt,
            lastReviewedAt: new Date(),
          },
        });
      } else if (questionType === 'GRAMMAR') {
        const existing = await tx.userGrammarProgress.findUnique({
          where: {
            userId_grammarId: {
              userId: user.id,
              grammarId: questionId,
            },
          },
        });

        const sm2Result = calculateSM2({
          easeFactor: existing?.easeFactor ?? 2.5,
          interval: existing?.interval ?? 0,
          streak: existing?.streak ?? 0,
          isCorrect,
          timeSpentSeconds,
        });

        await tx.userGrammarProgress.upsert({
          where: {
            userId_grammarId: {
              userId: user.id,
              grammarId: questionId,
            },
          },
          update: {
            correctCount: isCorrect ? { increment: 1 } : undefined,
            incorrectCount: !isCorrect ? { increment: 1 } : undefined,
            streak: sm2Result.streak,
            easeFactor: sm2Result.easeFactor,
            interval: sm2Result.interval,
            nextReviewAt: sm2Result.nextReviewAt,
            lastReviewedAt: new Date(),
            mastered: sm2Result.interval >= SRS_CONFIG.MASTERY_INTERVAL,
          },
          create: {
            userId: user.id,
            grammarId: questionId,
            correctCount: isCorrect ? 1 : 0,
            incorrectCount: isCorrect ? 0 : 1,
            streak: sm2Result.streak,
            easeFactor: sm2Result.easeFactor,
            interval: sm2Result.interval,
            nextReviewAt: sm2Result.nextReviewAt,
            lastReviewedAt: new Date(),
          },
        });
      }

      // Transport replays return above. A new attempt can be the first answer
      // to this question on a new KST day.
      if (
        !previousAnswer ||
        getTodayKST(previousAnswer.answeredAt).getTime() !==
          getTodayKST(processedAt).getTime()
      ) {
        await recordAnsweredStudyDay(tx, currentUser, processedAt);
        if (ANSWERED_STUDY_DAY_RECOGNITION_ENABLED) {
          const appSettings = await earnedDailyGoalSettings(
            tx,
            currentUser,
            questionType,
            processedAt
          );
          if (appSettings) {
            await tx.user.update({
              where: { id: user.id },
              data: { app_settings: appSettings },
            });
          }
        }
      }
      return NextResponse.json({ success: true, answerId: attemptId });
    });
  } catch (err) {
    if (err instanceof QuizContentUnavailableError) {
      return NextResponse.json({ error: err.message }, { status: 409 });
    }
    if (
      typeof err === 'object' &&
      err !== null &&
      'code' in err &&
      (err.code === 'P2002' || err.code === 'P2003')
    ) {
      return NextResponse.json({ error: QUIZ_WRITE_CONFLICT }, { status: 409 });
    }
    if (err instanceof QuizSnapshotError) {
      return NextResponse.json({ error: err.message }, { status: 409 });
    }
    console.error('Quiz answer error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
