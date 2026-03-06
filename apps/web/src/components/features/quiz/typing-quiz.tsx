'use client';

import { useState, useCallback, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CircleCheck, CircleX, Delete } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { shuffleArray } from '@/lib/shuffle';
import { playSound } from '@/lib/sounds';

type TypingQuestion = {
  questionId: string;
  prompt: string;
  answer: string;
  hint?: string | null;
  distractors: string[];
};

type QuizResult = {
  correct: number;
  total: number;
  wrongQuestionIds: string[];
};

type TypingQuizProps = {
  questions: TypingQuestion[];
  sessionId: string;
  onAnswer?: (questionId: string, isCorrect: boolean) => void;
  onComplete: (result: QuizResult) => void;
};

type AnswerState = 'idle' | 'correct' | 'incorrect';

export function TypingQuiz({
  questions,
  onAnswer,
  onComplete,
}: TypingQuizProps) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [placed, setPlaced] = useState<string[]>([]);
  const [bank, setBank] = useState<{ char: string; used: boolean }[]>(() => {
    const q = questions[0];
    const answerChars = [...q.answer];
    const allChars = shuffleArray([...answerChars, ...q.distractors]);
    return allChars.map((c) => ({ char: c, used: false }));
  });
  const [answerState, setAnswerState] = useState<AnswerState>('idle');
  const [results, setResults] = useState<
    { questionId: string; isCorrect: boolean }[]
  >([]);

  const total = questions.length;
  const question = questions[currentIndex];
  const progress = total > 0 ? ((currentIndex + 1) / total) * 100 : 0;
  const answerChars = [...question.answer];
  const slotCount = answerChars.length;

  const handleTapBank = useCallback(
    (index: number) => {
      if (answerState !== 'idle') return;
      if (bank[index].used) return;
      if (placed.length >= slotCount) return;

      setPlaced((prev) => [...prev, bank[index].char]);
      setBank((prev) =>
        prev.map((b, i) => (i === index ? { ...b, used: true } : b))
      );
    },
    [answerState, bank, placed.length, slotCount]
  );

  const handleBackspace = useCallback(() => {
    if (answerState !== 'idle') return;
    if (placed.length === 0) return;

    const lastChar = placed[placed.length - 1];
    setPlaced((prev) => prev.slice(0, -1));

    // Find the first used bank item matching this char and unmark it
    setBank((prev) => {
      const idx = prev.findIndex((b) => b.used && b.char === lastChar);
      if (idx === -1) return prev;
      return prev.map((b, i) => (i === idx ? { ...b, used: false } : b));
    });
  }, [answerState, placed]);

  // Auto-check when all slots filled
  const checkAnswer = useCallback(() => {
    if (answerState !== 'idle' || !question) return;
    if (placed.length !== slotCount) return;

    const isCorrect = placed.join('') === question.answer;
    playSound(isCorrect ? 'correct' : 'incorrect');
    setAnswerState(isCorrect ? 'correct' : 'incorrect');
    setResults((prev) => [
      ...prev,
      { questionId: question.questionId, isCorrect },
    ]);
    onAnswer?.(question.questionId, isCorrect);
  }, [answerState, question, placed, slotCount, onAnswer]);

  // Trigger check when slots are filled
  useEffect(() => {
    if (placed.length === slotCount && answerState === 'idle') {
      const timer = setTimeout(checkAnswer, 300);
      return () => clearTimeout(timer);
    }
  }, [placed.length, slotCount, answerState, checkAnswer]);

  function handleNext() {
    const nextIndex = currentIndex + 1;

    if (nextIndex >= total) {
      const correctCount = results.filter((r) => r.isCorrect).length;
      const wrongIds = results
        .filter((r) => !r.isCorrect)
        .map((r) => r.questionId);
      onComplete({ correct: correctCount, total, wrongQuestionIds: wrongIds });
      return;
    }

    const nextQ = questions[nextIndex];
    const nextAnswerChars = [...nextQ.answer];
    const allChars = shuffleArray([...nextAnswerChars, ...nextQ.distractors]);

    setCurrentIndex(nextIndex);
    setPlaced([]);
    setBank(allChars.map((c) => ({ char: c, used: false })));
    setAnswerState('idle');
  }

  if (!question) return null;

  return (
    <div className="flex min-h-[calc(100dvh-5rem)] flex-col">
      {/* Header */}
      <div className="flex flex-col gap-2 p-4 pb-2">
        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">단어 쓰기</span>
          <span className="font-medium">
            {currentIndex + 1}/{total}
          </span>
        </div>
        <div className="bg-secondary h-1.5 overflow-hidden rounded-full">
          <motion.div
            className="bg-primary h-full rounded-full"
            initial={{ width: 0 }}
            animate={{ width: `${progress}%` }}
            transition={{ duration: 0.3 }}
          />
        </div>
      </div>

      {/* Prompt */}
      <div className="flex flex-col items-center gap-2 px-4 pt-8 pb-4">
        <AnimatePresence mode="wait">
          <motion.div
            key={currentIndex}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="flex flex-col items-center gap-1"
          >
            <p className="text-center text-lg font-bold">
              &ldquo;{question.prompt}&rdquo;를 쓰세요
            </p>
            {question.hint && answerState === 'idle' && (
              <p className="text-muted-foreground text-sm">{question.hint}</p>
            )}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Input Slots */}
      <div className="flex flex-col items-center gap-3 px-4 pb-6">
        <motion.div
          className="flex items-center gap-2"
          animate={
            answerState === 'incorrect'
              ? { x: [0, -8, 8, -6, 6, -3, 3, 0] }
              : {}
          }
          transition={{ duration: 0.4 }}
        >
          {Array.from({ length: slotCount }).map((_, i) => {
            const char = placed[i];
            const isWrong =
              answerState === 'incorrect' && char && char !== answerChars[i];

            return (
              <div
                key={i}
                className={cn(
                  'font-jp flex size-12 items-center justify-center rounded-lg border-2 text-2xl font-bold transition-colors',
                  answerState === 'correct'
                    ? 'border-hk-success bg-hk-success/10 text-hk-success'
                    : isWrong
                      ? 'border-hk-error bg-hk-error/10 text-hk-error'
                      : char
                        ? 'border-primary bg-primary/10 text-primary'
                        : 'border-muted-foreground/30 border-dashed'
                )}
              >
                <AnimatePresence mode="wait">
                  {char && (
                    <motion.span
                      key={char + i}
                      initial={{ scale: 0, opacity: 0 }}
                      animate={
                        answerState === 'correct'
                          ? {
                              scale: [0, 1, 1.04, 1],
                              opacity: 1,
                              transition: {
                                delay: i * 0.1,
                                duration: 0.3,
                              },
                            }
                          : { scale: 1, opacity: 1 }
                      }
                      exit={{ scale: 0, opacity: 0 }}
                      transition={{ duration: 0.15 }}
                    >
                      {char}
                    </motion.span>
                  )}
                </AnimatePresence>
              </div>
            );
          })}

          {/* Backspace */}
          {answerState === 'idle' && placed.length > 0 && (
            <motion.button
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="text-muted-foreground ml-1 p-1"
              onClick={handleBackspace}
              whileTap={{ scale: 0.9 }}
            >
              <Delete className="size-5" />
            </motion.button>
          )}
        </motion.div>

        {/* Correct answer display after judgment */}
        {answerState !== 'idle' && (
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.3 }}
            className={cn(
              'font-jp text-sm font-medium',
              answerState === 'correct'
                ? 'text-hk-success'
                : 'text-muted-foreground'
            )}
          >
            {question.answer}{' '}
            {answerState === 'correct' ? '✓' : ''}
          </motion.p>
        )}
      </div>

      {/* Character Bank */}
      <div className="flex-1 px-4 pb-4">
        <AnimatePresence mode="wait">
          <motion.div
            key={currentIndex}
            initial="hidden"
            animate="visible"
            className="flex flex-wrap justify-center gap-2"
          >
            {bank.map((item, i) => (
              <motion.button
                key={`bank-${i}`}
                className={cn(
                  'font-jp flex size-11 items-center justify-center rounded-lg border-2 bg-card text-xl font-medium shadow-sm transition-colors',
                  item.used
                    ? 'pointer-events-none opacity-30'
                    : 'hover:bg-accent'
                )}
                onClick={() => handleTapBank(i)}
                disabled={answerState !== 'idle' || item.used}
                whileTap={
                  answerState === 'idle' && !item.used
                    ? { scale: 0.9 }
                    : undefined
                }
                variants={{
                  hidden: { opacity: 0, y: 10 },
                  visible: {
                    opacity: item.used ? 0.3 : 1,
                    y: 0,
                    transition: { delay: i * 0.04, duration: 0.2 },
                  },
                }}
                initial="hidden"
                animate="visible"
              >
                {item.char}
              </motion.button>
            ))}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Feedback Panel */}
      <AnimatePresence>
        {answerState !== 'idle' && (
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 25, stiffness: 300 }}
            className={cn(
              'fixed bottom-20 left-0 right-0 z-30 mx-auto max-w-lg rounded-t-2xl border-t p-5',
              answerState === 'correct'
                ? 'bg-background border-hk-success/30'
                : 'bg-background border-hk-error/30'
            )}
          >
            <div className="flex flex-col gap-3">
              <div className="flex items-center gap-2" role="alert">
                {answerState === 'correct' ? (
                  <CircleCheck className="text-hk-success size-6" />
                ) : (
                  <CircleX className="text-hk-error size-6" />
                )}
                <span className="text-lg font-bold">
                  {answerState === 'correct' ? '정답이에요!' : '아쉬워요!'}
                </span>
              </div>

              {answerState === 'incorrect' && (
                <p className="text-muted-foreground text-sm">
                  정답:{' '}
                  <span className="font-jp font-bold">{question.answer}</span>
                  {' '}({question.prompt})
                </p>
              )}

              <Button className="h-12 rounded-xl text-base" onClick={handleNext}>
                {currentIndex + 1 >= total ? '결과 보기' : '다음 문제 →'}
              </Button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export type { TypingQuestion, TypingQuizProps };
