// @vitest-environment node
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  listSavedQuizzes,
  SavedQuizQueryError,
} from '@/lib/quiz-incomplete-sessions';
const mocks = vi.hoisted(() => ({
  sessions: vi.fn(),
  vocabulary: vi.fn(),
  grammar: vi.fn(),
}));
vi.mock('@harukoto/database', () => ({
  prisma: {
    quizSession: { findMany: mocks.sessions },
    vocabulary: { findMany: mocks.vocabulary },
    grammar: { findMany: mocks.grammar },
  },
}));
const userId = '10000000-0000-4000-8000-000000000001';
const questionId = '10000000-0000-4000-8000-000000000002';
const otherId = '10000000-0000-4000-8000-000000000003';
const nativeQuestion = (id = questionId) => ({
  questionId: id,
  questionText: '映画',
  options: [{ id: 'right', text: '영화' }],
  correctOptionId: 'right',
});
const session = (suffix: number) => ({
  id: `10000000-0000-4000-8000-${suffix.toString().padStart(12, '0')}`,
  userId,
  quizType: 'VOCABULARY',
  jlptLevel: 'N5',
  totalQuestions: 2,
  startedAt: new Date('2026-10-01T01:00:00Z'),
  questionsData: [nativeQuestion(), nativeQuestion(otherId)],
  answers: [{ questionId }],
});
beforeEach(() => {
  vi.resetAllMocks();
  mocks.sessions.mockResolvedValue([session(10)]);
  mocks.vocabulary.mockImplementation(async ({ where }) =>
    where.id.in.map((id: string) => ({ id }))
  );
  mocks.grammar.mockResolvedValue([]);
});
describe('read-only saved quiz pagination', () => {
  it('keeps month-old records and excludes empty/KANA sessions before the page boundary', async () => {
    const result = await listSavedQuizzes(userId, new URLSearchParams());
    expect(result.sessions[0]).toMatchObject({
      id: session(10).id,
      answeredCount: 1,
      remainingCount: 1,
      startedAt: '2026-10-01T01:00:00.000Z',
      resumeStatus: 'available',
    });
    expect(mocks.sessions).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          userId,
          completedAt: null,
          quizType: { not: 'KANA' },
          answers: { some: {} },
        },
        take: 21,
        orderBy: [{ startedAt: 'desc' }, { id: 'desc' }],
      })
    );
  });
  it('uses a stable last-emitted cursor for same-time sessions and always constrains owner', async () => {
    mocks.sessions
      .mockResolvedValueOnce([session(12), session(11), session(10)])
      .mockResolvedValueOnce([session(10)]);
    const first = await listSavedQuizzes(
      userId,
      new URLSearchParams('limit=2')
    );
    expect(first.sessions.map((row) => row.id)).toEqual([
      session(12).id,
      session(11).id,
    ]);
    const next = new URLSearchParams({ limit: '2', cursor: first.nextCursor! });
    const second = await listSavedQuizzes('other-owner', next);
    expect(second.nextCursor).toBeNull();
    expect(mocks.sessions.mock.calls[1][0].where).toMatchObject({
      userId: 'other-owner',
      OR: [
        { startedAt: { lt: session(11).startedAt } },
        { startedAt: session(11).startedAt, id: { lt: session(11).id } },
      ],
    });
  });
  it.each([
    'limit=0',
    'limit=51',
    'limit=abc',
    'cursor=broken',
    'quizType=KANA',
    'jlptLevel=N0',
  ])('rejects invalid query %s without querying records', async (query) => {
    await expect(
      listSavedQuizzes(userId, new URLSearchParams(query))
    ).rejects.toBeInstanceOf(SavedQuizQueryError);
    expect(mocks.sessions).not.toHaveBeenCalled();
  });
  it('refuses applying a cursor to different filters', async () => {
    mocks.sessions.mockResolvedValue([session(12), session(11)]);
    const first = await listSavedQuizzes(
      userId,
      new URLSearchParams('limit=1&jlptLevel=N5')
    );
    mocks.sessions.mockClear();
    await expect(
      listSavedQuizzes(
        userId,
        new URLSearchParams({ cursor: first.nextCursor!, jlptLevel: 'N4' })
      )
    ).rejects.toBeInstanceOf(SavedQuizQueryError);
    expect(mocks.sessions).not.toHaveBeenCalled();
  });
  it('keeps unsupported rows visible alongside available records, without emitting original questions', async () => {
    mocks.sessions.mockResolvedValue([
      {
        ...session(11),
        totalQuestions: 1,
        questionsData: [
          {
            id: questionId,
            type: 'VOCABULARY',
            question: '映画',
            options: [],
            correctOptionId: questionId,
          },
        ],
      },
      session(10),
    ]);
    const result = await listSavedQuizzes(userId, new URLSearchParams());
    expect(result.sessions[0]).toMatchObject({
      resumeStatus: 'legacy_unavailable',
      resumeReason: 'UNSUPPORTED_CLIENT',
      remainingCount: null,
    });
    expect(result.sessions[1].resumeStatus).toBe('available');
    expect(JSON.stringify(result)).not.toContain('correctOptionId');
    expect(JSON.stringify(result)).not.toContain('映画');
  });
  it('marks only records needing removed catalogue entries unavailable', async () => {
    mocks.vocabulary.mockResolvedValue([]);
    mocks.sessions.mockResolvedValue([
      { ...session(11), answers: [{ questionId }, { questionId: otherId }] },
      session(10),
    ]);
    const result = await listSavedQuizzes(userId, new URLSearchParams());
    expect(result.sessions[0]).toMatchObject({
      resumeStatus: 'available',
      remainingCount: 0,
    });
    expect(result.sessions[1]).toMatchObject({
      resumeStatus: 'invalid_snapshot',
      resumeReason: 'CONTENT_UNAVAILABLE',
      remainingCount: null,
    });
    expect(mocks.vocabulary).toHaveBeenCalledOnce();
  });
});
