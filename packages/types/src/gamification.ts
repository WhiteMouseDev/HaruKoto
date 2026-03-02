export type Streak = {
  currentStreak: number;
  longestStreak: number;
  weeklyStatus: {
    day: string;
    studied: boolean;
  }[];
  lastStudyDate: string | null;
};

export type DailyProgress = {
  dailyGoal: number;
  completedCount: number;
  progressPercent: number;
  experienceToday: number;
  quizResults: {
    type: string;
    count: number;
    correct: number;
  }[];
};

export type LevelInfo = {
  currentLevel: number;
  currentXP: number;
  requiredXP: number;
  progressPercent: number;
  title: string;
};
