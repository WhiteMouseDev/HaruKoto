'use client';

import { motion } from 'framer-motion';
import { Clock, FileText } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Heatmap } from './heatmap';
import { BarChart } from './bar-chart';

type TodaySummary = {
  wordsStudied: number;
  quizzesCompleted: number;
  correctAnswers: number;
  totalAnswers: number;
  xpEarned: number;
  goalProgress: number;
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

type PeriodTabProps = {
  today: TodaySummary;
  historyRecords: HistoryRecord[];
  heatmapYear: number;
  onHeatmapYearChange: (year: number) => void;
};

const item = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3 } },
};

export function PeriodTab({
  today,
  historyRecords,
  heatmapYear,
  onHeatmapYearChange,
}: PeriodTabProps) {
  const todayRecord = historyRecords.find((r) => {
    const todayStr = new Date().toISOString().split('T')[0];
    return r.date === todayStr;
  });

  const studyMinutes = todayRecord
    ? Math.round(todayRecord.studyTimeSeconds / 60)
    : 0;

  const totalQuizzes = today.quizzesCompleted;

  const heatmapRecords = historyRecords.map((r) => ({
    date: r.date,
    wordsStudied: r.wordsStudied,
  }));

  const barChartRecords = historyRecords.map((r) => ({
    date: r.date,
    studyTimeSeconds: r.studyTimeSeconds,
    wordsStudied: r.wordsStudied,
  }));

  return (
    <motion.div
      className="flex flex-col gap-4"
      initial="hidden"
      animate="show"
      variants={{ show: { transition: { staggerChildren: 0.08 } } }}
    >
      {/* Today's Summary */}
      <motion.div variants={item}>
        <Card>
          <CardContent className="flex flex-col gap-3 p-4">
            <h3 className="font-semibold">오늘의 학습</h3>
            <div className="grid grid-cols-2 gap-3">
              <div className="bg-secondary flex items-center gap-3 rounded-xl p-3">
                <div className="bg-primary/20 flex size-10 items-center justify-center rounded-full">
                  <Clock className="text-primary size-5" />
                </div>
                <div>
                  <p className="text-muted-foreground text-xs">총 시간</p>
                  <p className="text-xl font-bold">{studyMinutes}분</p>
                </div>
              </div>
              <div className="bg-secondary flex items-center gap-3 rounded-xl p-3">
                <div className="bg-hk-blue/20 flex size-10 items-center justify-center rounded-full">
                  <FileText className="text-hk-blue size-5" />
                </div>
                <div>
                  <p className="text-muted-foreground text-xs">총 문제</p>
                  <p className="text-xl font-bold">{totalQuizzes}개</p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </motion.div>

      {/* Annual Heatmap */}
      <motion.div variants={item}>
        <Heatmap
          records={heatmapRecords}
          year={heatmapYear}
          onYearChange={onHeatmapYearChange}
        />
      </motion.div>

      {/* Study Time Bar Chart */}
      <motion.div variants={item}>
        <BarChart records={barChartRecords} />
      </motion.div>
    </motion.div>
  );
}
