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
  | 'xp_10000'
  | 'kana_first_char'
  | 'kana_hiragana_complete'
  | 'kana_katakana_complete';

export type AchievementCategory = 'level' | 'streak' | 'xp' | 'quiz' | 'words' | 'conversation' | 'special' | 'kana';

export type AchievementDef = {
  type: AchievementType;
  title: string;
  description: string;
  emoji: string;
  category: AchievementCategory;
  threshold?: number;
};

export const ACHIEVEMENTS: AchievementDef[] = [
  // 퀴즈
  { type: 'first_quiz', title: '첫 퀴즈 완료!', description: '첫 번째 퀴즈를 완료했어요', emoji: 'target', category: 'quiz', threshold: 1 },
  { type: 'quiz_10', title: '퀴즈 10회 달성', description: '퀴즈를 10번 완료했어요', emoji: 'file-text', category: 'quiz', threshold: 10 },
  { type: 'quiz_50', title: '퀴즈 50회 달성', description: '퀴즈를 50번 완료했어요', emoji: 'library', category: 'quiz', threshold: 50 },
  { type: 'quiz_100', title: '퀴즈 마스터', description: '퀴즈를 100번 완료했어요', emoji: 'trophy', category: 'quiz', threshold: 100 },
  { type: 'perfect_quiz', title: '퍼펙트!', description: '퀴즈에서 전부 맞았어요', emoji: 'check-check', category: 'special' },
  // 회화
  { type: 'first_conversation', title: '첫 회화 완료!', description: '첫 번째 AI 회화를 완료했어요', emoji: 'message-circle', category: 'conversation', threshold: 1 },
  { type: 'conversation_10', title: '회화 10회 달성', description: 'AI 회화를 10번 완료했어요', emoji: 'messages-square', category: 'conversation', threshold: 10 },
  { type: 'conversation_50', title: '대화의 달인', description: 'AI 회화를 50번 완료했어요', emoji: 'mic', category: 'conversation', threshold: 50 },
  // 스트릭
  { type: 'streak_3', title: '3일 연속 학습', description: '3일 연속으로 학습했어요', emoji: 'flame', category: 'streak', threshold: 3 },
  { type: 'streak_7', title: '일주일 연속 학습', description: '7일 연속으로 학습했어요', emoji: 'zap', category: 'streak', threshold: 7 },
  { type: 'streak_30', title: '한 달 연속 학습', description: '30일 연속으로 학습했어요', emoji: 'sparkles', category: 'streak', threshold: 30 },
  { type: 'streak_100', title: '100일 연속 학습', description: '100일 연속으로 학습했어요', emoji: 'crown', category: 'streak', threshold: 100 },
  // 단어 학습
  { type: 'words_50', title: '단어 50개 학습', description: '총 50개의 단어를 학습했어요', emoji: 'book-open', category: 'words', threshold: 50 },
  { type: 'words_100', title: '단어 100개 학습', description: '총 100개의 단어를 학습했어요', emoji: 'book-marked', category: 'words', threshold: 100 },
  // 레벨
  { type: 'level_5', title: '레벨 5 달성', description: '레벨 5에 도달했어요', emoji: 'star', category: 'level', threshold: 5 },
  { type: 'level_10', title: '레벨 10 달성', description: '레벨 10에 도달했어요', emoji: 'moon', category: 'level', threshold: 10 },
  { type: 'level_20', title: '레벨 20 달성', description: '레벨 20에 도달했어요', emoji: 'flower-2', category: 'level', threshold: 20 },
  // XP
  { type: 'xp_1000', title: 'XP 1,000 달성', description: '총 1,000 XP를 모았어요', emoji: 'gem', category: 'xp', threshold: 1000 },
  { type: 'xp_5000', title: 'XP 5,000 달성', description: '총 5,000 XP를 모았어요', emoji: 'medal', category: 'xp', threshold: 5000 },
  { type: 'xp_10000', title: 'XP 10,000 달성', description: '총 10,000 XP를 모았어요', emoji: 'award', category: 'xp', threshold: 10000 },
  // 가나
  { type: 'kana_first_char', title: '첫 글자!', description: '첫 번째 가나를 배웠어요', emoji: 'sprout', category: 'kana' },
  { type: 'kana_hiragana_complete', title: 'ひらがな達人', description: '히라가나를 전부 마스터했어요', emoji: 'trophy', category: 'kana' },
  { type: 'kana_katakana_complete', title: 'カタカナ達人', description: '가타카나를 전부 마스터했어요', emoji: 'trophy', category: 'kana' },
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

// ==========================================
// 캐릭터 해금 체크
// ==========================================

const JLPT_LEVEL_ORDER = ['N5', 'N4', 'N3', 'N2', 'N1'];

/**
 * JLPT 레벨 변경 시 새로 해금된 캐릭터 체크
 */
export async function checkCharacterUnlocks(
  oldLevel: string,
  newLevel: string
): Promise<GameEvent[]> {
  const oldIdx = JLPT_LEVEL_ORDER.indexOf(oldLevel);
  const newIdx = JLPT_LEVEL_ORDER.indexOf(newLevel);

  if (newIdx <= oldIdx) return [];

  const unlockedLevels = JLPT_LEVEL_ORDER.slice(oldIdx + 1, newIdx + 1);

  const characters = await prisma.aiCharacter.findMany({
    where: {
      unlockCondition: { in: unlockedLevels },
      isActive: true,
    },
    select: { name: true, nameJa: true, avatarEmoji: true },
  });

  return characters.map((char) => ({
    type: 'achievement' as const,
    title: '새 캐릭터 해금!',
    body: `${char.name}(${char.nameJa})와 대화할 수 있게 되었어요!`,
    emoji: char.avatarEmoji,
  }));
}

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
    kanaFirstChar?: boolean;
    kanaHiraganaComplete?: boolean;
    kanaKatakanaComplete?: boolean;
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
      emoji: 'party-popper',
    });
  }

  // 카테고리별 컨텍스트 값 매핑
  const contextMap: Record<string, number | undefined> = {
    level: context.newLevel,
    streak: context.streakCount,
    xp: context.totalXp,
    quiz: context.quizCount,
    words: context.totalWordsStudied,
    conversation: context.conversationCount,
  };

  for (const achievement of ACHIEVEMENTS) {
    if (achievement.category === 'special') {
      if (achievement.type === 'perfect_quiz' && context.isPerfectQuiz) {
        toGrant.push(achievement.type);
      }
      continue;
    }

    if (achievement.category === 'kana') {
      if (achievement.type === 'kana_first_char' && context.kanaFirstChar) {
        toGrant.push(achievement.type);
      } else if (achievement.type === 'kana_hiragana_complete' && context.kanaHiraganaComplete) {
        toGrant.push(achievement.type);
      } else if (achievement.type === 'kana_katakana_complete' && context.kanaKatakanaComplete) {
        toGrant.push(achievement.type);
      }
      continue;
    }

    const value = contextMap[achievement.category];
    if (value !== undefined && achievement.threshold !== undefined && value >= achievement.threshold) {
      toGrant.push(achievement.type);
    }
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
