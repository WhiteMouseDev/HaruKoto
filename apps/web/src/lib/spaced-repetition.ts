import { SRS_CONFIG } from '@/lib/constants';

/**
 * SM-2 Spaced Repetition Algorithm
 * Based on SuperMemo SM-2 algorithm for optimal review scheduling
 *
 * easeFactor: 난이도 계수 (최소 1.3, 기본 2.5)
 * interval: 복습 간격 (일 단위)
 * quality: 응답 품질 (0-5)
 *   5: 완벽 (즉시 정답)
 *   4: 약간 망설임 후 정답
 *   3: 어렵게 정답
 *   2: 오답 (힌트 후 기억)
 *   1: 오답 (약간 기억)
 *   0: 완전 오답
 */

interface SM2Input {
  easeFactor: number;
  interval: number;
  streak: number;
  isCorrect: boolean;
  timeSpentSeconds: number;
}

interface SM2Result {
  easeFactor: number;
  interval: number;
  streak: number;
  nextReviewAt: Date;
}

export function calculateSM2({
  easeFactor,
  interval,
  streak,
  isCorrect,
  timeSpentSeconds,
}: SM2Input): SM2Result {
  // Determine quality based on correctness and time spent
  let quality: number;
  if (isCorrect) {
    if (timeSpentSeconds <= SRS_CONFIG.SPEED_THRESHOLDS.INSTANT)
      quality = 5; // instant
    else if (timeSpentSeconds <= SRS_CONFIG.SPEED_THRESHOLDS.QUICK)
      quality = 4; // quick
    else quality = 3; // slow but correct
  } else {
    quality = 1; // incorrect
  }

  let newEaseFactor = easeFactor;
  let newInterval: number;
  let newStreak: number;

  if (quality >= 3) {
    // Correct answer
    newStreak = streak + 1;
    if (newStreak === 1) {
      newInterval = SRS_CONFIG.INITIAL_INTERVALS[0];
    } else if (newStreak === 2) {
      newInterval = SRS_CONFIG.INITIAL_INTERVALS[1];
    } else {
      newInterval = Math.round(interval * easeFactor);
    }
    newEaseFactor =
      easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  } else {
    // Incorrect answer - reset
    newStreak = 0;
    newInterval = 0; // review again soon (within minutes/hours)
    newEaseFactor = Math.max(SRS_CONFIG.MIN_EASE_FACTOR, easeFactor - SRS_CONFIG.INCORRECT_PENALTY);
  }

  // Ensure ease factor doesn't go below minimum
  newEaseFactor = Math.max(SRS_CONFIG.MIN_EASE_FACTOR, newEaseFactor);

  // Calculate next review date
  const nextReviewAt = new Date();
  if (newInterval === 0) {
    // Wrong answer: review after delay
    nextReviewAt.setMinutes(nextReviewAt.getMinutes() + SRS_CONFIG.REVIEW_DELAY_MINUTES);
  } else {
    nextReviewAt.setDate(nextReviewAt.getDate() + newInterval);
  }

  return {
    easeFactor: Math.round(newEaseFactor * 100) / 100,
    interval: newInterval,
    streak: newStreak,
    nextReviewAt,
  };
}
