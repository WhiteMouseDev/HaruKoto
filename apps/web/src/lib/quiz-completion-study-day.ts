import { getTodayKST } from '@/lib/date';
import { hasRecordedStudyActivity } from '@/lib/answered-study-day';
import { STUDY_DAY_CREDIT_SEPARATION_ENABLED } from '@/lib/study-day-policy';

/** Read existing recognition before completion adds XP/counts, under the user mutex. */
export function completionStudyDayCredit(
  existing: Parameters<typeof hasRecordedStudyActivity>[0],
  firstAnswerTimes: readonly Date[],
  now: Date,
  separationEnabled = STUDY_DAY_CREDIT_SEPARATION_ENABLED
): { credited: boolean; refreshStreak: boolean } {
  const today = getTodayKST(now).getTime();
  const answeredToday = firstAnswerTimes.some(
    (time) => time <= now && getTodayKST(time).getTime() === today
  );
  if (answeredToday) return { credited: true, refreshStreak: true };
  // Compatibility rollback cannot turn an explicitly uncredited recovery day
  // into attendance merely because its completion counters are positive.
  if (existing?.studyDayCredited === false)
    return { credited: false, refreshStreak: false };
  if (!separationEnabled) return { credited: true, refreshStreak: true };
  return {
    credited: hasRecordedStudyActivity(existing),
    refreshStreak: false,
  };
}
