'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { toast } from 'sonner';
import Image from 'next/image';
import { Loader2 } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import { showGameEvents } from '@/lib/show-events';
import type { LiveFeedbackResponse } from '@/types/gemini-live';

export default function AnalyzingPage() {
  const router = useRouter();
  const [status, setStatus] = useState('통화 내용을 분석하고 있어요...');
  const calledRef = useRef(false);

  useEffect(() => {
    if (calledRef.current) return;
    calledRef.current = true;

    const raw = sessionStorage.getItem('call_analysis_data');
    sessionStorage.removeItem('call_analysis_data');

    if (!raw) {
      router.replace('/chat');
      return;
    }

    const { transcript, durationSeconds, scenarioId } = JSON.parse(raw);

    async function analyze() {
      try {
        setStatus('AI가 피드백을 생성하고 있어요...');

        const data = await apiFetch<LiveFeedbackResponse>(
          '/api/v1/chat/live-feedback',
          {
            method: 'POST',
            body: JSON.stringify({ transcript, durationSeconds, scenarioId }),
          }
        );

        if (data.feedbackSummary) {
          sessionStorage.setItem(
            `feedback_${data.conversationId}`,
            JSON.stringify({
              feedbackSummary: data.feedbackSummary,
              transcript,
              vocabulary: [],
              scenario: null,
            })
          );
        }
        showGameEvents(data.events);

        router.replace(`/chat/${data.conversationId}/feedback`);
      } catch {
        toast.error('피드백 생성에 실패했습니다.');
        router.replace('/chat');
      }
    }

    analyze();
  }, [router]);

  return (
    <div className="fixed inset-0 z-50 flex flex-col items-center justify-center gap-6 bg-gradient-to-b from-slate-900 to-black">
      <motion.div
        initial={{ scale: 0.8, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ duration: 0.4 }}
        className="flex flex-col items-center gap-6"
      >
        {/* Avatar */}
        <div className="relative">
          <div className="size-28 overflow-hidden rounded-full shadow-lg shadow-emerald-500/25">
            <Image
              src="/images/haru-avatar.png"
              alt="하루"
              width={112}
              height={112}
              className="size-full object-cover"
              priority
            />
          </div>
          <motion.div
            className="absolute -bottom-1 -right-1 flex size-10 items-center justify-center rounded-full bg-slate-800 shadow-lg"
            animate={{ rotate: 360 }}
            transition={{ duration: 1.5, repeat: Infinity, ease: 'linear' }}
          >
            <Loader2 className="size-5 text-emerald-400" />
          </motion.div>
        </div>

        {/* Status text */}
        <motion.p
          key={status}
          className="text-center text-base font-medium text-white/80"
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
        >
          {status}
        </motion.p>

        {/* Progress dots */}
        <div className="flex gap-1.5">
          {[0, 1, 2].map((i) => (
            <motion.div
              key={i}
              className="size-2 rounded-full bg-emerald-400"
              animate={{ opacity: [0.3, 1, 0.3] }}
              transition={{
                duration: 1.2,
                repeat: Infinity,
                delay: i * 0.3,
              }}
            />
          ))}
        </div>
      </motion.div>
    </div>
  );
}
