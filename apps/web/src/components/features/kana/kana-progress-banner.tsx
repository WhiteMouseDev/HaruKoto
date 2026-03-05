'use client';

import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { BookOpen, ArrowRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';

type KanaProgressInfo = {
  learned: number;
  total: number;
  pct: number;
};

type KanaProgressBannerProps = {
  hiragana: KanaProgressInfo;
  katakana: KanaProgressInfo;
};

export function KanaProgressBanner({
  hiragana,
  katakana,
}: KanaProgressBannerProps) {
  const router = useRouter();

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
    >
      <div className="rounded-3xl border border-primary/30 bg-primary/5 p-5 shadow-sm">
        <div className="mb-4 flex items-center gap-3">
          <div className="bg-primary/20 flex size-10 shrink-0 items-center justify-center rounded-full">
            <BookOpen className="text-primary size-5" />
          </div>
          <div className="flex-1">
            <h3 className="font-bold">히라가나/가타카나 배우기</h3>
            <p className="text-muted-foreground text-xs">
              일본어의 기본 문자를 마스터하세요
            </p>
          </div>
        </div>

        {/* Progress bars */}
        <div className="mb-4 flex flex-col gap-3">
          <div className="flex flex-col gap-1.5">
            <div className="flex items-center justify-between text-sm">
              <span className="text-muted-foreground font-medium">히라가나</span>
              <span className="font-medium">
                {hiragana.learned}/{hiragana.total}{' '}
                <span className="text-muted-foreground text-xs">
                  ({hiragana.pct}%)
                </span>
              </span>
            </div>
            <Progress value={hiragana.pct} />
          </div>

          <div className="flex flex-col gap-1.5">
            <div className="flex items-center justify-between text-sm">
              <span className="text-muted-foreground font-medium">가타카나</span>
              <span className="font-medium">
                {katakana.learned}/{katakana.total}{' '}
                <span className="text-muted-foreground text-xs">
                  ({katakana.pct}%)
                </span>
              </span>
            </div>
            <Progress value={katakana.pct} />
          </div>
        </div>

        {/* CTA button */}
        <Button
          className="h-11 w-full"
          onClick={() => router.push('/study/kana')}
        >
          학습 시작하기
          <ArrowRight className="size-4" />
        </Button>
      </div>
    </motion.div>
  );
}
