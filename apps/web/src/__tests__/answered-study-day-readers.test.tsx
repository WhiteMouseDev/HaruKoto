import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
import { GET as dashboard } from '@/app/api/v1/stats/dashboard/route';
import { GET as history } from '@/app/api/v1/stats/history/route';
import { StreakBadge } from '@/components/features/dashboard/streak-badge';
import { Heatmap } from '@/components/features/stats/heatmap';
import { hasRecordedStudyActivity } from '@/lib/answered-study-day';

const mocks = vi.hoisted(() => ({
  getUser: vi.fn(),
  prisma: {
    $queryRaw: vi.fn(),
    user: { findUnique: vi.fn() },
    dailyProgress: { findUnique: vi.fn(), findMany: vi.fn() },
    userVocabProgress: { groupBy: vi.fn() },
    userGrammarProgress: { groupBy: vi.fn() },
    userKanaProgress: { count: vi.fn() },
    vocabulary: { count: vi.fn() },
    grammar: { count: vi.fn() },
  },
}));
vi.mock('@harukoto/database', () => ({ prisma: mocks.prisma }));
vi.mock('@/lib/supabase/server', () => ({
  createClient: async () => ({ auth: { getUser: mocks.getUser } }),
}));
vi.mock('framer-motion', () => ({
  motion: {
    div: ({
      children,
      className,
      style,
      'aria-label': label,
      'data-studied': studied,
    }: React.HTMLAttributes<HTMLDivElement> & { 'data-studied'?: boolean }) => (
      <div
        className={className}
        style={style}
        aria-label={label}
        data-studied={studied}
      >
        {children}
      </div>
    ),
  },
}));

const record = () => ({
  date: new Date('2026-11-02T00:00:00Z'),
  wordsStudied: 0,
  quizzesCompleted: 0,
  correctAnswers: 0,
  totalAnswers: 0,
  conversationCount: 0,
  studyTimeSeconds: 0,
  xpEarned: 0,
  activity_recorded: true,
  kanaLearned: 0,
  grammar_studied: 0,
  sentences_studied: 0,
  study_minutes: 0,
});
beforeEach(() => {
  vi.resetAllMocks();
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2026-11-02T01:00:00Z'));
  mocks.getUser.mockResolvedValue({ data: { user: { id: 'user' } } });
  mocks.prisma.user.findUnique.mockResolvedValue({
    dailyGoal: 20,
    streakCount: 1,
    longestStreak: 9,
    showKana: true,
  });
  mocks.prisma.$queryRaw.mockResolvedValue([]);
  mocks.prisma.dailyProgress.findUnique.mockResolvedValue(record());
  mocks.prisma.dailyProgress.findMany.mockResolvedValue([record()]);
  mocks.prisma.userVocabProgress.groupBy.mockResolvedValue([]);
  mocks.prisma.userGrammarProgress.groupBy.mockResolvedValue([]);
  mocks.prisma.userKanaProgress.count.mockResolvedValue(0);
  mocks.prisma.vocabulary.count.mockResolvedValue(10);
  mocks.prisma.grammar.count.mockResolvedValue(10);
});
afterEach(() => {
  cleanup();
  vi.useRealTimers();
});

it('projects marker-only attendance without changing dashboard word goals, XP or completed quiz totals', async () => {
  const response = await dashboard();
  expect(response.status).toBe(200);
  const body = await response.json();
  expect(body.today).toEqual({
    wordsStudied: 0,
    hasStudied: true,
    quizzesCompleted: 0,
    correctAnswers: 0,
    totalAnswers: 0,
    xpEarned: 0,
    goalProgress: 0,
  });
  expect(body.weeklyStats[0]).toEqual({
    date: '2026-11-02',
    wordsStudied: 0,
    xpEarned: 0,
    hasStudied: true,
    vocabularyAnsweredCount: 0,
  });
  expect(body.weeklyStats[1].hasStudied).toBe(false);
});

it('exposes only the approved additive history flag, never the internal marker', async () => {
  const response = await history(
    new Request('http://localhost/api/v1/stats/history?year=2026&month=11')
  );
  const body = await response.json();
  expect(body.records).toEqual([
    {
      date: '2026-11-02',
      wordsStudied: 0,
      quizzesCompleted: 0,
      correctAnswers: 0,
      totalAnswers: 0,
      conversationCount: 0,
      studyTimeSeconds: 0,
      xpEarned: 0,
      hasStudied: true,
    },
  ]);
  expect(response.headers.get('Cache-Control')).toBe('private, no-cache');
});

it('revalidates the KST current month at a UTC year boundary after answer ACK', async () => {
  vi.setSystemTime(new Date('2026-12-31T15:00:00Z'));
  const response = await history(
    new Request('http://localhost/api/v1/stats/history?year=2027&month=1')
  );
  expect(response.headers.get('Cache-Control')).toBe('private, no-cache');
});

it('keeps positive legacy attendance and zero/absent record semantics', () => {
  expect(
    hasRecordedStudyActivity({ activity_recorded: false, kanaLearned: 1 })
  ).toBe(true);
  expect(hasRecordedStudyActivity({ wordsStudied: 1 })).toBe(true);
  expect(
    hasRecordedStudyActivity({ activity_recorded: false, wordsStudied: 0 })
  ).toBe(false);
  expect(hasRecordedStudyActivity(null)).toBe(false);
});

describe('attendance consumers', () => {
  it('uses explicit attendance with zero word/XP values and supports an old response without the field', () => {
    render(
      <StreakBadge
        currentStreak={1}
        weeklyStats={[
          {
            date: '2026-11-02',
            wordsStudied: 0,
            xpEarned: 0,
            hasStudied: true,
          },
          { date: '2026-11-03', wordsStudied: 1, xpEarned: 0 },
          { date: '2026-11-04', wordsStudied: 0, xpEarned: 0 },
        ]}
      />
    );
    expect(screen.getByLabelText('월요일 · 학습 기록 있음')).toHaveTextContent(
      ''
    );
    expect(
      screen.getByLabelText('화요일 · 학습 기록 있음')
    ).toBeInTheDocument();
    expect(
      screen.getByLabelText('수요일 · 학습 기록 없음')
    ).toBeInTheDocument();
  });

  it('shows marker-only history with a border without inventing word intensity', () => {
    render(
      <Heatmap
        year={2026}
        onYearChange={() => {}}
        records={[
          { date: '2026-11-02', wordsStudied: 0, hasStudied: true },
          { date: '2026-11-03', wordsStudied: 5 },
        ]}
      />
    );
    const attendance = screen.getByLabelText(
      '2026-11-02 · 단어 0개 · 학습 기록 있음'
    );
    expect(attendance).toHaveClass('bg-secondary', 'ring-1');
    expect(screen.getByText('총 5개 · 2일 학습')).toBeInTheDocument();
    expect(
      screen.getByLabelText('2026-11-04 · 단어 0개 · 학습 기록 없음')
    ).not.toHaveClass('ring-1');
  });
});
