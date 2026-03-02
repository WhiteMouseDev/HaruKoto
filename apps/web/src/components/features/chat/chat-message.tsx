'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import { ChevronDown, ChevronUp, AlertCircle } from 'lucide-react';

type Feedback = {
  type: string;
  original: string;
  correction: string;
  explanationKo: string;
};

type ChatMessageProps = {
  role: 'ai' | 'user';
  messageJa: string;
  messageKo?: string;
  feedback?: Feedback[];
  showTranslation: boolean;
};

export function ChatMessage({
  role,
  messageJa,
  messageKo,
  feedback,
  showTranslation,
}: ChatMessageProps) {
  const [showFeedback, setShowFeedback] = useState(false);
  const isAI = role === 'ai';
  const hasFeedback = feedback && feedback.length > 0;

  return (
    <motion.div
      className={`flex ${isAI ? 'justify-start' : 'justify-end'}`}
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
    >
      <div className={`max-w-[80%] ${isAI ? '' : ''}`}>
        {isAI && (
          <span className="text-muted-foreground mb-1 block text-xs">
            AI
          </span>
        )}
        <div
          className={`rounded-2xl px-4 py-3 ${
            isAI
              ? 'bg-card rounded-tl-sm border shadow-sm'
              : 'bg-primary text-primary-foreground rounded-tr-sm'
          }`}
        >
          <p className="font-jp text-sm leading-relaxed">{messageJa}</p>
          {showTranslation && messageKo && (
            <p className="text-muted-foreground mt-1.5 border-t border-dashed pt-1.5 text-xs">
              {messageKo}
            </p>
          )}
        </div>

        {/* Inline feedback for user messages */}
        {!isAI && hasFeedback && (
          <div className="mt-1.5">
            <button
              onClick={() => setShowFeedback(!showFeedback)}
              className="text-hk-info flex items-center gap-1 text-xs"
            >
              <AlertCircle className="size-3" />
              교정 {feedback.length}건
              {showFeedback ? (
                <ChevronUp className="size-3" />
              ) : (
                <ChevronDown className="size-3" />
              )}
            </button>
            {showFeedback && (
              <motion.div
                className="bg-hk-info/10 mt-1 space-y-2 rounded-lg p-2.5"
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
              >
                {feedback.map((fb, i) => (
                  <div key={i} className="text-xs">
                    <p className="text-hk-red line-through">{fb.original}</p>
                    <p className="text-hk-success font-medium">
                      → {fb.correction}
                    </p>
                    <p className="text-muted-foreground mt-0.5">
                      {fb.explanationKo}
                    </p>
                  </div>
                ))}
              </motion.div>
            )}
          </div>
        )}
      </div>
    </motion.div>
  );
}
