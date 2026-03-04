'use client';

import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { ChevronRight, Grid3x3 } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';
import { useKanaProgress } from '@/hooks/use-kana';

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.08 },
  },
};

const item = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35 } },
};

export default function KanaHubPage() {
  const router = useRouter();
  const { data: progress, isLoading } = useKanaProgress();

  if (isLoading) {
    return (
      <div className="flex flex-col gap-5 p-4">
        <div className="bg-secondary h-8 w-48 animate-pulse rounded pt-2" />
        <div className="bg-secondary h-4 w-64 animate-pulse rounded" />
        {/* Kana type cards with progress bar shape */}
        {[1, 2].map((n) => (
          <div
            key={n}
            className="flex flex-col gap-4 rounded-xl border p-5"
          >
            <div className="flex items-center gap-3">
              <div className="bg-secondary size-12 animate-pulse rounded-xl" />
              <div className="flex flex-1 flex-col gap-1.5">
                <div className="bg-secondary h-5 w-36 animate-pulse rounded" />
                <div className="bg-secondary h-4 w-48 animate-pulse rounded" />
              </div>
            </div>
            <div className="flex flex-col gap-1.5">
              <div className="flex justify-between">
                <div className="bg-secondary h-3 w-12 animate-pulse rounded" />
                <div className="bg-secondary h-3 w-8 animate-pulse rounded" />
              </div>
              <div className="bg-secondary h-2 w-full animate-pulse rounded-full" />
            </div>
          </div>
        ))}
        {/* Chart link card */}
        <div className="bg-secondary h-14 animate-pulse rounded-xl" />
      </div>
    );
  }

  const hiragana = progress?.hiragana ?? { learned: 0, total: 0, pct: 0 };
  const katakana = progress?.katakana ?? { learned: 0, total: 0, pct: 0 };

  return (
    <motion.div
      className="flex flex-col gap-5 p-4"
      variants={container}
      initial="hidden"
      animate="show"
    >
      <motion.h1 variants={item} className="pt-2 text-2xl font-bold">
        가나 학습
      </motion.h1>

      <motion.p variants={item} className="text-muted-foreground -mt-2 text-sm">
        일본어의 기본! 히라가나와 가타카나를 배워보세요.
      </motion.p>

      {/* Hiragana Card */}
      <motion.div variants={item}>
        <Card
          className="cursor-pointer transition-shadow hover:shadow-md"
          onClick={() => router.push('/study/kana/hiragana')}
        >
          <CardContent className="flex flex-col gap-4 p-5">
            <div className="flex items-center gap-3">
              <div className="bg-primary/10 flex size-12 items-center justify-center rounded-xl">
                <span className="font-jp text-primary text-xl font-bold">あ</span>
              </div>
              <div className="flex-1">
                <h3 className="text-lg font-semibold">히라가나 배우기</h3>
                <p className="text-muted-foreground text-sm">
                  {hiragana.total > 0 ? `${hiragana.learned}/${hiragana.total}자 학습` : '로딩 중...'}
                </p>
              </div>
              <ChevronRight className="text-muted-foreground size-5" />
            </div>
            <div className="flex flex-col gap-1.5">
              <div className="text-muted-foreground flex justify-between text-xs">
                <span>진행률</span>
                <span>{hiragana.pct}%</span>
              </div>
              <Progress value={hiragana.pct} className="h-2" />
            </div>
          </CardContent>
        </Card>
      </motion.div>

      {/* Katakana Card */}
      <motion.div variants={item}>
        <Card
          className="cursor-pointer transition-shadow hover:shadow-md"
          onClick={() => router.push('/study/kana/katakana')}
        >
          <CardContent className="flex flex-col gap-4 p-5">
            <div className="flex items-center gap-3">
              <div className="bg-primary/10 flex size-12 items-center justify-center rounded-xl">
                <span className="font-jp text-primary text-xl font-bold">ア</span>
              </div>
              <div className="flex-1">
                <h3 className="text-lg font-semibold">가타카나 배우기</h3>
                <p className="text-muted-foreground text-sm">
                  {katakana.total > 0 ? `${katakana.learned}/${katakana.total}자 학습` : '로딩 중...'}
                </p>
              </div>
              <ChevronRight className="text-muted-foreground size-5" />
            </div>
            <div className="flex flex-col gap-1.5">
              <div className="text-muted-foreground flex justify-between text-xs">
                <span>진행률</span>
                <span>{katakana.pct}%</span>
              </div>
              <Progress value={katakana.pct} className="h-2" />
            </div>
          </CardContent>
        </Card>
      </motion.div>

      {/* 50-Sound Chart Link */}
      <motion.div variants={item}>
        <Card
          className="cursor-pointer transition-shadow hover:shadow-md"
          onClick={() => router.push('/study/kana/chart')}
        >
          <CardContent className="flex items-center gap-3 px-5 py-4">
            <Grid3x3 className="text-muted-foreground size-5" />
            <span className="flex-1 font-medium">50음도 차트 보기</span>
            <ChevronRight className="text-muted-foreground size-4" />
          </CardContent>
        </Card>
      </motion.div>
    </motion.div>
  );
}
