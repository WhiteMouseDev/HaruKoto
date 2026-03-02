import type { JlptLevel } from './content';

export type QuizType = 'vocabulary' | 'grammar' | 'kanji' | 'listening';
export type QuizMode = 'new' | 'review' | 'mixed';

export type QuizQuestion = {
  id: string;
  questionText: string;
  questionSubText?: string;
  options: {
    id: string;
    text: string;
  }[];
  hint?: string;
};

export type QuizSession = {
  sessionId: string;
  questions: QuizQuestion[];
  totalCount: number;
};

export type QuizAnswer = {
  isCorrect: boolean;
  correctOptionId: string;
  explanation: string;
};

export type QuizResult = {
  totalQuestions: number;
  correctCount: number;
  accuracy: number;
  totalTimeSeconds: number;
  experienceGained: number;
  streakBonus: number;
  incorrectItems: {
    questionId: string;
    word?: string;
    reading?: string;
    meaningKo?: string;
    correctAnswer: string;
    userAnswer: string;
  }[];
  newLevel?: number;
};
