import type { prisma, QuizType, User } from '@harukoto/database';
import { getTodayKST } from '@/lib/date';

// Compatibility for the existing legacy web writer. FastAPI owns the API
// contract and shares this private persisted format with web.
const SETTINGS_KEY = 'dailyCategoryGoalsV1';
const DEFAULT_GOAL = 10;
const KST_OFFSET_SECONDS = 9 * 60 * 60;
const SECONDS_PER_DAY = 24 * 60 * 60;

type GoalUser = Pick<User, 'id' | 'dailyGoal' | 'app_settings'>;

function asObject(value: User['app_settings'] | undefined) {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? value
    : {};
}

/** Prepare the award after the caller has locked the user and saved the answer. */
export async function earnedDailyGoalSettings(
  tx: Pick<typeof prisma, '$queryRaw'>,
  user: GoalUser,
  quizType: QuizType,
  processedAt: Date
) {
  const settings = asObject(user.app_settings);
  const goals = asObject(settings[SETTINGS_KEY]);
  let target = DEFAULT_GOAL;
  switch (quizType) {
    case 'VOCABULARY':
      if (user.dailyGoal > 0) target = user.dailyGoal;
      break;
    case 'GRAMMAR':
    case 'SENTENCE_ARRANGE': {
      const value = goals[quizType === 'GRAMMAR' ? 'grammar' : 'sentence'];
      if (
        typeof value === 'number' &&
        Number.isInteger(value) &&
        value >= 5 &&
        value <= 50
      ) {
        target = value;
      }
      break;
    }
    default:
      return null;
  }

  const day = getTodayKST(processedAt);
  const month = day.toISOString().slice(0, 7);
  const dayNumber = day.getUTCDate();
  const earnedByMonth = asObject(goals.earnedByMonth);
  const monthDays = earnedByMonth[month];
  const earnedDays = Array.isArray(monthDays)
    ? monthDays.filter(
        (value): value is number =>
          typeof value === 'number' &&
          Number.isInteger(value) &&
          value >= 1 &&
          value <= 31
      )
    : [];
  if (earnedDays.includes(dayNumber)) return null;

  const startEpoch = day.getTime() / 1000 - KST_OFFSET_SECONDS;
  const endEpoch = startEpoch + SECONDS_PER_DAY;
  // Epoch bounds handle both legacy UTC-naive timestamps and aware timestamps.
  const [row] = await tx.$queryRaw<{ count: number }[]>`
    SELECT COUNT(DISTINCT answer.question_id)::integer AS count
    FROM public.quiz_answers AS answer
    JOIN public.quiz_sessions AS session ON session.id = answer.session_id
    WHERE session.user_id = ${user.id}::uuid
      AND session.quiz_type = ${quizType}::public."QuizType"
      AND (
        answer.question_type = session.quiz_type
        OR (
          answer.question_type = 'CLOZE'
          AND session.quiz_type IN ('VOCABULARY', 'GRAMMAR')
          AND COALESCE(session.questions_data->'questions', session.questions_data)::jsonb
            @> jsonb_build_array(jsonb_build_object('id', answer.question_id::text, 'type', 'CLOZE'))
        )
      )
      AND (
        session.quiz_type <> 'SENTENCE_ARRANGE'
        OR session.questions_data->>'mode' IS NULL
        OR session.questions_data->>'mode' = 'arrange'
      )
      AND EXTRACT(EPOCH FROM answer.answered_at) >= ${startEpoch}
      AND EXTRACT(EPOCH FROM answer.answered_at) < ${endEpoch}
  `;
  if ((row?.count ?? 0) < target) return null;

  const updatedDays = [...new Set([...earnedDays, dayNumber])].sort(
    (a, b) => a - b
  );
  return {
    ...settings,
    [SETTINGS_KEY]: {
      ...goals,
      earnedByMonth: { ...earnedByMonth, [month]: updatedDays },
    },
  };
}
