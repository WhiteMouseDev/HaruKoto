export const STUDY_WRITE_STOP_MESSAGE =
  '학습 저장을 잠시 점검하고 있어요. 잠시 후 같은 기록으로 다시 시도해주세요.';
export const STUDY_WRITE_STOP_RETRY_SECONDS = 60;

type Decision = 'pause' | 'allow';
type Rule = {
  method: string;
  path: string;
  decision: Decision;
  reason: string;
};

const rules = (
  method: string,
  decision: Decision,
  reason: string,
  paths: string[]
): Rule[] => paths.map((path) => ({ method, path, decision, reason }));

/** Inventory is deliberately explicit. New route methods require classification
 * in the regression test rather than inheriting a blanket POST/GET decision. */
export const STUDY_WRITE_ROUTE_POLICY: readonly Rule[] = [
  ...rules(
    'POST',
    'pause',
    'Learning session, answer, completion or reward writer',
    [
      '/api/v1/quiz/start',
      '/api/v1/quiz/smart-start',
      '/api/v1/quiz/wrong-answer-review/start',
      '/api/v1/quiz/resume',
      '/api/v1/quiz/answer',
      '/api/v1/quiz/complete',
      '/api/v1/kana/progress',
      '/api/v1/kana/quiz/start',
      '/api/v1/kana/quiz/answer',
      '/api/v1/kana/quiz/complete',
      '/api/v1/kana/stage-complete',
      '/api/v1/lessons/[lessonId]/start',
      '/api/v1/lessons/[lessonId]/submit',
      '/api/v1/lessons/[lessonId]/submissions',
      '/api/v1/lessons/[lessonId]/study-activities',
      '/api/v1/chat/start',
      '/api/v1/chat/message',
      '/api/v1/chat/end',
      '/api/v1/chat/live-token',
      '/api/v1/chat/live-feedback',
      '/api/v1/missions/claim',
    ]
  ),
  ...rules(
    'GET',
    'pause',
    'GET auto-claims mission XP and updates user rewards',
    ['/api/v1/missions/today']
  ),
  ...rules('PATCH', 'pause', 'Account settings update the shared user row', [
    '/api/v1/user/profile',
    '/api/v1/user/account',
    '/api/v1/user/avatar',
    '/api/v1/study/daily-goal',
  ]),
  ...rules(
    'POST',
    'pause',
    'Avatar upload ultimately updates the shared user row',
    ['/api/v1/user/avatar']
  ),
  ...rules('DELETE', 'pause', 'Destructive account/session mutation', [
    '/api/v1/user/account',
    '/api/v1/chat/[conversationId]',
  ]),
  ...rules(
    'GET',
    'allow',
    'Read or bootstrap only; no reward/user activity writer',
    [
      '/api/v1/stats/dashboard',
      '/api/v1/stats/history',
      '/api/v1/quiz/stats',
      '/api/v1/quiz/wrong-answers',
      '/api/v1/quiz/incomplete',
      '/api/v1/quiz/incomplete-sessions',
      '/api/v1/quiz/recommendations',
      '/api/v1/kana/characters',
      // This legacy read initializes stage rows, but does not grant rewards or
      // lock/update User. Retain listing/bootstrap and its existing behavior.
      '/api/v1/kana/stages',
      '/api/v1/kana/progress',
      '/api/v1/study/wrong-answers',
      '/api/v1/study/learned-words',
      '/api/v1/user/profile',
      '/api/v1/chat/scenarios',
      '/api/v1/chat/history',
      '/api/v1/chat/[conversationId]',
      '/api/v1/chat/characters',
      '/api/v1/chat/characters/favorites',
      '/api/v1/chat/characters/stats',
      '/api/v1/lessons/[lessonId]',
      '/api/v1/lessons/[lessonId]/submissions/[submissionId]',
      '/api/v1/lessons/[lessonId]/study-activities/[activityId]',
    ]
  ),
  ...rules(
    'GET',
    'allow',
    'Audio playback/cache does not update learning rewards',
    ['/api/v1/vocab/tts']
  ),
  ...rules(
    'POST',
    'allow',
    'Audio output/transcription, not a learning record',
    ['/api/v1/chat/tts', '/api/v1/chat/voice/transcribe']
  ),
  ...rules('POST', 'allow', 'Preserve authentication/bootstrap', [
    '/api/auth/ensure-user',
    '/api/v1/auth/onboarding',
  ]),
  ...rules(
    'POST',
    'allow',
    'Preserve payment callbacks and subscription operations',
    [
      '/api/v1/webhook/portone',
      '/api/v1/cron/subscription-renewal',
      '/api/v1/subscription/activate',
      '/api/v1/subscription/cancel',
      '/api/v1/subscription/checkout',
      '/api/v1/subscription/resume',
    ]
  ),
  ...rules('GET', 'allow', 'Billing read and existing scheduled reminder', [
    '/api/v1/subscription/status',
    '/api/v1/payments',
    '/api/cron/daily-reminder',
  ]),
  ...rules('GET', 'allow', 'User metadata read, not learning progress', [
    '/api/v1/notifications',
    '/api/v1/wordbook',
  ]),
  ...rules(
    'POST',
    'allow',
    'User metadata only, not XP/streak/session progress',
    [
      '/api/v1/wordbook',
      '/api/v1/push/subscribe',
      '/api/v1/chat/characters/favorites',
    ]
  ),
  ...rules('PATCH', 'allow', 'Notification metadata only', [
    '/api/v1/notifications',
  ]),
  ...rules('DELETE', 'allow', 'User metadata only', [
    '/api/v1/wordbook/[id]',
    '/api/v1/push/subscribe',
  ]),
];

export function canonicalStudyWritePath(pathname: string): string {
  let decoded = pathname;
  // Accept the same static path written with escaped characters/separators.
  // Bounded decoding also fences double-encoded aliases before a rewrite.
  for (let pass = 0; pass < 3; pass++) {
    try {
      const next = decodeURIComponent(decoded);
      if (next === decoded) break;
      decoded = next;
    } catch {
      break;
    }
  }
  const separators = decoded.replace(/\\/g, '/').replace(/\/{2,}/g, '/');
  return (
    new URL(separators, 'http://study-stop.invalid').pathname.replace(
      /\/+$/,
      ''
    ) || '/'
  );
}

function matchesPath(template: string, pathname: string): boolean {
  const pattern = template
    .split('/')
    .map((segment) =>
      /^\[[^\]]+\]$/.test(segment)
        ? '[^/]+'
        : segment.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    )
    .join('/');
  return new RegExp(`^${pattern}$`).test(pathname);
}

export function studyWriteRouteDecision(
  method: string,
  pathname: string
): Decision | undefined {
  const path = canonicalStudyWritePath(pathname);
  // Next supplies HEAD by running the GET handler when no HEAD is exported.
  const verb = method.toUpperCase() === 'HEAD' ? 'GET' : method.toUpperCase();
  return STUDY_WRITE_ROUTE_POLICY.find(
    (rule) => rule.method === verb && matchesPath(rule.path, path)
  )?.decision;
}

export function isStudyWriteStopError(error: unknown): boolean {
  return error instanceof Error && error.message === STUDY_WRITE_STOP_MESSAGE;
}

export function studyWriteErrorMessage(
  error: unknown,
  fallback: string
): string {
  return isStudyWriteStopError(error) ? STUDY_WRITE_STOP_MESSAGE : fallback;
}
