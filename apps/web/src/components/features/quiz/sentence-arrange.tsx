'use client';

import { useState, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CircleCheck, CircleX } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { shuffleArray } from '@/lib/shuffle';

type SentenceToken = {
  text: string;
  type: 'noun' | 'particle' | 'verb' | 'adjective' | 'copula' | 'adverb' | 'suffix';
  meaning: string;
  order: number;
};

type SentenceArrangeQuestion = {
  questionId: string;
  koreanSentence: string;
  japaneseSentence: string;
  tokens: SentenceToken[];
  explanation: string;
  grammarPoint?: string | null;
};

type QuizResult = {
  correct: number;
  total: number;
  wrongQuestionIds: string[];
};

type SentenceArrangeQuizProps = {
  questions: SentenceArrangeQuestion[];
  sessionId: string;
  onAnswer?: (questionId: string, isCorrect: boolean) => void;
  onComplete: (result: QuizResult) => void;
};

type AnswerState = 'idle' | 'correct' | 'incorrect';

const TOKEN_COLORS: Record<SentenceToken['type'], string> = {
  noun: 'border-l-blue-500',
  particle: 'border-l-violet-500',
  verb: 'border-l-emerald-500',
  adjective: 'border-l-amber-500',
  adverb: 'border-l-teal-500',
  suffix: 'border-l-gray-400',
  copula: 'border-l-gray-400',
};

export function SentenceArrangeQuiz({
  questions,
  sessionId,
  onAnswer,
  onComplete,
}: SentenceArrangeQuizProps) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [placed, setPlaced] = useState<SentenceToken[]>([]);
  const [available, setAvailable] = useState<SentenceToken[]>(() =>
    shuffleArray([...questions[0].tokens])
  );
  const [answerState, setAnswerState] = useState<AnswerState>('idle');
  const [results, setResults] = useState<
    { questionId: string; isCorrect: boolean }[]
  >([]);

  const total = questions.length;
  const question = questions[currentIndex];
  const progress = total > 0 ? ((currentIndex + 1) / total) * 100 : 0;

  const handlePlaceToken = useCallback(
    (token: SentenceToken) => {
      if (answerState !== 'idle') return;
      setPlaced((prev) => [...prev, token]);
      setAvailable((prev) => prev.filter((t) => t !== token));
    },
    [answerState]
  );

  const handleRemoveToken = useCallback(
    (index: number) => {
      if (answerState !== 'idle') return;
      const token = placed[index];
      setPlaced((prev) => prev.filter((_, i) => i !== index));
      setAvailable((prev) => [...prev, token]);
    },
    [answerState, placed]
  );

  const handleCheck = useCallback(() => {
    if (answerState !== 'idle' || !question) return;
    if (placed.length !== question.tokens.length) return;

    const isCorrect = placed.every((token, i) => token.order === i);
    setAnswerState(isCorrect ? 'correct' : 'incorrect');
    setResults((prev) => [
      ...prev,
      { questionId: question.questionId, isCorrect },
    ]);

    onAnswer?.(question.questionId, isCorrect);
  }, [answerState, question, placed, onAnswer]);

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

    const nextQuestion = questions[nextIndex];
    setCurrentIndex(nextIndex);
    setPlaced([]);
    setAvailable(shuffleArray([...nextQuestion.tokens]));
    setAnswerState('idle');
  }

  if (!question) return null;

  const allPlaced = placed.length === question.tokens.length;
  const correctSentence = question.japaneseSentence;

  return (
    <div className="flex min-h-[calc(100dvh-5rem)] flex-col">
      {/* Header */}
      <div className="flex flex-col gap-2 p-4 pb-2">
        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">어순 배열</span>
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

      {/* Korean Sentence Prompt */}
      <div className="flex flex-col items-center gap-2 px-4 pt-6 pb-4">
        <AnimatePresence mode="wait">
          <motion.div
            key={currentIndex}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="flex flex-col items-center gap-1"
          >
            <p className="text-center text-lg font-bold leading-relaxed">
              &ldquo;{question.koreanSentence}&rdquo;를
            </p>
            <p className="text-muted-foreground text-sm">
              일본어로 만드세요
            </p>
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Answer Zone */}
      <div className="px-4 pb-4">
        <motion.div
          className={cn(
            'min-h-[64px] rounded-2xl border-2 border-dashed p-3 transition-colors',
            answerState === 'correct'
              ? 'border-hk-success bg-hk-success/5'
              : answerState === 'incorrect'
                ? 'border-hk-error bg-hk-error/5'
                : placed.length > 0
                  ? 'border-primary/30 bg-primary/5'
                  : 'border-muted-foreground/20 bg-secondary/30'
          )}
          animate={
            answerState === 'incorrect'
              ? { x: [0, -8, 8, -6, 6, -3, 3, 0] }
              : {}
          }
          transition={{ duration: 0.4 }}
        >
          <div className="flex flex-wrap gap-2">
            {placed.map((token, i) => (
              <motion.button
                key={`placed-${token.order}-${i}`}
                className={cn(
                  'font-jp rounded-xl border-2 border-l-4 px-4 py-3 text-base font-medium transition-colors',
                  answerState === 'correct'
                    ? 'border-hk-success bg-hk-success/10 text-hk-success'
                    : answerState === 'incorrect' && token.order !== i
                      ? 'border-hk-error bg-hk-error/10 text-hk-error'
                      : 'border-primary/50 bg-primary/5',
                  TOKEN_COLORS[token.type]
                )}
                onClick={() => handleRemoveToken(i)}
                disabled={answerState !== 'idle'}
                initial={{ scale: 0.8, opacity: 0 }}
                animate={
                  answerState === 'correct'
                    ? {
                        scale: [1, 1.04, 1],
                        opacity: 1,
                        transition: { delay: i * 0.1, duration: 0.3 },
                      }
                    : { scale: 1, opacity: 1 }
                }
                whileTap={answerState === 'idle' ? { scale: 0.95 } : undefined}
              >
                {token.text}
              </motion.button>
            ))}
            {placed.length === 0 && (
              <span className="text-muted-foreground/50 py-3 text-sm">
                아래 카드를 탭하세요
              </span>
            )}
          </div>

          {/* Correct sentence display after judgment */}
          {answerState !== 'idle' && (
            <motion.p
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.3 }}
              className={cn(
                'font-jp mt-2 text-sm font-medium',
                answerState === 'correct'
                  ? 'text-hk-success'
                  : 'text-muted-foreground'
              )}
            >
              {correctSentence}{' '}
              {answerState === 'correct' ? '✓' : ''}
            </motion.p>
          )}
        </motion.div>
      </div>

      {/* Available Tokens */}
      <div className="flex-1 px-4 pb-4">
        <AnimatePresence mode="wait">
          <motion.div
            key={currentIndex}
            initial="hidden"
            animate="visible"
            className="flex flex-wrap justify-center gap-2"
          >
            {available.map((token, i) => (
              <motion.button
                key={`avail-${token.order}-${i}`}
                className={cn(
                  'font-jp rounded-xl border-2 border-l-4 bg-card px-4 py-3 text-base font-medium shadow-sm transition-colors hover:bg-accent',
                  TOKEN_COLORS[token.type]
                )}
                onClick={() => handlePlaceToken(token)}
                disabled={answerState !== 'idle'}
                whileTap={answerState === 'idle' ? { scale: 0.95 } : undefined}
                variants={{
                  hidden: { opacity: 0, y: 10 },
                  visible: {
                    opacity: 1,
                    y: 0,
                    transition: { delay: i * 0.06, duration: 0.2 },
                  },
                }}
                initial="hidden"
                animate="visible"
                exit={{ opacity: 0, scale: 0.8 }}
              >
                {token.text}
              </motion.button>
            ))}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Check Button */}
      {answerState === 'idle' && (
        <div className="px-4 pb-4">
          <Button
            className="h-12 w-full rounded-xl text-base"
            disabled={!allPlaced}
            onClick={handleCheck}
          >
            확인하기
          </Button>
        </div>
      )}

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
                ? 'bg-hk-success/5 border-hk-success/30'
                : 'bg-hk-error/5 border-hk-error/30'
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
                  정답:{' '}
                  <span className="font-jp font-bold">{correctSentence}</span>
                </p>
              )}

              {/* Grammar explanation */}
              <div className="bg-secondary rounded-xl p-3">
                {question.grammarPoint && (
                  <p className="text-primary mb-1 text-xs font-medium">
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

export type { SentenceArrangeQuestion, SentenceArrangeQuizProps, SentenceToken };
