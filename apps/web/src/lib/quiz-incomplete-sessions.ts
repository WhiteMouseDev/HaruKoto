import { z } from 'zod';
import { prisma } from '@harukoto/database';
import {
  decodeWebQuizSnapshot,
  QuizSnapshotError,
} from '@/lib/quiz-session-snapshot';

const types = [
  'VOCABULARY',
  'GRAMMAR',
  'KANJI',
  'LISTENING',
  'CLOZE',
  'SENTENCE_ARRANGE',
] as const;
const levels = ['N5', 'N4', 'N3', 'N2', 'N1'] as const;
const querySchema = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: z.string().max(2048).optional(),
  quizType: z.enum(types).optional(),
  jlptLevel: z.enum(levels).optional(),
});
const cursorSchema = z
  .object({
    version: z.literal(1),
    id: z.string().uuid(),
    startedAt: z.string().datetime(),
    quizType: z.enum(types).nullable(),
    jlptLevel: z.enum(levels).nullable(),
  })
  .strict();

export type SavedQuizSummary = {
  id: string;
  quizType: string;
  jlptLevel: string;
  mode: string | null;
  totalQuestions: number;
  answeredCount: number;
  remainingCount: number | null;
  startedAt: string;
  resumeStatus: 'available' | 'legacy_unavailable' | 'invalid_snapshot';
  resumeReason:
    | 'UNSUPPORTED_CLIENT'
    | 'UNSUPPORTED_LEGACY'
    | 'SNAPSHOT_INVALID'
    | 'CONTENT_UNAVAILABLE'
    | null;
};
export type SavedQuizPage = {
  sessions: SavedQuizSummary[];
  nextCursor: string | null;
};

export class SavedQuizQueryError extends Error {}

export async function listSavedQuizzes(
  userId: string,
  search: URLSearchParams
): Promise<SavedQuizPage> {
  const parsed = querySchema.safeParse(Object.fromEntries(search));
  if (!parsed.success)
    throw new SavedQuizQueryError('저장 목록 조회 조건을 확인해 주세요.');
  const query = parsed.data;
  let cursor: z.infer<typeof cursorSchema> | null = null;
  if (query.cursor) {
    try {
      cursor = cursorSchema.parse(
        JSON.parse(Buffer.from(query.cursor, 'base64url').toString('utf8'))
      );
      if (
        cursor.quizType !== (query.quizType ?? null) ||
        cursor.jlptLevel !== (query.jlptLevel ?? null)
      )
        throw new Error('filter mismatch');
    } catch {
      throw new SavedQuizQueryError(
        '목록 위치를 확인할 수 없어요. 처음부터 다시 불러와 주세요.'
      );
    }
  }
  const where: NonNullable<
    Parameters<typeof prisma.quizSession.findMany>[0]
  >['where'] = {
    userId,
    completedAt: null,
    quizType: query.quizType ?? { not: 'KANA' },
    ...(query.jlptLevel ? { jlptLevel: query.jlptLevel } : {}),
    // Eligibility must precede LIMIT, including zero-answer rows.
    answers: { some: {} },
    ...(cursor
      ? {
          OR: [
            { startedAt: { lt: new Date(cursor.startedAt) } },
            { startedAt: new Date(cursor.startedAt), id: { lt: cursor.id } },
          ],
        }
      : {}),
  };
  const candidates = await prisma.quizSession.findMany({
    where,
    orderBy: [{ startedAt: 'desc' }, { id: 'desc' }],
    take: query.limit + 1,
    include: {
      answers: { select: { questionId: true }, distinct: ['questionId'] },
    },
  });
  const page = candidates.slice(0, query.limit);
  const sessions: SavedQuizSummary[] = page.map((session) => {
    const result: SavedQuizSummary = {
      id: session.id,
      quizType: session.quizType,
      jlptLevel: session.jlptLevel,
      totalQuestions: session.totalQuestions,
      answeredCount: session.answers.length,
      startedAt: session.startedAt.toISOString(),
      mode: null,
      remainingCount: null,
      resumeStatus: 'invalid_snapshot',
      resumeReason: 'SNAPSHOT_INVALID',
    };
    try {
      const snapshot = decodeWebQuizSnapshot(
        session.questionsData,
        session.totalQuestions,
        session.quizType
      );
      const expected = new Set(
        snapshot.questions.map((question) => question.questionId)
      );
      if (session.answers.some((answer) => !expected.has(answer.questionId)))
        return result;
      return {
        ...result,
        mode: snapshot.mode,
        remainingCount: session.totalQuestions - session.answers.length,
        resumeStatus: 'available',
        resumeReason: null,
      };
    } catch (error) {
      if (
        error instanceof QuizSnapshotError &&
        error.reason === 'unsupported'
      ) {
        return {
          ...result,
          resumeStatus: 'legacy_unavailable',
          resumeReason: 'UNSUPPORTED_CLIENT',
        };
      }
      return result;
    }
  });
  // Two bounded catalogue lookups for remaining SRS references, never one
  // query per session. Fully answered sessions need no catalogue to recover.
  const remainingBySession = new Map<string, string[]>();
  const vocabularyIds = new Set<string>();
  const grammarIds = new Set<string>();
  for (let index = 0; index < page.length; index++) {
    const row = page[index];
    if (sessions[index].resumeStatus !== 'available') continue;
    if (row.quizType !== 'VOCABULARY' && row.quizType !== 'GRAMMAR') continue;
    const snapshot = decodeWebQuizSnapshot(
      row.questionsData,
      row.totalQuestions,
      row.quizType
    );
    const saved = new Set(row.answers.map((answer) => answer.questionId));
    const ids = snapshot.questions
      .map((question) => question.questionId)
      .filter((id) => !saved.has(id));
    remainingBySession.set(row.id, ids);
    for (const id of ids)
      (row.quizType === 'VOCABULARY' ? vocabularyIds : grammarIds).add(id);
  }
  const [vocabulary, grammar] = await Promise.all([
    vocabularyIds.size
      ? prisma.vocabulary.findMany({
          where: { id: { in: [...vocabularyIds] } },
          select: { id: true },
        })
      : [],
    grammarIds.size
      ? prisma.grammar.findMany({
          where: { id: { in: [...grammarIds] } },
          select: { id: true },
        })
      : [],
  ]);
  const availableVocabulary = new Set(vocabulary.map((item) => item.id));
  const availableGrammar = new Set(grammar.map((item) => item.id));
  for (const summary of sessions) {
    const available =
      summary.quizType === 'VOCABULARY'
        ? availableVocabulary
        : availableGrammar;
    if (remainingBySession.get(summary.id)?.some((id) => !available.has(id))) {
      summary.resumeStatus = 'invalid_snapshot';
      summary.resumeReason = 'CONTENT_UNAVAILABLE';
      summary.remainingCount = null;
    }
  }
  const last = page.at(-1);
  const nextCursor =
    candidates.length > query.limit && last
      ? Buffer.from(
          JSON.stringify({
            version: 1,
            id: last.id,
            startedAt: last.startedAt.toISOString(),
            quizType: query.quizType ?? null,
            jlptLevel: query.jlptLevel ?? null,
          })
        ).toString('base64url')
      : null;
  return { sessions, nextCursor };
}
