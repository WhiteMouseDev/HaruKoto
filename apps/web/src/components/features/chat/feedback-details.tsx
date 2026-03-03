'use client';

import { motion } from 'framer-motion';
import { CheckCircle2, Lightbulb, BookOpen } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';

type Vocabulary = {
  word: string;
  reading: string;
  meaningKo: string;
};

type RecommendedExpression = {
  ja: string;
  ko: string;
};

type FeedbackDetailsProps = {
  strengths: string[];
  improvements: string[];
  recommendedExpressions: (RecommendedExpression | string)[];
  vocabulary: Vocabulary[];
};

const listItem = {
  hidden: { opacity: 0, x: -10 },
  show: { opacity: 1, x: 0 },
};

export function FeedbackDetails({
  strengths,
  improvements,
  recommendedExpressions,
  vocabulary,
}: FeedbackDetailsProps) {
  return (
    <div className="space-y-4">
      {/* Strengths */}
      {strengths.length > 0 && (
        <Card className="py-4">
          <CardContent className="space-y-2 px-5">
            <h3 className="flex items-center gap-2 font-semibold">
              <CheckCircle2 className="text-hk-success size-4" />
              잘한 표현
            </h3>
            <motion.ul
              className="space-y-1.5"
              initial="hidden"
              animate="show"
              transition={{ staggerChildren: 0.08 }}
            >
              {strengths.map((s, i) => (
                <motion.li
                  key={i}
                  variants={listItem}
                  className="text-sm flex items-start gap-2"
                >
                  <span className="text-hk-success mt-0.5">✅</span>
                  <span>{s}</span>
                </motion.li>
              ))}
            </motion.ul>
          </CardContent>
        </Card>
      )}

      {/* Improvements */}
      {improvements.length > 0 && (
        <Card className="py-4">
          <CardContent className="space-y-2 px-5">
            <h3 className="flex items-center gap-2 font-semibold">
              <Lightbulb className="text-hk-warning size-4" />
              개선 포인트
            </h3>
            <motion.ul
              className="space-y-1.5"
              initial="hidden"
              animate="show"
              transition={{ staggerChildren: 0.08 }}
            >
              {improvements.map((item, i) => (
                <motion.li
                  key={i}
                  variants={listItem}
                  className="text-sm flex items-start gap-2"
                >
                  <span className="text-hk-warning mt-0.5">💡</span>
                  <span>{item}</span>
                </motion.li>
              ))}
            </motion.ul>
          </CardContent>
        </Card>
      )}

      {/* Recommended expressions */}
      {recommendedExpressions.length > 0 && (
        <Card className="py-4">
          <CardContent className="space-y-2 px-5">
            <h3 className="flex items-center gap-2 font-semibold">
              <BookOpen className="text-hk-info size-4" />
              추천 표현
            </h3>
            <ul className="space-y-1.5">
              {recommendedExpressions.map((expr, i) => {
                const isObj = typeof expr === 'object' && expr !== null;
                return (
                  <li
                    key={i}
                    className="bg-secondary/50 rounded-lg px-3 py-2 text-sm"
                  >
                    <span className="font-jp font-medium">
                      {isObj ? expr.ja : expr}
                    </span>
                    {isObj && (
                      <span className="text-muted-foreground ml-2 text-xs">
                        {expr.ko}
                      </span>
                    )}
                  </li>
                );
              })}
            </ul>
          </CardContent>
        </Card>
      )}

      {/* Vocabulary */}
      {vocabulary.length > 0 && (
        <Card className="py-4">
          <CardContent className="space-y-2 px-5">
            <h3 className="flex items-center gap-2 font-semibold">
              📝 새로 배운 표현
            </h3>
            <div className="space-y-2">
              {vocabulary.map((v, i) => (
                <div
                  key={i}
                  className="bg-secondary/50 flex items-center justify-between rounded-lg px-3 py-2"
                >
                  <div>
                    <span className="font-jp font-medium">{v.word}</span>
                    <span className="font-jp text-muted-foreground ml-1.5 text-xs">
                      ({v.reading})
                    </span>
                  </div>
                  <span className="text-muted-foreground text-sm">
                    {v.meaningKo}
                  </span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
