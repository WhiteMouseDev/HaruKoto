import { describe, it, expect } from 'vitest';
import { REWARDS, QUIZ_CONFIG, SRS_CONFIG, PAGINATION } from '@/lib/constants';

describe('REWARDS', () => {
  it('should have positive XP per correct quiz answer', () => {
    expect(REWARDS.QUIZ_XP_PER_CORRECT).toBeGreaterThan(0);
  });

  it('should have positive conversation XP', () => {
    expect(REWARDS.CONVERSATION_COMPLETE_XP).toBeGreaterThan(0);
  });
});

describe('QUIZ_CONFIG', () => {
  it('should have valid default count', () => {
    expect(QUIZ_CONFIG.DEFAULT_COUNT).toBeGreaterThan(0);
  });

  it('should have GREAT threshold higher than GOOD', () => {
    expect(QUIZ_CONFIG.ACCURACY_THRESHOLDS.GREAT).toBeGreaterThan(
      QUIZ_CONFIG.ACCURACY_THRESHOLDS.GOOD
    );
  });

  it('should have thresholds between 0 and 100', () => {
    expect(QUIZ_CONFIG.ACCURACY_THRESHOLDS.GREAT).toBeLessThanOrEqual(100);
    expect(QUIZ_CONFIG.ACCURACY_THRESHOLDS.GOOD).toBeGreaterThan(0);
  });

  it('should have review ratio between 0 and 1', () => {
    expect(QUIZ_CONFIG.REVIEW_RATIO).toBeGreaterThan(0);
    expect(QUIZ_CONFIG.REVIEW_RATIO).toBeLessThanOrEqual(1);
  });

  it('should have wrong options count for 4-choice quiz', () => {
    expect(QUIZ_CONFIG.WRONG_OPTIONS_COUNT).toBe(3); // 1 correct + 3 wrong = 4
  });
});

describe('SRS_CONFIG', () => {
  it('should have INSTANT threshold less than QUICK', () => {
    expect(SRS_CONFIG.SPEED_THRESHOLDS.INSTANT).toBeLessThan(
      SRS_CONFIG.SPEED_THRESHOLDS.QUICK
    );
  });

  it('should have increasing initial intervals', () => {
    expect(SRS_CONFIG.INITIAL_INTERVALS[0]).toBeLessThan(
      SRS_CONFIG.INITIAL_INTERVALS[1]
    );
  });

  it('should have mastery interval greater than initial intervals', () => {
    expect(SRS_CONFIG.MASTERY_INTERVAL).toBeGreaterThan(
      SRS_CONFIG.INITIAL_INTERVALS[1]
    );
  });

  it('should have minimum ease factor greater than 1', () => {
    expect(SRS_CONFIG.MIN_EASE_FACTOR).toBeGreaterThan(1);
  });

  it('should have positive incorrect penalty', () => {
    expect(SRS_CONFIG.INCORRECT_PENALTY).toBeGreaterThan(0);
    expect(SRS_CONFIG.INCORRECT_PENALTY).toBeLessThan(1);
  });

  it('should have positive review delay', () => {
    expect(SRS_CONFIG.REVIEW_DELAY_MINUTES).toBeGreaterThan(0);
  });
});

describe('PAGINATION', () => {
  it('should have default page size less than max', () => {
    expect(PAGINATION.DEFAULT_PAGE_SIZE).toBeLessThanOrEqual(
      PAGINATION.MAX_PAGE_SIZE
    );
  });

  it('should have positive page sizes', () => {
    expect(PAGINATION.DEFAULT_PAGE_SIZE).toBeGreaterThan(0);
    expect(PAGINATION.MAX_PAGE_SIZE).toBeGreaterThan(0);
  });
});
