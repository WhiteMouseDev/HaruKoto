'use client';

import { motion } from 'framer-motion';
import { Star } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';

type FeedbackScoresProps = {
  overallScore: number;
  fluency: number;
  accuracy: number;
  vocabularyDiversity: number;
  naturalness: number;
};

const SCORE_ITEMS = [
  { key: 'fluency' as const, label: '유창성', emoji: '🗣️' },
  { key: 'accuracy' as const, label: '정확성', emoji: '🎯' },
  { key: 'vocabularyDiversity' as const, label: '어휘 다양성', emoji: '📚' },
  { key: 'naturalness' as const, label: '자연스러움', emoji: '🌿' },
];

function getStarRating(score100: number): number {
  return Math.round((score100 / 100) * 5 * 10) / 10;
}

export function FeedbackScores({
  overallScore,
  fluency,
  accuracy,
  vocabularyDiversity,
  naturalness,
}: FeedbackScoresProps) {
  const starRating = getStarRating(overallScore);
  const fullStars = Math.floor(starRating);
  const scores = { fluency, accuracy, vocabularyDiversity, naturalness };

  return (
    <Card className="py-5">
      <CardContent className="space-y-5 px-5">
        {/* Mascot & Overall */}
        <div className="flex flex-col items-center gap-2 text-center">
          <motion.span
            className="text-5xl"
            animate={{ rotate: [0, -5, 5, 0] }}
            transition={{ duration: 2, repeat: Infinity, repeatDelay: 3 }}
          >
            🦊
          </motion.span>
          <p className="text-sm font-medium">
            {starRating >= 4
              ? '일본어 실력이 훌륭해요!'
              : starRating >= 3
                ? '일본어 실력이 늘고 있어요!'
                : '조금 더 연습해봐요!'}
          </p>
        </div>

        {/* Star Rating */}
        <div className="flex flex-col items-center gap-1">
          <div className="flex items-center gap-0.5">
            {Array.from({ length: 5 }, (_, i) => (
              <Star
                key={i}
                className={`size-6 ${
                  i < fullStars
                    ? 'fill-hk-yellow text-hk-yellow'
                    : i < Math.ceil(starRating)
                      ? 'fill-hk-yellow/40 text-hk-yellow'
                      : 'fill-muted text-muted'
                }`}
              />
            ))}
          </div>
          <span className="text-xl font-bold">{starRating.toFixed(1)} / 5</span>
        </div>

        {/* Detail Scores */}
        <div className="space-y-3">
          {SCORE_ITEMS.map(({ key, label, emoji }, index) => (
            <motion.div
              key={key}
              className="space-y-1"
              initial={{ opacity: 0, x: -10 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: index * 0.1 }}
            >
              <div className="flex items-center justify-between text-sm">
                <span>
                  {emoji} {label}
                </span>
                <span className="font-semibold">{scores[key]}%</span>
              </div>
              <Progress value={scores[key]} className="h-2.5" />
            </motion.div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
