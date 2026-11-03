import { QUIZ_CONTENT_UNAVAILABLE } from '@/lib/quiz-submission-errors';
import type { prisma } from '@harukoto/database';

export class QuizContentUnavailableError extends Error {
  constructor() {
    super(QUIZ_CONTENT_UNAVAILABLE);
  }
}

type ContentReader = Pick<typeof prisma, 'vocabulary' | 'grammar'>;

export async function assertQuizContentAvailable(
  reader: ContentReader,
  quizType: string,
  questionIds: string[]
) {
  if (!questionIds.length) return;
  const ids = [...new Set(questionIds)];
  const records =
    quizType === 'VOCABULARY'
      ? await reader.vocabulary.findMany({
          where: { id: { in: ids } },
          select: { id: true },
        })
      : quizType === 'GRAMMAR'
        ? await reader.grammar.findMany({
            where: { id: { in: ids } },
            select: { id: true },
          })
        : null;
  if (records && records.length !== ids.length)
    throw new QuizContentUnavailableError();
}
