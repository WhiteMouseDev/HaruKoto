'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { Crown, PartyPopper } from 'lucide-react';
import { Button } from '@/components/ui/button';

export default function SubscriptionSuccessPage() {
  const router = useRouter();
  const [showConfetti, setShowConfetti] = useState(false);

  useEffect(() => {
    setShowConfetti(true);
    const timer = setTimeout(() => setShowConfetti(false), 4000);
    return () => clearTimeout(timer);
  }, []);

  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center gap-6 p-4 text-center">
      {/* Confetti effect */}
      {showConfetti && (
        <div className="pointer-events-none fixed inset-0 z-50 overflow-hidden">
          {Array.from({ length: 30 }).map((_, i) => (
            <motion.div
              key={i}
              className="absolute"
              initial={{
                top: -20,
                left: `${Math.random() * 100}%`,
                opacity: 1,
                scale: 1,
              }}
              animate={{
                top: '110%',
                rotate: Math.random() * 720 - 360,
                opacity: 0,
              }}
              transition={{
                duration: 2 + Math.random() * 2,
                delay: Math.random() * 1,
                ease: 'easeOut',
              }}
              style={{
                width: 8 + Math.random() * 8,
                height: 8 + Math.random() * 8,
                borderRadius: Math.random() > 0.5 ? '50%' : '2px',
                backgroundColor: ['#FF6B6B', '#4ECDC4', '#FFE66D', '#A78BFA', '#F472B6', '#34D399'][
                  Math.floor(Math.random() * 6)
                ],
              }}
            />
          ))}
        </div>
      )}

      <motion.div
        initial={{ scale: 0 }}
        animate={{ scale: 1 }}
        transition={{ type: 'spring', stiffness: 200, delay: 0.2 }}
        className="bg-primary/10 flex size-24 items-center justify-center rounded-full"
      >
        <Crown className="text-primary size-12" />
      </motion.div>

      <motion.div
        initial={{ y: 20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.4 }}
        className="flex flex-col gap-2"
      >
        <div className="flex items-center justify-center gap-2">
          <PartyPopper className="text-hk-yellow size-6" />
          <h1 className="text-2xl font-bold">프리미엄 활성화!</h1>
          <PartyPopper className="text-hk-yellow size-6" />
        </div>
        <p className="text-muted-foreground">
          이제 모든 프리미엄 기능을 자유롭게 이용할 수 있습니다.
        </p>
      </motion.div>

      <motion.div
        initial={{ y: 20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.6 }}
        className="flex w-full max-w-xs flex-col gap-3"
      >
        <Button size="lg" className="w-full" onClick={() => router.push('/')}>
          학습 시작하기
        </Button>
        <Button
          variant="outline"
          size="lg"
          className="w-full"
          onClick={() => router.push('/my')}
        >
          내 구독 확인
        </Button>
      </motion.div>
    </div>
  );
}
