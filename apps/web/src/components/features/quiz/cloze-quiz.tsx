'use client';

import { useState, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CircleCheck, CircleX } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { cn } from '@/lib/utils';

type ClozeQuizQuestion = {
  questionId: string;
  sentence: string;
  translation: string;
  options: { id: string; text: string }[];
  correctOptionId: string;
  explanation: string;
  grammarPoint?: string | null;
};

type QuizResult = {
  correct: number;
  total: number;
  wrongQuestionIds: string[];
};

type ClozeQuizProps = {
  questions: ClozeQuizQuestion[];
  sessionId: string;
  onAnswer?: (questionId: string, selectedOptionId: string, isCorrect: boolean) => void;
  onComplete: (result: QuizResult) => void;
};

type AnswerState = 'idle' | 'correct' | 'incorrect';

export function ClozeQuiz({
  questions,
  sessionId,
  onAnswer,
  onComplete,
}: ClozeQuizProps) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [selectedOption, setSelectedOption] = useState<string | null>(null);
  const [answerState, setAnswerState] = useState<AnswerState>('idle');
  const [results, setResults] = useState<
    { questionId: string; isCorrect: boolean }[]
  >([]);

  const total = questions.length;
  const question = questions[currentIndex];
  const progress = total > 0 ? ((currentIndex + 1) / total) * 100 : 0;

  const handleSelect = useCallback(
    (optionId: string) => {
      if (answerState !== 'idle' || !question) return;

      setSelectedOption(optionId);

      const isCorrect = optionId === question.correctOptionId;
      setAnswerState(isCorrect ? 'correct' : 'incorrect');
      setResults((prev) => [
        ...prev,
        { questionId: question.questionId, isCorrect },
      ]);

      onAnswer?.(question.questionId, optionId, isCorrect);
    },
    [answerState, question, onAnswer]
  );

  function handleNext() {
    const nextIndex = currentIndex + 1;

    if (nextIndex >= total) {
      const allResults = results;
      const correctCount = allResults.filter((r) => r.isCorrect).length;
      const wrongIds = allResults
        .filter((r) => !r.isCorrect)
        .map((r) => r.questionId);
      onComplete({ correct: correctCount, total, wrongQuestionIds: wrongIds });
      return;
    }

    setCurrentIndex(nextIndex);
    setSelectedOption(null);
    setAnswerState('idle');
  }

  if (!question) return null;

  // Parse sentence to render blank
  const sentenceParts = question.sentence.split('{blank}');
  const selectedText = selectedOption
    ? question.options.find((o) => o.id === selectedOption)?.text
    : null;

  const correctText = question.options.find(
    (o) => o.id === question.correctOptionId
  )?.text;

  return (
    <div className="flex min-h-[calc(100dvh-5rem)] flex-col">
      {/* Header */}
      <div className="flex flex-col gap-2 p-4 pb-2">
        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">빈칸 채우기</span>
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

      {/* Sentence */}
      <div className="flex flex-1 flex-col items-center justify-center gap-3 px-4 py-8">
        <AnimatePresence mode="wait">
          <motion.div
            key={currentIndex}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="flex flex-col items-center gap-4"
          >
            {/* Sentence with blank */}
            <p className="font-jp text-center text-xl font-bold leading-relaxed">
              {sentenceParts[0]}
              {answerState === 'idle' && !selectedText ? (
                <span className="border-primary/40 mx-1 inline-block min-w-[48px] border-b-2 border-dashed">
                  &nbsp;&nbsp;&nbsp;&nbsp;
                </span>
              ) : (
                <motion.span
                  initial={{ scale: 0.8, opacity: 0 }}
                  animate={{
                    scale: 1,
                    opacity: 1,
                    ...(answerState === 'incorrect'
                      ? { x: [0, -8, 8, -6, 6, -3, 3, 0] }
                      : answerState === 'correct'
                        ? { scale: [1, 1.04, 1] }
                        : {}),
                  }}
                  transition={{ duration: 0.3 }}
                  className={cn(
                    'mx-1 inline-block rounded px-2 py-0.5 font-bold',
                    answerState === 'correct'
                      ? 'border-hk-success bg-hk-success/10 text-hk-success border-b-2'
                      : answerState === 'incorrect'
                        ? 'border-hk-error bg-hk-error/10 text-hk-error border-b-2'
                        : 'border-primary bg-primary/10 text-primary border-b-2'
                  )}
                >
                  {selectedText}
                </motion.span>
              )}
              {sentenceParts[1]}
            </p>

            {/* Translation */}
            <p className="text-muted-foreground text-sm">
              {question.translation}
            </p>

            {/* Guide text */}
            {answerState === 'idle' && (
              <p className="text-muted-foreground text-xs">
                빈칸에 들어갈 말을 선택하세요
              </p>
            )}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Options */}
      <div className="px-4 pb-4">
        <AnimatePresence mode="wait">
          <motion.div
            key={currentIndex}
            initial="hidden"
            animate="visible"
            className="flex flex-wrap justify-center gap-2"
          >
            {question.options.map((option, i) => {
              const isSelected = selectedOption === option.id;
              const isCorrectOption = option.id === question.correctOptionId;

              let chipStyle = 'border-border bg-card hover:bg-accent';
              if (answerState !== 'idle') {
                if (isCorrectOption) {
                  chipStyle = 'border-hk-success bg-hk-success/10 text-hk-success';
                } else if (isSelected && !isCorrectOption) {
                  chipStyle = 'border-hk-error bg-hk-error/10 text-hk-error';
                } else {
                  chipStyle = 'border-border bg-card opacity-40';
                }
              }

              return (
                <motion.button
                  key={option.id}
                  className={cn(
                    'font-jp min-w-[56px] rounded-xl border-2 px-5 py-3 text-center text-lg font-medium transition-colors disabled:cursor-default',
                    chipStyle
                  )}
                  onClick={() => handleSelect(option.id)}
                  disabled={answerState !== 'idle'}
                  whileTap={answerState === 'idle' ? { scale: 0.95 } : undefined}
                  variants={{
                    hidden: { opacity: 0, y: 10 },
                    visible: {
                      opacity: 1,
                      y: 0,
                      transition: { delay: i * 0.05, duration: 0.2 },
                    },
                    pulse: {
                      scale: [1, 1.04, 1],
                      transition: { duration: 0.3 },
                    },
                    shake: {
                      x: [0, -8, 8, -6, 6, -3, 3, 0],
                      transition: { duration: 0.4 },
                    },
                  }}
                  initial="hidden"
                  animate={
                    answerState === 'idle'
                      ? 'visible'
                      : isCorrectOption
                        ? 'pulse'
                        : isSelected && !isCorrectOption
                          ? 'shake'
                          : 'visible'
                  }
                >
                  {option.text}
                </motion.button>
              );
            })}
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
              'safe-area-bottom fixed bottom-20 left-0 right-0 z-30 mx-auto max-w-lg rounded-t-2xl border-t p-5',
              answerState === 'correct'
                ? 'bg-background border-hk-success/30'
                : 'bg-background border-hk-error/30'
            )}
          >
            <div className="flex flex-col gap-3">
              {/* Result header */}
              <div className="flex items-center gap-2">
                {answerState === 'correct' ? (
                  <CircleCheck className="text-hk-success size-6" />
                ) : (
                  <CircleX className="text-hk-error size-6" />
                )}
                <span className="text-lg font-bold">
                  {answerState === 'correct' ? '정답이에요!' : '아쉬워요!'}
                </span>
              </div>

              {/* Show correct answer on incorrect */}
              {answerState === 'incorrect' && (
                <p className="text-muted-foreground text-sm">
                  정답: <span className="font-jp font-bold">{correctText}</span>
                </p>
              )}

              {/* Grammar explanation */}
              <div className="bg-secondary rounded-xl p-3">
                {question.grammarPoint && (
                  <p className="mb-1 text-xs font-medium text-primary">
                    {question.grammarPoint}
                  </p>
                )}
                <p className="text-muted-foreground text-sm">
                  {question.explanation}
                </p>
              </div>

              {/* Next button */}
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

export type { ClozeQuizQuestion, ClozeQuizProps };
