import { describe, expect, it } from 'vitest';
import { completionStudyDayCredit } from '@/lib/quiz-completion-study-day';

const now = new Date('2026-11-03T15:00:00Z'); // Nov 4 KST midnight
const yesterday = new Date('2026-11-03T14:59:59.999Z');
describe('completion study-day credit separation', () => {
  it('does not infer attendance from a late completion or future-dated answer', () => {
    expect(completionStudyDayCredit(null, [yesterday], now)).toEqual({
      credited: false,
      refreshStreak: false,
    });
    expect(
      completionStudyDayCredit(null, [new Date(now.getTime() + 1)], now)
    ).toEqual({ credited: false, refreshStreak: false });
  });
  it('credits a canonical first answer exactly at the KST boundary', () => {
    expect(
      completionStudyDayCredit(
        { studyDayCredited: false, xpEarned: 100 },
        [now],
        now
      )
    ).toEqual({ credited: true, refreshStreak: true });
  });
  it('preserves prior legacy and explicit recognition without refreshing its date', () => {
    for (const row of [
      { studyDayCredited: null, wordsStudied: 1 },
      { studyDayCredited: true },
    ]) {
      expect(completionStudyDayCredit(row, [yesterday], now)).toEqual({
        credited: true,
        refreshStreak: false,
      });
    }
  });
  it('respects explicit FALSE with positive XP even in compatibility OFF mode', () => {
    expect(
      completionStudyDayCredit(
        { studyDayCredited: false, xpEarned: 100 },
        [yesterday],
        now,
        false
      )
    ).toEqual({ credited: false, refreshStreak: false });
  });
  it('keeps the previous completion recognition in OFF mode for legacy/new days only', () => {
    expect(completionStudyDayCredit(null, [yesterday], now, false)).toEqual({
      credited: true,
      refreshStreak: true,
    });
    expect(
      completionStudyDayCredit(
        { studyDayCredited: null, xpEarned: 0 },
        [yesterday],
        now,
        false
      )
    ).toEqual({ credited: true, refreshStreak: true });
  });
});
