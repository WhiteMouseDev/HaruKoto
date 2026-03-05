'use client';

import { Phone, FlaskConical } from 'lucide-react';
import { motion } from 'framer-motion';
import { cardHoverVariants } from '@/lib/motion';

type PhoneCallCtaProps = {
  onClick: () => void;
};

export function PhoneCallCta({ onClick }: PhoneCallCtaProps) {
  return (
    <motion.div
      className="rounded-3xl"
      variants={cardHoverVariants}
      initial="rest"
      whileHover="hover"
      whileTap="tap"
    >
      <div
        className="relative cursor-pointer overflow-hidden rounded-3xl border border-[#F0E0F5] bg-gradient-to-br from-[#FDF0F8] to-[#F4E8F9] p-6 shadow-sm dark:border-violet-500/20 dark:from-violet-500/15 dark:via-fuchsia-500/10 dark:to-pink-500/10"
        onClick={onClick}
      >
        <div className="relative z-10 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex size-11 shrink-0 items-center justify-center rounded-full bg-[#A855F7] shadow-sm shadow-purple-200 dark:shadow-violet-500/25">
              <Phone size={20} className="fill-current text-white" />
            </div>
            <div className="flex flex-col">
              <div className="flex items-center gap-2">
                <h2 className="text-lg font-bold">AI 전화 통화</h2>
                <span className="flex items-center gap-0.5 rounded-full bg-[#A855F7]/10 px-2 py-0.5 text-[10px] font-bold tracking-wide text-[#A855F7] dark:text-violet-400">
                  <FlaskConical className="size-2.5" />
                  Beta
                </span>
              </div>
              <p className="text-muted-foreground mt-0.5 text-sm">
                음성으로 실전 회화 연습!
              </p>
            </div>
          </div>
          <button className="rounded-full p-2 text-[#A855F7] transition-colors hover:bg-[#A855F7]/10 dark:text-violet-400">
            <Phone size={20} />
          </button>
        </div>
      </div>
    </motion.div>
  );
}
