import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  calculateLevel,
  updateStreak,
  getAchievement,
  ACHIEVEMENTS,
  type AchievementType,
} from '@/lib/gamification';

// ==========================================
// calculateLevel
// ==========================================

describe('calculateLevel', () => {
  it('should return level 1 for 0 XP', () => {
    const result = calculateLevel(0);
    expect(result.level).toBe(1);
    expect(result.currentXp).toBe(0);
    expect(result.xpForNext).toBe(100);
  });

  it('should return level 1 for 99 XP', () => {
    const result = calculateLevel(99);
    expect(result.level).toBe(1);
    expect(result.currentXp).toBe(99);
    expect(result.xpForNext).toBe(100);
  });

  it('should return level 2 for exactly 100 XP', () => {
    const result = calculateLevel(100);
    expect(result.level).toBe(2);
    expect(result.currentXp).toBe(0);
    expect(result.xpForNext).toBe(300); // 2^2*100 - 1^2*100 = 400 - 100 = 300
  });

  it('should return level 3 for 400 XP', () => {
    const result = calculateLevel(400);
    expect(result.level).toBe(3);
    expect(result.currentXp).toBe(0);
    expect(result.xpForNext).toBe(500); // 3^2*100 - 2^2*100 = 900 - 400 = 500
  });

  it('should track partial progress within a level', () => {
    const result = calculateLevel(250);
    // level = floor(sqrt(250/100)) + 1 = floor(1.58) + 1 = 2
    expect(result.level).toBe(2);
    expect(result.currentXp).toBe(150); // 250 - 100
    expect(result.xpForNext).toBe(300); // 400 - 100
  });

  it('should handle large XP values', () => {
    const result = calculateLevel(10000);
    // level = floor(sqrt(100)) + 1 = 10 + 1 = 11
    expect(result.level).toBe(11);
  });
});

// ==========================================
// updateStreak
// ==========================================

describe('updateStreak', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-03-02T12:00:00Z'));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('should start streak at 1 when no last study date', () => {
    const result = updateStreak(null, 0, 0);
    expect(result.streakCount).toBe(1);
    expect(result.longestStreak).toBe(1);
    expect(result.streakBroken).toBe(false);
  });

  it('should preserve existing longestStreak on first study', () => {
    const result = updateStreak(null, 0, 5);
    expect(result.streakCount).toBe(1);
    expect(result.longestStreak).toBe(5);
  });

  it('should keep streak unchanged when studying same day', () => {
    const today = new Date('2026-03-02T08:00:00Z');
    const result = updateStreak(today, 3, 5);
    expect(result.streakCount).toBe(3);
    expect(result.longestStreak).toBe(5);
    expect(result.streakBroken).toBe(false);
  });

  it('should extend streak when studying consecutive day', () => {
    // Use a time that is clearly "yesterday" in any timezone (KST = UTC+9)
    const yesterday = new Date('2026-03-01T06:00:00Z'); // March 1 15:00 KST
    const result = updateStreak(yesterday, 3, 5);
    expect(result.streakCount).toBe(4);
    expect(result.longestStreak).toBe(5);
    expect(result.streakBroken).toBe(false);
  });

  it('should update longestStreak when extending beyond it', () => {
    const yesterday = new Date('2026-03-01T06:00:00Z');
    const result = updateStreak(yesterday, 5, 5);
    expect(result.streakCount).toBe(6);
    expect(result.longestStreak).toBe(6);
  });

  it('should break streak when more than 1 day gap', () => {
    const twoDaysAgo = new Date('2026-02-28T12:00:00Z');
    const result = updateStreak(twoDaysAgo, 10, 10);
    expect(result.streakCount).toBe(1);
    expect(result.longestStreak).toBe(10);
    expect(result.streakBroken).toBe(true);
  });

  it('should handle week-long gap', () => {
    const weekAgo = new Date('2026-02-23T12:00:00Z');
    const result = updateStreak(weekAgo, 7, 14);
    expect(result.streakCount).toBe(1);
    expect(result.longestStreak).toBe(14);
    expect(result.streakBroken).toBe(true);
  });
});

// ==========================================
// ACHIEVEMENTS data integrity
// ==========================================

describe('ACHIEVEMENTS', () => {
  it('should have unique types', () => {
    const types = ACHIEVEMENTS.map((a) => a.type);
    expect(new Set(types).size).toBe(types.length);
  });

  it('should have valid icon name strings (not emoji)', () => {
    for (const a of ACHIEVEMENTS) {
      // Icon names should be kebab-case, not Unicode emoji
      expect(a.emoji).toMatch(/^[a-z0-9-]+$/);
    }
  });

  it('should have thresholds for all non-special categories', () => {
    for (const a of ACHIEVEMENTS) {
      if (a.category !== 'special') {
        expect(a.threshold).toBeDefined();
        expect(a.threshold).toBeGreaterThan(0);
      }
    }
  });

  it('should have all required fields for every achievement', () => {
    for (const a of ACHIEVEMENTS) {
      expect(a.type).toBeTruthy();
      expect(a.title).toBeTruthy();
      expect(a.description).toBeTruthy();
      expect(a.emoji).toBeTruthy();
      expect(a.category).toBeTruthy();
    }
  });

  it('should contain exactly 20 achievements', () => {
    expect(ACHIEVEMENTS).toHaveLength(20);
  });
});

// ==========================================
// getAchievement
// ==========================================

describe('getAchievement', () => {
  it('should find existing achievement', () => {
    const result = getAchievement('first_quiz');
    expect(result).toBeDefined();
    expect(result!.title).toBe('첫 퀴즈 완료!');
    expect(result!.emoji).toBe('target');
  });

  it('should return undefined for non-existent type', () => {
    const result = getAchievement('non_existent' as AchievementType);
    expect(result).toBeUndefined();
  });

  it('should return correct icon name for each achievement', () => {
    const iconMap: Partial<Record<AchievementType, string>> = {
      first_quiz: 'target',
      quiz_100: 'trophy',
      perfect_quiz: 'check-check',
      streak_3: 'flame',
      streak_7: 'zap',
      level_5: 'star',
      xp_1000: 'gem',
    };

    for (const [type, expectedIcon] of Object.entries(iconMap)) {
      const result = getAchievement(type as AchievementType);
      expect(result?.emoji).toBe(expectedIcon);
    }
  });
});
