import type { prisma, User } from '@harukoto/database';
import { getTodayKST } from '@/lib/date';

type StudyActivityUser = Pick<
  User,
  | 'id'
  | 'experiencePoints'
  | 'level'
  | 'lastStudyDate'
  | 'streakCount'
  | 'longestStreak'
  | 'dailyGoal'
  | 'app_settings'
>;

/**
 * Use the same user-first lock as the API before daily activity or streak
 * writes. NO KEY UPDATE remains compatible with child-row FK KEY SHARE locks.
 * Reading these fields in the locking query returns the committed values after
 * a competing completion releases the user, rather than an earlier auth read.
 */
export async function lockStudyActivityUser(
  tx: Pick<typeof prisma, '$queryRaw'>,
  userId: string
): Promise<StudyActivityUser> {
  const users = await tx.$queryRaw<StudyActivityUser[]>`
    SELECT id,
           experience_points AS "experiencePoints",
           level,
           last_study_date AS "lastStudyDate",
           streak_count AS "streakCount",
           longest_streak AS "longestStreak",
           daily_goal AS "dailyGoal",
           app_settings
    FROM public.users
    WHERE id = ${userId}::uuid
    FOR NO KEY UPDATE
  `;
  const user = users[0];
  if (!user) throw new Error('Study activity user no longer exists');
  return user;
}

/** Keep a newer stored study day when a delayed request or clock runs behind. */
export function preserveNewerStudyDate(
  previous: Date | null,
  currentDay: Date
): Date {
  return previous && getTodayKST(previous).getTime() > currentDay.getTime()
    ? previous
    : currentDay;
}
