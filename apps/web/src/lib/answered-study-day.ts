import type { prisma, QuizSession } from '@harukoto/database';
import { getTodayKST } from '@/lib/date';
import { updateStreak } from '@/lib/gamification';
import type { lockStudyActivityUser } from '@/lib/study-activity-lock';
import { ANSWERED_STUDY_DAY_RECOGNITION_ENABLED } from '@/lib/study-day-policy';

type LockedUser = Awaited<ReturnType<typeof lockStudyActivityUser>>;
type ActivityTransaction = Pick<typeof prisma, 'user' | 'dailyProgress'>;

export async function lockStudyQuizSession(
  tx: Pick<typeof prisma, '$queryRaw' | 'quizSession'>,
  sessionId: string
): Promise<QuizSession | null> {
  // The caller holds the user mutex first. Re-read after waiting, rather than
  // grading from an earlier unlocked snapshot or an auth-time user object.
  await tx.$queryRaw`
    SELECT id FROM public.quiz_sessions
    WHERE id = ${sessionId}::uuid
    FOR UPDATE
  `;
  return tx.quizSession.findUnique({ where: { id: sessionId } });
}

export async function recordAnsweredStudyDay(
  tx: ActivityTransaction,
  user: LockedUser,
  processedAt: Date
): Promise<void> {
  if (!ANSWERED_STUDY_DAY_RECOGNITION_ENABLED) return;
  const today = getTodayKST(processedAt);
  const streak = updateStreak(
    user.lastStudyDate,
    user.streakCount,
    user.longestStreak,
    today
  );
  await tx.dailyProgress.upsert({
    where: { userId_date: { userId: user.id, date: today } },
    create: { userId: user.id, date: today, activity_recorded: true },
    update: { activity_recorded: true },
  });
  await tx.user.update({
    where: { id: user.id },
    data: {
      streakCount: streak.streakCount,
      longestStreak: streak.longestStreak,
      lastStudyDate:
        user.lastStudyDate && user.lastStudyDate > processedAt
          ? user.lastStudyDate
          : processedAt,
    },
  });
}

type ActivityRecord = {
  activity_recorded?: boolean;
  wordsStudied?: number | null;
  quizzesCompleted?: number | null;
  conversationCount?: number | null;
  xpEarned?: number | null;
  kanaLearned?: number | null;
  grammar_studied?: number | null;
  sentences_studied?: number | null;
  studyTimeSeconds?: number | null;
  study_minutes?: number | null;
};

/** Match the API's explicit marker OR positive legacy activity predicate. */
export function hasRecordedStudyActivity(
  record: ActivityRecord | null
): boolean {
  return (
    record !== null &&
    (record.activity_recorded === true ||
      (
        [
          'wordsStudied',
          'quizzesCompleted',
          'conversationCount',
          'xpEarned',
          'kanaLearned',
          'grammar_studied',
          'sentences_studied',
          'studyTimeSeconds',
          'study_minutes',
        ] as const
      ).some((field) => (record[field] ?? 0) > 0))
  );
}
