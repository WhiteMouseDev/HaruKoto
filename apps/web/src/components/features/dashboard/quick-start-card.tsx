'use client';

import Link from 'next/link';
import { motion } from 'framer-motion';
import { Logo } from '@/components/brand/logo';
import { cardHoverVariants } from '@/lib/motion';

export function QuickStartCard() {
  return (
    <Link href="/study">
      <motion.div
        className="rounded-3xl"
        variants={cardHoverVariants}
        initial="rest"
        whileHover="hover"
        whileTap="tap"
      >
        <div className="flex items-center gap-4 rounded-3xl border border-primary/30 bg-gradient-to-r from-primary/10 to-accent p-6 shadow-sm">
          <div className="bg-primary flex size-12 shrink-0 items-center justify-center rounded-full">
            <Logo variant="symbol" size={28} className="brightness-0 invert" />
          </div>
          <div className="flex-1">
            <h3 className="font-bold">학습 시작하기</h3>
            <p className="text-muted-foreground text-sm">
              오늘의 단어와 문법을 학습해보세요!
            </p>
          </div>
        </div>
      </motion.div>
    </Link>
  );
}
