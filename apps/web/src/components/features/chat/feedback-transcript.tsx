'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronDown, ChevronUp, MessageSquareText } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';

type GrammarCorrection = {
  original: string;
  corrected: string;
  explanation: string;
};

type TranscriptMessage = {
  role: 'user' | 'assistant';
  text: string;
};

type FeedbackTranscriptProps = {
  transcript: TranscriptMessage[];
  corrections: GrammarCorrection[];
};

const bubbleVariants = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3 } },
};

function findCorrection(text: string, corrections: GrammarCorrection[]) {
  return corrections.find(
    (c) => text.includes(c.original) || c.original.includes(text)
  );
}

function CorrectionToggle({ correction }: { correction: GrammarCorrection }) {
  const [open, setOpen] = useState(false);

  return (
    <div className="mt-1.5">
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-1 text-xs text-amber-200/80 hover:text-amber-200 transition-colors"
      >
        <span className="text-[10px]">📝</span>
        교정 있음
        {open ? (
          <ChevronUp className="size-3" />
        ) : (
          <ChevronDown className="size-3" />
        )}
      </button>
      <AnimatePresence>
        {open && (
          <motion.div
            className="mt-1 space-y-1 rounded-lg bg-black/20 p-2.5 text-xs"
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
          >
            <p className="text-red-300 line-through">{correction.original}</p>
            <p className="text-emerald-300 font-medium">
              {correction.corrected}
            </p>
            <p className="text-white/60 mt-0.5">{correction.explanation}</p>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export function FeedbackTranscript({
  transcript,
  corrections,
}: FeedbackTranscriptProps) {
  if (!transcript || transcript.length === 0) return null;

  return (
    <Card className="py-4">
      <CardContent className="space-y-3 px-5">
        <h3 className="flex items-center gap-2 font-semibold">
          <MessageSquareText className="text-hk-info size-4" />
          대화 내역
        </h3>
        <motion.div
          className="space-y-3"
          initial="hidden"
          animate="show"
          transition={{ staggerChildren: 0.06 }}
        >
          {transcript.map((msg, i) => {
            const isUser = msg.role === 'user';
            const correction = isUser
              ? findCorrection(msg.text, corrections)
              : undefined;

            return (
              <motion.div
                key={i}
                variants={bubbleVariants}
                className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}
              >
                <div className="max-w-[85%]">
                  {!isUser && (
                    <span className="text-muted-foreground mb-1 block text-[11px]">
                      하루
                    </span>
                  )}
                  <div
                    className={`rounded-2xl px-3.5 py-2.5 ${
                      isUser
                        ? 'bg-primary text-primary-foreground rounded-tr-sm'
                        : 'bg-card rounded-tl-sm border shadow-sm'
                    }`}
                  >
                    <p className="font-jp text-sm leading-relaxed">
                      {msg.text}
                    </p>
                    {correction && <CorrectionToggle correction={correction} />}
                  </div>
                </div>
              </motion.div>
            );
          })}
        </motion.div>
      </CardContent>
    </Card>
  );
}
