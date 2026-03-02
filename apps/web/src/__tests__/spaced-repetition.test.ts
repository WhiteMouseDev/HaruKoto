import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { calculateSM2 } from '@/lib/spaced-repetition';

describe('calculateSM2', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-03-02T12:00:00Z'));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  const defaultInput = {
    easeFactor: 2.5,
    interval: 0,
    streak: 0,
    isCorrect: true,
    timeSpentSeconds: 2,
  };

  describe('정답 처리', () => {
    it('should set interval to 1 on first correct answer', () => {
      const result = calculateSM2({ ...defaultInput, streak: 0 });
      expect(result.interval).toBe(1);
      expect(result.streak).toBe(1);
    });

    it('should set interval to 3 on second correct answer', () => {
      const result = calculateSM2({ ...defaultInput, streak: 1, interval: 1 });
      expect(result.interval).toBe(3);
      expect(result.streak).toBe(2);
    });

    it('should multiply interval by easeFactor on third+ correct answer', () => {
      const result = calculateSM2({
        ...defaultInput,
        streak: 2,
        interval: 3,
        easeFactor: 2.5,
      });
      // Math.round(3 * 2.5) = 8
      expect(result.interval).toBe(8);
      expect(result.streak).toBe(3);
    });

    it('should assign quality 5 for instant correct (<=3s)', () => {
      const result = calculateSM2({
        ...defaultInput,
        timeSpentSeconds: 2,
        easeFactor: 2.5,
      });
      // quality=5: ef + (0.1 - 0 * (0.08 + 0 * 0.02)) = 2.5 + 0.1 = 2.6
      expect(result.easeFactor).toBe(2.6);
    });

    it('should assign quality 4 for quick correct (<=8s)', () => {
      const result = calculateSM2({
        ...defaultInput,
        timeSpentSeconds: 5,
        easeFactor: 2.5,
      });
      // quality=4: ef + (0.1 - 1 * (0.08 + 1 * 0.02)) = 2.5 + 0.0 = 2.5
      expect(result.easeFactor).toBe(2.5);
    });

    it('should assign quality 3 for slow correct (>8s)', () => {
      const result = calculateSM2({
        ...defaultInput,
        timeSpentSeconds: 15,
        easeFactor: 2.5,
      });
      // quality=3: ef + (0.1 - 2 * (0.08 + 2 * 0.02)) = 2.5 + (0.1 - 0.24) = 2.5 - 0.14 = 2.36
      expect(result.easeFactor).toBe(2.36);
    });

    it('should set nextReviewAt to interval days from now', () => {
      const result = calculateSM2({ ...defaultInput, streak: 0 });
      // interval = 1, so next review is tomorrow
      const expected = new Date('2026-03-03T12:00:00Z');
      expect(result.nextReviewAt.toISOString()).toBe(expected.toISOString());
    });
  });

  describe('오답 처리', () => {
    it('should reset streak to 0 on incorrect answer', () => {
      const result = calculateSM2({
        ...defaultInput,
        isCorrect: false,
        streak: 5,
      });
      expect(result.streak).toBe(0);
      expect(result.interval).toBe(0);
    });

    it('should decrease easeFactor by 0.2 on incorrect answer', () => {
      const result = calculateSM2({
        ...defaultInput,
        isCorrect: false,
        easeFactor: 2.5,
      });
      expect(result.easeFactor).toBe(2.3);
    });

    it('should not let easeFactor go below 1.3', () => {
      const result = calculateSM2({
        ...defaultInput,
        isCorrect: false,
        easeFactor: 1.3,
      });
      expect(result.easeFactor).toBe(1.3);
    });

    it('should set nextReviewAt to 10 minutes from now on wrong answer', () => {
      const result = calculateSM2({
        ...defaultInput,
        isCorrect: false,
      });
      const expected = new Date('2026-03-02T12:10:00Z');
      expect(result.nextReviewAt.toISOString()).toBe(expected.toISOString());
    });
  });

  describe('경계값 테스트', () => {
    it('should handle exactly 3 seconds (boundary for quality 5)', () => {
      const result = calculateSM2({
        ...defaultInput,
        timeSpentSeconds: 3,
        easeFactor: 2.5,
      });
      // Exactly 3s is <= 3, so quality = 5
      expect(result.easeFactor).toBe(2.6);
    });

    it('should handle exactly 8 seconds (boundary for quality 4)', () => {
      const result = calculateSM2({
        ...defaultInput,
        timeSpentSeconds: 8,
        easeFactor: 2.5,
      });
      // Exactly 8s is <= 8, so quality = 4
      expect(result.easeFactor).toBe(2.5);
    });

    it('should handle minimum easeFactor with correct answer', () => {
      const result = calculateSM2({
        ...defaultInput,
        easeFactor: 1.3,
        timeSpentSeconds: 15,
      });
      // quality=3: 1.3 + (0.1 - 0.24) = 1.3 - 0.14 = 1.16 → clamped to 1.3
      expect(result.easeFactor).toBe(1.3);
    });

    it('should round easeFactor to 2 decimal places', () => {
      const result = calculateSM2({
        ...defaultInput,
        easeFactor: 2.5,
        timeSpentSeconds: 2,
      });
      expect(result.easeFactor).toBe(2.6);
      expect(
        result.easeFactor.toString().split('.')[1]?.length || 0
      ).toBeLessThanOrEqual(2);
    });
  });
});
