import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
import { GET as dashboard } from '@/app/api/v1/stats/dashboard/route';
import { getWeeklySavedVocabularyCounts } from '@/lib/weekly-saved-vocabulary';
import { WeeklyChart } from '@/components/features/dashboard/weekly-chart';
import { StreakBadge } from '@/components/features/dashboard/streak-badge';

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
      role,
      style,
      animate,
      'aria-label': label,
    }: React.HTMLAttributes<HTMLDivElement> & {
      animate?: { height?: number };
    }) => (
      <div
        role={role}
        className={className}
        aria-label={label}
        style={{
          ...style,
          ...(animate?.height !== undefined ? { height: animate.height } : {}),
        }}
      >
        {children}
      </div>
    ),
  },
}));

const userId = '10000000-0000-4000-8000-000000000001';
const bucket = (day: string) =>
  new Date(`${day}T00:00:00Z`).getTime() / 86400000;
const day = {
  date: '2026-11-02',
  wordsStudied: 0,
  xpEarned: 0,
  hasStudied: false,
};

beforeEach(() => {
  vi.resetAllMocks();
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2026-11-02T01:00:00Z'));
  mocks.getUser.mockResolvedValue({ data: { user: { id: userId } } });
  mocks.prisma.$queryRaw.mockResolvedValue([]);
  mocks.prisma.user.findUnique.mockResolvedValue({
    dailyGoal: 20,
    streakCount: 0,
    longestStreak: 0,
  });
  mocks.prisma.dailyProgress.findUnique.mockResolvedValue(null);
  mocks.prisma.dailyProgress.findMany.mockResolvedValue([]);
  mocks.prisma.userVocabProgress.groupBy.mockResolvedValue([]);
  mocks.prisma.userGrammarProgress.groupBy.mockResolvedValue([]);
  mocks.prisma.userKanaProgress.count.mockResolvedValue(0);
  mocks.prisma.vocabulary.count.mockResolvedValue(1);
  mocks.prisma.grammar.count.mockResolvedValue(1);
});
afterEach(() => {
  cleanup();
  vi.useRealTimers();
});

describe('weekly read projection', () => {
  it('shows one persisted incomplete/wrong vocabulary answer without inventing completion, XP, goals or attendance', async () => {
    mocks.prisma.$queryRaw.mockResolvedValue([
      { bucket: bucket(day.date), count: 1 },
    ]);
    const response = await dashboard();
    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body.weeklyStats[0]).toEqual({ ...day, vocabularyAnsweredCount: 1 });
    expect(body.today).toEqual({
      wordsStudied: 0,
      hasStudied: false,
      quizzesCompleted: 0,
      correctAnswers: 0,
      totalAnswers: 0,
      xpEarned: 0,
      goalProgress: 0,
    });
    expect(body.streak).toEqual({ current: 0, longest: 0 });
    expect(body.weeklyStats).toHaveLength(7);
    expect(body.weeklyStats[6].date).toBe('2026-11-08');
  });

  it('executes one parameterized distinct-per-KST-day query with owner, both vocabulary types and half-open week bounds', async () => {
    mocks.prisma.$queryRaw.mockResolvedValue([
      { bucket: bucket('2026-11-02'), count: 1 },
      { bucket: bucket('2026-11-03'), count: 1 },
    ]);
    const counts = await getWeeklySavedVocabularyCounts(
      userId,
      new Date('2026-11-02T00:00:00Z')
    );
    expect([...counts]).toEqual([
      ['2026-11-02', 1],
      ['2026-11-03', 1],
    ]);
    expect(mocks.prisma.$queryRaw).toHaveBeenCalledTimes(1);
    const [parts, owner, start, end] = mocks.prisma.$queryRaw.mock.calls[0];
    const sql = parts.join('?');
    expect(sql).toContain('COUNT(DISTINCT answer.question_id)');
    expect(sql).toContain("session.quiz_type = 'VOCABULARY'");
    expect(sql).toContain("answer.question_type = 'VOCABULARY'");
    expect(sql).toContain('GROUP BY 1');
    expect(sql).toContain('session.user_id = ?::uuid');
    expect(sql).not.toContain(userId);
    expect(sql).not.toContain('completed_at');
    expect(sql).not.toContain('is_correct');
    expect(sql).not.toMatch(/\b(INSERT|UPDATE|DELETE)\b/);
    expect(owner).toBe(userId);
    expect(start).toBe(new Date('2026-11-01T15:00:00Z').getTime() / 1000);
    expect(end).toBe(new Date('2026-11-08T15:00:00Z').getTime() / 1000);
  });

  it('retains the Monday–Sunday window through a KST year boundary', async () => {
    vi.setSystemTime(new Date('2026-12-31T15:00:00Z'));
    const body = await (await dashboard()).json();
    expect(body.weeklyStats[0].date).toBe('2026-12-28');
    expect(body.weeklyStats[6].date).toBe('2027-01-03');
    const [, owner, start, end] = mocks.prisma.$queryRaw.mock.calls[0];
    expect(owner).toBe(userId);
    expect(start).toBe(new Date('2026-12-27T15:00:00Z').getTime() / 1000);
    expect(end).toBe(new Date('2027-01-03T15:00:00Z').getTime() / 1000);
  });
});

describe('weekly chart', () => {
  it('uses saved answers for bars, sums and targets while XP stays completion-based', () => {
    render(
      <WeeklyChart
        dailyGoal={20}
        weeklyStats={[
          {
            ...day,
            wordsStudied: 20,
            xpEarned: 70,
            vocabularyAnsweredCount: 1,
          },
        ]}
      />
    );
    const bar = screen.getByRole('img', {
      name: '2026-11-02 · 저장한 단어 1개',
    });
    expect(parseFloat(bar.style.height)).toBeGreaterThan(0);
    expect(
      screen.queryByRole('img', { name: /목표 달성/ })
    ).not.toBeInTheDocument();
    expect(screen.getByText('1개')).toBeInTheDocument();
    expect(screen.getByText('70')).toBeInTheDocument();
    expect(
      screen.queryByText('아직 이번 주 학습 활동이 없어요.')
    ).not.toBeInTheDocument();
  });

  it('shows zero-word lesson/kana/grammar activity without fabricating a word bar or XP', () => {
    render(
      <WeeklyChart
        weeklyStats={[{ ...day, hasStudied: true, vocabularyAnsweredCount: 0 }]}
      />
    );
    expect(
      screen.getByRole('img', { name: '2026-11-02 · 저장한 단어 0개' })
    ).toHaveStyle({ height: '0px' });
    expect(
      screen.getByRole('img', { name: '2026-11-02 · 학습 활동 있음' })
    ).toHaveClass('bg-primary');
    expect(
      screen.queryByText('아직 이번 주 학습 활동이 없어요.')
    ).not.toBeInTheDocument();
    expect(screen.getByText(/학습 활동 1일/)).toBeInTheDocument();
    expect(screen.getByText('0개')).toBeInTheDocument();
  });

  it('labels absent/null fields as legacy completion counts instead of turning unknown values into zero', () => {
    render(
      <WeeklyChart
        weeklyStats={[
          { ...day, wordsStudied: 3 },
          {
            ...day,
            date: '2026-11-03',
            wordsStudied: 4,
            vocabularyAnsweredCount: null,
          },
        ]}
      />
    );
    expect(
      screen.getByRole('img', { name: '2026-11-02 · 완료 집계 3개' })
    ).toBeInTheDocument();
    expect(
      screen.getByRole('img', { name: '2026-11-03 · 완료 집계 4개' })
    ).toBeInTheDocument();
    expect(
      screen.getByText('일부 날짜는 완료한 퀴즈 기준으로 표시해요.')
    ).toBeInTheDocument();
    expect(screen.getByText('7개')).toBeInTheDocument();
  });

  it('can show historical saved-answer activity without backfilling formal attendance', () => {
    const stats = [{ ...day, vocabularyAnsweredCount: 2 }];
    render(
      <>
        <WeeklyChart weeklyStats={stats} />
        <StreakBadge currentStreak={0} weeklyStats={stats} />
      </>
    );
    expect(
      screen.getByRole('img', { name: '2026-11-02 · 학습 활동 있음' })
    ).toBeInTheDocument();
    expect(
      screen.getByLabelText('월요일 · 학습 기록 없음')
    ).toBeInTheDocument();
    expect(stats[0].hasStudied).toBe(false);
  });

  it('updates on a new dashboard response after ACK without retaining an empty state', () => {
    const view = render(
      <WeeklyChart weeklyStats={[{ ...day, vocabularyAnsweredCount: 0 }]} />
    );
    expect(
      screen.getByText('아직 이번 주 학습 활동이 없어요.')
    ).toBeInTheDocument();
    view.rerender(
      <WeeklyChart weeklyStats={[{ ...day, vocabularyAnsweredCount: 1 }]} />
    );
    expect(
      screen.queryByText('아직 이번 주 학습 활동이 없어요.')
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole('img', { name: '2026-11-02 · 저장한 단어 1개' })
    ).toBeInTheDocument();
  });
});
