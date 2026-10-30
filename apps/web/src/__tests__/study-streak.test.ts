// @vitest-environment node

import { afterEach, describe, expect, it, vi } from 'vitest';
import { getTodayKST } from '@/lib/date';
import { updateStreak } from '@/lib/gamification';

vi.mock('@harukoto/database', () => ({ prisma: {} }));

const day = (value: string) => new Date(`${value}T00:00:00Z`);

afterEach(() => {
  vi.useRealTimers();
});

describe('getTodayKST', () => {
  it.each([
    ['2026-09-28T14:59:59.999Z', '2026-09-28'],
    ['2026-09-28T15:00:00Z', '2026-09-29'],
    ['2026-09-28T23:59:59.999Z', '2026-09-29'],
    ['2026-09-29T00:00:00Z', '2026-09-29'],
    ['2026-12-31T15:00:00Z', '2027-01-01'],
    ['2028-02-28T15:00:00Z', '2028-02-29'],
  ])(
    'should represent %s as the Korean date %s at UTC midnight',
    (instant, date) => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date('2000-01-01T00:00:00Z'));
      const now = new Date(instant);
      const originalTime = now.getTime();

      expect(getTodayKST(now)).toEqual(day(date));
      expect(now.getTime()).toBe(originalTime);
    }
  );

  it('should default to the current instant at Korean midnight', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-09-28T15:00:00Z'));

    expect(getTodayKST()).toEqual(day('2026-09-29'));
  });
});

describe('updateStreak KST date compatibility', () => {
  it('should preserve a streak for two completions in the same Korean morning', () => {
    const result = updateStreak(
      new Date('2026-09-28T15:30:00Z'),
      4,
      5,
      day('2026-09-29')
    );

    expect(result).toEqual({
      streakCount: 4,
      longestStreak: 5,
      streakBroken: false,
    });
  });

  it('should extend a streak for consecutive Korean mornings', () => {
    const result = updateStreak(
      new Date('2026-09-27T23:00:00Z'),
      4,
      5,
      day('2026-09-29')
    );

    expect(result).toEqual({
      streakCount: 5,
      longestStreak: 5,
      streakBroken: false,
    });
  });

  it('should extend across Korean midnight within one UTC day', () => {
    const result = updateStreak(
      new Date('2026-09-28T14:59:59Z'),
      4,
      5,
      day('2026-09-29')
    );

    expect(result).toEqual({
      streakCount: 5,
      longestStreak: 5,
      streakBroken: false,
    });
  });

  it('should preserve a streak across UTC midnight within one Korean day', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-09-29T00:00:00Z'));

    expect(updateStreak(new Date('2026-09-28T23:59:59Z'), 4, 5)).toEqual({
      streakCount: 4,
      longestStreak: 5,
      streakBroken: false,
    });
  });

  it('should default to the current Korean date when no date key is supplied', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-09-28T15:00:00Z'));

    expect(updateStreak(new Date('2026-09-28T14:59:59Z'), 5, 5)).toEqual({
      streakCount: 6,
      longestStreak: 6,
      streakBroken: false,
    });
  });

  it('should preserve the UTC-midnight date keys used by completion routes', () => {
    expect(updateStreak(day('2026-09-28'), 5, 5, day('2026-09-29'))).toEqual({
      streakCount: 6,
      longestStreak: 6,
      streakBroken: false,
    });
  });

  it('should preserve a newer study day when an older request completes', () => {
    expect(updateStreak(day('2026-09-30'), 5, 8, day('2026-09-29'))).toEqual({
      streakCount: 5,
      longestStreak: 8,
      streakBroken: false,
    });
  });

  it('should preserve stored counters on the same day even when the longest is inconsistent', () => {
    expect(updateStreak(day('2026-09-29'), 5, 3, day('2026-09-29'))).toEqual({
      streakCount: 5,
      longestStreak: 3,
      streakBroken: false,
    });
  });

  it('should start at one without a prior study date and preserve the historical best', () => {
    expect(updateStreak(null, 0, 8, day('2026-09-29'))).toEqual({
      streakCount: 1,
      longestStreak: 8,
      streakBroken: false,
    });
  });

  it('should break a streak only after a skipped Korean calendar day', () => {
    expect(
      updateStreak(new Date('2026-09-26T23:00:00Z'), 5, 8, day('2026-09-29'))
    ).toEqual({ streakCount: 1, longestStreak: 8, streakBroken: true });
  });

  it('should preserve the stored longest when a skipped day restarts the current streak', () => {
    expect(updateStreak(day('2026-09-27'), 5, 0, day('2026-09-29'))).toEqual({
      streakCount: 1,
      longestStreak: 0,
      streakBroken: true,
    });
  });

  it.each([
    ['2026-12-31', '2027-01-01'],
    ['2028-02-28', '2028-02-29'],
    ['2028-02-29', '2028-03-01'],
    ['2026-03-08', '2026-03-09'],
    ['2026-11-01', '2026-11-02'],
  ])(
    'should extend consecutive date keys across %s and %s',
    (previous, today) => {
      expect(updateStreak(day(previous), 4, 5, day(today))).toEqual({
        streakCount: 5,
        longestStreak: 5,
        streakBroken: false,
      });
    }
  );
});
