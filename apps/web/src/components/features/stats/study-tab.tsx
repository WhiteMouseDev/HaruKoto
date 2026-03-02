'use client';

import { motion } from 'framer-motion';
import { BookOpen, BookText, Languages, MessageCircle } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';

type TodaySummary = {
  wordsStudied: number;
  quizzesCompleted: number;
  correctAnswers: number;
  totalAnswers: number;
  xpEarned: number;
  goalProgress: number;
};

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
  today: TodaySummary;
  levelProgress: LevelProgress;
  historyRecords: HistoryRecord[];
};

type CategoryData = {
  icon: React.ReactNode;
  name: string;
  accuracy: number;
  total: number;
  mastered: number;
  inProgress: number;
  detail1Label: string;
  detail1Value: string;
  detail2Label: string;
  detail2Value: string;
};

const item = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3 } },
};

export function StudyTab({
  today,
  levelProgress,
  historyRecords,
}: StudyTabProps) {
  const vocabAccuracy =
    today.totalAnswers > 0
      ? Math.round((today.correctAnswers / today.totalAnswers) * 100)
      : 0;

  const totalConversations = historyRecords.reduce(
    (sum, r) => sum + r.conversationCount,
    0
  );

  const totalStudyMinutes = historyRecords.reduce(
    (sum, r) => sum + Math.round(r.studyTimeSeconds / 60),
    0
  );

  const categories: CategoryData[] = [
    {
      icon: <BookOpen className="text-primary size-5" />,
      name: '단어',
      accuracy: vocabAccuracy,
      total: levelProgress.vocabulary.total,
      mastered: levelProgress.vocabulary.mastered,
      inProgress: levelProgress.vocabulary.inProgress,
      detail1Label: '마스터',
      detail1Value: `${levelProgress.vocabulary.mastered}개`,
      detail2Label: '학습 중',
      detail2Value: `${levelProgress.vocabulary.inProgress}개`,
    },
    {
      icon: <BookText className="text-hk-green size-5" />,
      name: '문법',
      accuracy:
        levelProgress.grammar.total > 0
          ? Math.round(
              (levelProgress.grammar.mastered / levelProgress.grammar.total) *
                100
            )
          : 0,
      total: levelProgress.grammar.total,
      mastered: levelProgress.grammar.mastered,
      inProgress: levelProgress.grammar.inProgress,
      detail1Label: '마스터',
      detail1Value: `${levelProgress.grammar.mastered}개`,
      detail2Label: '학습 중',
      detail2Value: `${levelProgress.grammar.inProgress}개`,
    },
    {
      icon: <Languages className="text-hk-yellow size-5" />,
      name: '한자',
      accuracy: 0,
      total: 0,
      mastered: 0,
      inProgress: 0,
      detail1Label: '마스터',
      detail1Value: '0개',
      detail2Label: '학습 중',
      detail2Value: '0개',
    },
    {
      icon: <MessageCircle className="text-hk-blue size-5" />,
      name: '회화',
      accuracy: 0,
      total: totalConversations,
      mastered: 0,
      inProgress: 0,
      detail1Label: '대화',
      detail1Value: `${totalConversations}회`,
      detail2Label: '시간',
      detail2Value: `${totalStudyMinutes}분`,
    },
  ];

  return (
    <motion.div
      className="flex flex-col gap-4"
      initial="hidden"
      animate="show"
      variants={{ show: { transition: { staggerChildren: 0.08 } } }}
    >
      <motion.div variants={item}>
        <Card>
          <CardContent className="flex flex-col gap-1 p-4">
            <h3 className="mb-2 font-semibold">카테고리별 학습</h3>
            {categories.map((cat, i) => (
              <motion.div
                key={cat.name}
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: i * 0.08, duration: 0.3 }}
                className="border-border flex flex-col gap-2 border-b py-3 last:border-b-0"
              >
                {/* Category header */}
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    {cat.icon}
                    <span className="font-medium">{cat.name}</span>
                  </div>
                  <span className="text-sm font-semibold">
                    {cat.name === '회화'
                      ? `${cat.total}회`
                      : `정답률 ${cat.accuracy}%`}
                  </span>
                </div>

                {/* Progress bar */}
                {cat.name !== '회화' ? (
                  <Progress
                    value={cat.total > 0 ? (cat.mastered / cat.total) * 100 : 0}
                  />
                ) : (
                  <Progress value={cat.total > 0 ? Math.min(cat.total * 10, 100) : 0} />
                )}

                {/* Details */}
                <div className="text-muted-foreground flex gap-4 text-xs">
                  <span>
                    {cat.detail1Label}:{' '}
                    <span className="text-foreground font-medium">
                      {cat.detail1Value}
                    </span>
                  </span>
                  <span>
                    {cat.detail2Label}:{' '}
                    <span className="text-foreground font-medium">
                      {cat.detail2Value}
                    </span>
                  </span>
                </div>
              </motion.div>
            ))}
          </CardContent>
        </Card>
      </motion.div>
    </motion.div>
  );
}
