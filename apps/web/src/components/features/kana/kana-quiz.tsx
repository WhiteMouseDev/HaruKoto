'use client';

import { useState, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Progress } from '@/components/ui/progress';
import { cn } from '@/lib/utils';
import { useAnswerKanaQuestion } from '@/hooks/use-kana-quiz';

type QuizQuestion = {
  questionId: string;
  questionText: string;
  questionSubText: string | null;
  options: { id: string; text: string }[];
  correctOptionId: string;
};

type QuizResult = {
  correct: number;
  total: number;
  wrongQuestionIds: string[];
};

type KanaQuizProps = {
  questions: QuizQuestion[];
  sessionId?: string | null;
  onComplete: (result: QuizResult) => void;
};

export function KanaQuiz({ questions, sessionId, onComplete }: KanaQuizProps) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [selectedOption, setSelectedOption] = useState<string | null>(null);
  const [showFeedback, setShowFeedback] = useState(false);
  const [answers, setAnswers] = useState<
    { questionId: string; selectedOptionId: string; isCorrect: boolean }[]
  >([]);
  const answerMutation = useAnswerKanaQuestion();

  const total = questions.length;
  const current = questions[currentIndex];
  const progressPercent =
    total > 0 ? Math.round((currentIndex / total) * 100) : 0;

  const handleSelect = useCallback(
    (optionId: string) => {
      if (showFeedback || !current) return;

      setSelectedOption(optionId);
      setShowFeedback(true);

      const isCorrect = optionId === current.correctOptionId;
      const newAnswer = {
        questionId: current.questionId,
        selectedOptionId: optionId,
        isCorrect,
      };

      const updatedAnswers = [...answers, newAnswer];
      setAnswers(updatedAnswers);

      // Report answer to server for per-question progress tracking
      if (sessionId) {
        answerMutation.mutate({
          sessionId,
          questionId: current.questionId,
          selectedOptionId: optionId,
        });
      }

      setTimeout(() => {
        const nextIndex = currentIndex + 1;

        if (nextIndex >= total) {
          const correctCount = updatedAnswers.filter((a) => a.isCorrect).length;
          const wrongIds = updatedAnswers
            .filter((a) => !a.isCorrect)
            .map((a) => a.questionId);
          onComplete({
            correct: correctCount,
            total,
            wrongQuestionIds: wrongIds,
          });
        } else {
          setCurrentIndex(nextIndex);
          setSelectedOption(null);
          setShowFeedback(false);
        }
      }, 1000);
    },
    [showFeedback, current, answers, currentIndex, total, sessionId, onComplete, answerMutation]
  );

  if (!current) return null;

  // Determine if question text is kana (for large display) or romaji
  const isKanaText = /^[\u3040-\u309F\u30A0-\u30FF]$/.test(current.questionText);

  return (
    <div className="flex flex-col gap-6">
      {/* Progress */}
      <div className="flex flex-col gap-2">
        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">문제 풀기</span>
          <span className="font-medium">
            {currentIndex + 1}/{total}
          </span>
        </div>
        <Progress value={progressPercent} />
      </div>

      {/* Question */}
      <AnimatePresence mode="wait">
        <motion.div
          key={current.questionId}
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: -20 }}
          transition={{ duration: 0.2 }}
          className="flex flex-col items-center gap-3 py-6"
        >
          <span
            className={cn(
              'font-bold',
              isKanaText ? 'font-jp text-5xl' : 'text-3xl'
            )}
          >
            {current.questionText}
          </span>
          {current.questionSubText && (
            <span className="text-muted-foreground text-lg">
              {current.questionSubText}
            </span>
          )}
        </motion.div>
      </AnimatePresence>

      {/* Options 2x2 grid */}
      <div className="grid grid-cols-2 gap-3" aria-live="assertive">
        {current.options.map((option) => {
          const isSelected = selectedOption === option.id;
          const isCorrect = option.id === current.correctOptionId;

          let optionStyle = 'border bg-card hover:bg-accent';

          if (showFeedback) {
            if (isCorrect) {
              optionStyle = 'border-hk-success bg-hk-success/10 text-hk-success';
            } else if (isSelected && !isCorrect) {
              optionStyle = 'border-destructive bg-destructive/10 text-destructive';
            } else {
              optionStyle = 'border bg-card opacity-50';
            }
          }

          return (
            <motion.button
              key={option.id}
              aria-label={`선택지: ${option.text}`}
              whileTap={showFeedback ? undefined : { scale: 0.96 }}
              onClick={() => handleSelect(option.id)}
              disabled={showFeedback}
              className={cn(
                'flex min-h-[56px] items-center justify-center rounded-xl px-4 py-3 text-center font-medium transition-colors disabled:cursor-default',
                optionStyle
              )}
            >
              {option.text}
            </motion.button>
          );
        })}
      </div>
    </div>
  );
}
