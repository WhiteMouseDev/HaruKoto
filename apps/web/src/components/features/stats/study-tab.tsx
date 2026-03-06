'use client';

import { useMemo } from 'react';
import { motion } from 'framer-motion';
import {
  BookOpen,
  BookText,
  MessageCircle,
  Target,
  Clock,
  Zap,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';

type LevelProgress = {
  vocabulary: { total: number; mastered: number; inProgress: number };
  grammar: { total: number; mastered: number; inProgress: number };
};

type HistoryRecord = {
  date: string;
  wordsStudied: number;
  quizzesCompleted: number;
  correctAnswers: number;
  totalAnswers: number;
  conversationCount: number;
  studyTimeSeconds: number;
  xpEarned: number;
};

type StudyTabProps = {
  levelProgress: LevelProgress;
  historyRecords: HistoryRecord[];
};

const item = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3 } },
};

function formatTime(seconds: number): string {
  const mins = Math.round(seconds / 60);
  if (mins < 60) return `${mins}분`;
  const hours = Math.floor(mins / 60);
  const remainder = mins % 60;
  return remainder > 0 ? `${hours}시간 ${remainder}분` : `${hours}시간`;
}

export function StudyTab({
  levelProgress,
  historyRecords,
}: StudyTabProps) {
  const cumulative = useMemo(() => {
    let totalWords = 0;
    let totalQuizzes = 0;
    let totalCorrect = 0;
    let totalAnswers = 0;
    let totalConversations = 0;
    let totalStudySeconds = 0;
    let totalXp = 0;

    for (const r of historyRecords) {
      totalWords += r.wordsStudied;
      totalQuizzes += r.quizzesCompleted;
      totalCorrect += r.correctAnswers;
      totalAnswers += r.totalAnswers;
      totalConversations += r.conversationCount;
      totalStudySeconds += r.studyTimeSeconds;
      totalXp += r.xpEarned;
    }

    return {
      totalWords,
      totalQuizzes,
      totalCorrect,
      totalAnswers,
      accuracy: totalAnswers > 0 ? Math.round((totalCorrect / totalAnswers) * 100) : 0,
      totalConversations,
      totalStudySeconds,
      totalXp,
    };
  }, [historyRecords]);

  const vocab = levelProgress.vocabulary;
  const grammar = levelProgress.grammar;

  const vocabPct = vocab.total > 0 ? Math.round((vocab.mastered / vocab.total) * 100) : 0;
  const grammarPct = grammar.total > 0 ? Math.round((grammar.mastered / grammar.total) * 100) : 0;

  return (
    <motion.div
      className="flex flex-col gap-3"
      initial="hidden"
      animate="show"
      variants={{ show: { transition: { staggerChildren: 0.08 } } }}
    >
      {/* Cumulative Summary */}
      <motion.div variants={item}>
        <Card>
          <CardContent className="p-4">
            <h3 className="mb-3 font-semibold">누적 학습 요약</h3>
            <div className="grid grid-cols-3 gap-3">
              <div className="flex flex-col items-center gap-1 rounded-lg bg-primary/10 p-3">
                <Target className="text-primary size-4" />
                <span className="text-lg font-bold">{cumulative.totalQuizzes}</span>
                <span className="text-muted-foreground text-[11px]">퀴즈 완료</span>
              </div>
              <div className="flex flex-col items-center gap-1 rounded-lg bg-primary/10 p-3">
                <Zap className="text-primary size-4" />
                <span className="text-lg font-bold">{cumulative.accuracy}%</span>
                <span className="text-muted-foreground text-[11px]">정답률</span>
              </div>
              <div className="flex flex-col items-center gap-1 rounded-lg bg-primary/10 p-3">
                <Clock className="text-primary size-4" />
                <span className="text-lg font-bold">
                  {formatTime(cumulative.totalStudySeconds)}
                </span>
                <span className="text-muted-foreground text-[11px]">총 학습</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </motion.div>

      {/* Vocabulary */}
      <motion.div variants={item}>
        <Card>
          <CardContent className="flex flex-col gap-3 p-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <BookOpen className="text-primary size-5" />
                <span className="font-semibold">단어</span>
              </div>
              <span className="text-muted-foreground text-sm">
                {vocabPct}% 마스터
              </span>
            </div>
            <Progress value={vocabPct} />
            <div className="flex justify-between text-xs">
              <div className="flex items-center gap-1.5">
                <div className="bg-primary size-2 rounded-full" />
                <span className="text-muted-foreground">
                  마스터 <span className="text-foreground font-medium">{vocab.mastered}개</span>
                </span>
              </div>
              <div className="flex items-center gap-1.5">
                <div className="bg-primary/40 size-2 rounded-full" />
                <span className="text-muted-foreground">
                  학습 중 <span className="text-foreground font-medium">{vocab.inProgress}개</span>
                </span>
              </div>
              <div className="flex items-center gap-1.5">
                <div className="bg-secondary size-2 rounded-full" />
                <span className="text-muted-foreground">
                  미학습 <span className="text-foreground font-medium">{Math.max(0, vocab.total - vocab.mastered - vocab.inProgress)}개</span>
                </span>
              </div>
            </div>
          </CardContent>
        </Card>
      </motion.div>

      {/* Grammar */}
      <motion.div variants={item}>
        <Card>
          <CardContent className="flex flex-col gap-3 p-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <BookText className="text-hk-green size-5" />
                <span className="font-semibold">문법</span>
              </div>
              <span className="text-muted-foreground text-sm">
                {grammarPct}% 마스터
              </span>
            </div>
            <Progress value={grammarPct} />
            <div className="flex justify-between text-xs">
              <div className="flex items-center gap-1.5">
                <div className="bg-primary size-2 rounded-full" />
                <span className="text-muted-foreground">
                  마스터 <span className="text-foreground font-medium">{grammar.mastered}개</span>
                </span>
              </div>
              <div className="flex items-center gap-1.5">
                <div className="bg-primary/40 size-2 rounded-full" />
                <span className="text-muted-foreground">
                  학습 중 <span className="text-foreground font-medium">{grammar.inProgress}개</span>
                </span>
              </div>
              <div className="flex items-center gap-1.5">
                <div className="bg-secondary size-2 rounded-full" />
                <span className="text-muted-foreground">
                  미학습 <span className="text-foreground font-medium">{Math.max(0, grammar.total - grammar.mastered - grammar.inProgress)}개</span>
                </span>
              </div>
            </div>
          </CardContent>
        </Card>
      </motion.div>

      {/* Conversation */}
      <motion.div variants={item}>
        <Card>
          <CardContent className="flex flex-col gap-3 p-4">
            <div className="flex items-center gap-2">
              <MessageCircle className="text-hk-blue size-5" />
              <span className="font-semibold">회화</span>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="flex flex-col rounded-lg bg-secondary p-3">
                <span className="text-xl font-bold">{cumulative.totalConversations}회</span>
                <span className="text-muted-foreground text-[11px]">총 대화 수</span>
              </div>
              <div className="flex flex-col rounded-lg bg-secondary p-3">
                <span className="text-xl font-bold">
                  {formatTime(cumulative.totalStudySeconds)}
                </span>
                <span className="text-muted-foreground text-[11px]">대화 시간</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </motion.div>
  );
}
