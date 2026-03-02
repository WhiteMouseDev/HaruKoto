'use client';

import { Phone, FlaskConical } from 'lucide-react';
import { motion } from 'framer-motion';
import { Card, CardContent } from '@/components/ui/card';

type PhoneCallCtaProps = {
  onClick: () => void;
};

export function PhoneCallCta({ onClick }: PhoneCallCtaProps) {
  return (
    <motion.div whileTap={{ scale: 0.98 }}>
      <Card
        className="cursor-pointer border-violet-500/30 bg-gradient-to-br from-violet-500/15 via-fuchsia-500/10 to-pink-500/10 py-4 transition-shadow hover:shadow-md hover:shadow-violet-500/10"
        onClick={onClick}
      >
        <CardContent className="flex items-center gap-4 p-4">
          <div className="flex size-12 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-violet-500 to-fuchsia-500 text-white shadow-md shadow-violet-500/25">
            <Phone className="size-5" />
          </div>
          <div className="flex-1">
            <h3 className="flex items-center gap-1.5 font-semibold">
              AI 전화 통화
              <span className="inline-flex items-center gap-0.5 rounded-full bg-violet-500/10 px-1.5 py-0.5 text-xs font-medium text-violet-600 dark:text-violet-400">
                <FlaskConical className="size-2.5" />
                Beta
              </span>
            </h3>
            <p className="text-muted-foreground text-sm">
              음성으로 실전 회화 연습!
            </p>
          </div>
          <Phone className="size-5 text-violet-500" />
        </CardContent>
      </Card>
    </motion.div>
  );
}
