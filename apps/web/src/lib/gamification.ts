import { prisma } from '@harukoto/database';

// ==========================================
// 레벨 시스템
// ==========================================

/**
 * 현재 XP 기반으로 레벨 계산
 * level = floor(sqrt(totalXP / 100)) + 1
 * @returns { level, currentXp, xpForNext }
 */
export function calculateLevel(totalXp: number): {
  level: number;
  currentXp: number;
  xpForNext: number;
} {
  const level = Math.floor(Math.sqrt(totalXp / 100)) + 1;
  // 현재 레벨 시작에 필요한 총 XP: (level - 1)^2 * 100
  const xpAtCurrentLevel = Math.pow(level - 1, 2) * 100;
  // 다음 레벨에 필요한 총 XP: level^2 * 100
  const xpAtNextLevel = Math.pow(level, 2) * 100;

  return {
    level,
    currentXp: totalXp - xpAtCurrentLevel,
    xpForNext: xpAtNextLevel - xpAtCurrentLevel,
  };
}

// ==========================================
// 스트릭 시스템
// ==========================================

/**
 * 연속 학습일(스트릭) 업데이트
 * @returns { streakCount, longestStreak, streakBroken }
 */
export function updateStreak(
  lastStudyDate: Date | null,
  currentStreakCount: number,
  currentLongestStreak: number
): {
  streakCount: number;
  longestStreak: number;
  streakBroken: boolean;
} {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  if (!lastStudyDate) {
    return { streakCount: 1, longestStreak: Math.max(1, currentLongestStreak), streakBroken: false };
  }

  const lastDate = new Date(lastStudyDate);
  const lastDay = new Date(lastDate.getFullYear(), lastDate.getMonth(), lastDate.getDate());
  const diffDays = Math.floor((today.getTime() - lastDay.getTime()) / (1000 * 60 * 60 * 24));

  if (diffDays === 0) {
    // 오늘 이미 학습함 - 변경 없음
    return {
      streakCount: currentStreakCount,
      longestStreak: currentLongestStreak,
      streakBroken: false,
    };
  }

  if (diffDays === 1) {
    // 어제 학습함 - 스트릭 연장
    const newStreak = currentStreakCount + 1;
    return {
      streakCount: newStreak,
      longestStreak: Math.max(newStreak, currentLongestStreak),
      streakBroken: false,
    };
  }

  // 하루 이상 건너뜀 - 스트릭 리셋
  return {
    streakCount: 1,
    longestStreak: currentLongestStreak,
    streakBroken: true,
  };
}

// ==========================================
// 업적 시스템
// ==========================================

export type AchievementType =
  | 'first_quiz'
  | 'first_conversation'
  | 'quiz_10'
  | 'quiz_50'
  | 'quiz_100'
  | 'conversation_10'
  | 'conversation_50'
  | 'streak_3'
  | 'streak_7'
  | 'streak_30'
  | 'streak_100'
  | 'level_5'
  | 'level_10'
  | 'level_20'
  | 'perfect_quiz'
  | 'words_50'
  | 'words_100'
  | 'xp_1000'
  | 'xp_5000'
  | 'xp_10000';

export type AchievementDef = {
  type: AchievementType;
  title: string;
  description: string;
  emoji: string;
};

export const ACHIEVEMENTS: AchievementDef[] = [
  // 퀴즈
  { type: 'first_quiz', title: '첫 퀴즈 완료!', description: '첫 번째 퀴즈를 완료했어요', emoji: '🎯' },
  { type: 'quiz_10', title: '퀴즈 10회 달성', description: '퀴즈를 10번 완료했어요', emoji: '📝' },
  { type: 'quiz_50', title: '퀴즈 50회 달성', description: '퀴즈를 50번 완료했어요', emoji: '📚' },
  { type: 'quiz_100', title: '퀴즈 마스터', description: '퀴즈를 100번 완료했어요', emoji: '🏆' },
  { type: 'perfect_quiz', title: '퍼펙트!', description: '퀴즈에서 전부 맞았어요', emoji: '💯' },
  // 회화
  { type: 'first_conversation', title: '첫 회화 완료!', description: '첫 번째 AI 회화를 완료했어요', emoji: '💬' },
  { type: 'conversation_10', title: '회화 10회 달성', description: 'AI 회화를 10번 완료했어요', emoji: '🗣️' },
  { type: 'conversation_50', title: '대화의 달인', description: 'AI 회화를 50번 완료했어요', emoji: '🎙️' },
  // 스트릭
  { type: 'streak_3', title: '3일 연속 학습', description: '3일 연속으로 학습했어요', emoji: '🔥' },
  { type: 'streak_7', title: '일주일 연속 학습', description: '7일 연속으로 학습했어요', emoji: '⚡' },
  { type: 'streak_30', title: '한 달 연속 학습', description: '30일 연속으로 학습했어요', emoji: '🌟' },
  { type: 'streak_100', title: '100일 연속 학습', description: '100일 연속으로 학습했어요', emoji: '👑' },
  // 단어 학습
  { type: 'words_50', title: '단어 50개 학습', description: '총 50개의 단어를 학습했어요', emoji: '📖' },
  { type: 'words_100', title: '단어 100개 학습', description: '총 100개의 단어를 학습했어요', emoji: '📕' },
  // 레벨
  { type: 'level_5', title: '레벨 5 달성', description: '레벨 5에 도달했어요', emoji: '⭐' },
  { type: 'level_10', title: '레벨 10 달성', description: '레벨 10에 도달했어요', emoji: '🌙' },
  { type: 'level_20', title: '레벨 20 달성', description: '레벨 20에 도달했어요', emoji: '🌸' },
  // XP
  { type: 'xp_1000', title: 'XP 1,000 달성', description: '총 1,000 XP를 모았어요', emoji: '💎' },
  { type: 'xp_5000', title: 'XP 5,000 달성', description: '총 5,000 XP를 모았어요', emoji: '🏅' },
  { type: 'xp_10000', title: 'XP 10,000 달성', description: '총 10,000 XP를 모았어요', emoji: '🎖️' },
];

export function getAchievement(type: AchievementType): AchievementDef | undefined {
  return ACHIEVEMENTS.find((a) => a.type === type);
}

export type GameEvent = {
  type: 'level_up' | 'streak' | 'achievement' | 'xp';
  title: string;
  body: string;
  emoji: string;
};

/**
 * 사용자의 현재 상태를 기반으로 새 업적을 확인하고 부여
 * @returns 새로 획득한 업적 + 레벨업/스트릭 이벤트 목록
 */
export async function checkAndGrantAchievements(
  userId: string,
  context: {
    totalXp: number;
    newLevel: number;
    oldLevel: number;
    streakCount: number;
    quizCount?: number;
    conversationCount?: number;
    isPerfectQuiz?: boolean;
    totalWordsStudied?: number;
  }
): Promise<GameEvent[]> {
  const events: GameEvent[] = [];

  // 기존 업적 조회
  const existing = await prisma.userAchievement.findMany({
    where: { userId },
    select: { achievementType: true },
  });
  const existingTypes = new Set(existing.map((a) => a.achievementType));

  // 부여 대상 업적 체크
  const toGrant: AchievementType[] = [];

  // 레벨업 이벤트
  if (context.newLevel > context.oldLevel) {
    events.push({
      type: 'level_up',
      title: '레벨 업!',
      body: `레벨 ${context.newLevel}에 도달했어요!`,
      emoji: '🎉',
    });
  }

  // 레벨 업적
  if (context.newLevel >= 5) toGrant.push('level_5');
  if (context.newLevel >= 10) toGrant.push('level_10');
  if (context.newLevel >= 20) toGrant.push('level_20');

  // 스트릭 업적
  if (context.streakCount >= 3) toGrant.push('streak_3');
  if (context.streakCount >= 7) toGrant.push('streak_7');
  if (context.streakCount >= 30) toGrant.push('streak_30');
  if (context.streakCount >= 100) toGrant.push('streak_100');

  // XP 업적
  if (context.totalXp >= 1000) toGrant.push('xp_1000');
  if (context.totalXp >= 5000) toGrant.push('xp_5000');
  if (context.totalXp >= 10000) toGrant.push('xp_10000');

  // 퀴즈 업적
  if (context.quizCount !== undefined) {
    if (context.quizCount >= 1) toGrant.push('first_quiz');
    if (context.quizCount >= 10) toGrant.push('quiz_10');
    if (context.quizCount >= 50) toGrant.push('quiz_50');
    if (context.quizCount >= 100) toGrant.push('quiz_100');
  }
  if (context.isPerfectQuiz) toGrant.push('perfect_quiz');

  // 단어 학습 업적
  if (context.totalWordsStudied !== undefined) {
    if (context.totalWordsStudied >= 50) toGrant.push('words_50');
    if (context.totalWordsStudied >= 100) toGrant.push('words_100');
  }

  // 회화 업적
  if (context.conversationCount !== undefined) {
    if (context.conversationCount >= 1) toGrant.push('first_conversation');
    if (context.conversationCount >= 10) toGrant.push('conversation_10');
    if (context.conversationCount >= 50) toGrant.push('conversation_50');
  }

  // 새 업적만 필터링하여 부여
  const newAchievements = toGrant.filter((t) => !existingTypes.has(t));

  for (const type of newAchievements) {
    const def = getAchievement(type);
    if (!def) continue;

    await prisma.userAchievement.create({
      data: {
        userId,
        achievementType: type,
      },
    });

    events.push({
      type: 'achievement',
      title: def.title,
      body: def.description,
      emoji: def.emoji,
    });
  }

  return events;
}
