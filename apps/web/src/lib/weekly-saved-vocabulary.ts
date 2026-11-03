import { prisma } from '@harukoto/database';

const DAY_MS = 24 * 60 * 60 * 1000;
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

/** Read-only daily unique answers, independent of completion counters/attendance. */
export async function getWeeklySavedVocabularyCounts(
  userId: string,
  mondayKstDate: Date
): Promise<Map<string, number>> {
  const startEpoch = (mondayKstDate.getTime() - KST_OFFSET_MS) / 1000;
  const endEpoch =
    (mondayKstDate.getTime() + 7 * DAY_MS - KST_OFFSET_MS) / 1000;
  // As in the API vocabulary goal, epoch extraction treats legacy UTC-naive
  // columns as nominal UTC and aware columns as instants, regardless of DB TZ.
  const rows = await prisma.$queryRaw<{ bucket: number; count: number }[]>`
    SELECT FLOOR((EXTRACT(EPOCH FROM answer.answered_at) + 32400) / 86400)::integer AS bucket,
           COUNT(DISTINCT answer.question_id)::integer AS count
    FROM public.quiz_answers AS answer
    JOIN public.quiz_sessions AS session ON session.id = answer.session_id
    WHERE session.user_id = ${userId}::uuid
      AND session.quiz_type = 'VOCABULARY'
      AND answer.question_type = 'VOCABULARY'
      AND EXTRACT(EPOCH FROM answer.answered_at) >= ${startEpoch}
      AND EXTRACT(EPOCH FROM answer.answered_at) < ${endEpoch}
    GROUP BY 1
    ORDER BY 1
  `;
  return new Map(
    rows.map((row) => [
      new Date(row.bucket * DAY_MS).toISOString().slice(0, 10),
      row.count,
    ])
  );
}
