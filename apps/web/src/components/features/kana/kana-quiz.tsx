'use client';

import { useState, useCallback, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Progress } from '@/components/ui/progress';
import { cn } from '@/lib/utils';
import { useAnswerKanaQuestion } from '@/hooks/use-kana-quiz';
import { Button } from '@/components/ui/button';
import {
  isStudyWriteStopError,
  STUDY_WRITE_STOP_MESSAGE,
} from '@/lib/study-write-stop';

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
  const mounted = useRef(true);
  const advanceTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      if (advanceTimer.current) clearTimeout(advanceTimer.current);
    };
  }, []);
  const [stoppedRetry, setStoppedRetry] = useState<{
    payload: {
      sessionId: string;
      questionId: string;
      selectedOptionId: string;
    };
    advance: () => void;
  } | null>(null);

  const total = questions.length;
  const current = questions[currentIndex];
  const progressPercent =
    total > 0 ? Math.round((currentIndex / total) * 100) : 0;

  const handleSelect = useCallback(
    async (optionId: string) => {
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

      const advance = () => {
        if (!mounted.current) return;
        advanceTimer.current = setTimeout(() => {
          const nextIndex = currentIndex + 1;

          if (nextIndex >= total) {
            const correctCount = updatedAnswers.filter(
              (a) => a.isCorrect
            ).length;
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
      };
      // A STOP response is not an ACK. Keep the same choice/question and retry
      // its frozen payload instead of letting the feedback timer advance it.
      if (sessionId) {
        const payload = {
          sessionId,
          questionId: current.questionId,
          selectedOptionId: optionId,
        };
        try {
          await answerMutation.mutateAsync(payload);
        } catch (error) {
          if (isStudyWriteStopError(error)) {
            setStoppedRetry({ payload, advance });
            return;
          }
        }
      }
      advance();
    },
    [
      showFeedback,
      current,
      answers,
      currentIndex,
      total,
      sessionId,
      onComplete,
      answerMutation,
    ]
  );

  if (!current) return null;

  // Determine if question text is kana (for large display) or romaji
  const isKanaText = /^[\u3040-\u309F\u30A0-\u30FF]$/.test(
    current.questionText
  );

  return (
    <div className="flex flex-col gap-6">
      {stoppedRetry && (
        <div role="alert" className="rounded-xl border p-4">
          <p className="text-sm">{STUDY_WRITE_STOP_MESSAGE}</p>
          <p className="text-muted-foreground mt-1 text-sm">
            선택한 답안은 이 화면에 보관 중이에요. 화면을 새로고침하면 미저장
            선택을 잃을 수 있어요.
          </p>
          <Button
            className="mt-3"
            disabled={answerMutation.isPending}
            onClick={async () => {
              try {
                await answerMutation.mutateAsync(stoppedRetry.payload);
                const { advance } = stoppedRetry;
                setStoppedRetry(null);
                advance();
              } catch {
                /* The same pending choice remains available for retry. */
              }
            }}
          >
            같은 답안 다시 저장
          </Button>
        </div>
      )}
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
              optionStyle =
                'border-hk-success bg-hk-success/10 text-hk-success';
            } else if (isSelected && !isCorrect) {
              optionStyle =
                'border-destructive bg-destructive/10 text-destructive';
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
