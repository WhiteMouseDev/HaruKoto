'use client';

import { useState, useEffect, useCallback, useRef, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ArrowLeft,
  CircleCheck,
  CircleX,
  Frown,
  Lightbulb,
  PartyPopper,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { showGameEvents } from '@/lib/show-events';
import { Logo } from '@/components/brand/logo';

interface QuizOption {
  id: string;
  text: string;
}

interface QuizQuestion {
  questionId: string;
  questionText: string;
  questionSubText: string | null;
  hint: string | null;
  options: QuizOption[];
  correctOptionId: string;
}

type AnswerState = 'idle' | 'correct' | 'incorrect';

export default function QuizPage() {
  return (
    <Suspense
      fallback={
        <div className="flex min-h-dvh items-center justify-center">
          <div className="flex flex-col items-center gap-3">
            <Logo size="sm" className="animate-pulse" />
            <p className="text-muted-foreground">퀴즈를 준비하고 있어요...</p>
          </div>
        </div>
      }
    >
      <QuizContent />
    </Suspense>
  );
}

function QuizContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const quizType = searchParams.get('type') || 'VOCABULARY';
  const jlptLevel = searchParams.get('level') || 'N5';
  const count = parseInt(searchParams.get('count') || '10');
  const mode = searchParams.get('mode');
  const resumeSessionId = searchParams.get('resume');
  const isReview = mode === 'review';

  const [sessionId, setSessionId] = useState<string | null>(null);
  const [questions, setQuestions] = useState<QuizQuestion[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [selectedOption, setSelectedOption] = useState<string | null>(null);
  const [answerState, setAnswerState] = useState<AnswerState>('idle');
  const [showHint, setShowHint] = useState(false);
  const [loading, setLoading] = useState(true);
  const [, setResults] = useState<boolean[]>([]);
  const timerRef = useRef<number>(0);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Start or resume quiz
  useEffect(() => {
    async function initQuiz() {
      try {
        if (resumeSessionId) {
          // Resume mode
          const res = await fetch('/api/v1/quiz/resume', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ sessionId: resumeSessionId }),
          });
          const data = await res.json();
          if (res.ok && data.questions) {
            setSessionId(data.sessionId);
            setQuestions(data.questions);
            const answeredCount = data.answeredQuestionIds.length;
            setCurrentIndex(answeredCount);
            // Restore results: correctCount trues, rest false
            const restoredResults = Array.from(
              { length: answeredCount },
              (_, i) => i < data.correctCount
            );
            setResults(restoredResults);
          }
        } else {
          // Normal start
          const res = await fetch('/api/v1/quiz/start', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ quizType, jlptLevel, count, mode: mode || undefined }),
          });
          const data = await res.json();
          if (res.ok) {
            setSessionId(data.sessionId);
            setQuestions(data.questions);
          }
        }
      } catch (err) {
        console.error('Failed to init quiz:', err);
      } finally {
        setLoading(false);
      }
    }
    initQuiz();
  }, [quizType, jlptLevel, count, mode, resumeSessionId]);

  // Timer
  useEffect(() => {
    if (!loading && answerState === 'idle') {
      timerRef.current = 0;
      intervalRef.current = setInterval(() => {
        timerRef.current += 1;
      }, 1000);
    }
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [currentIndex, loading, answerState]);

  // Warn before leaving during quiz
  useEffect(() => {
    if (loading || questions.length === 0) return;

    function handleBeforeUnload(e: BeforeUnloadEvent) {
      e.preventDefault();
    }

    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, [loading, questions.length]);

  const handleAnswer = useCallback(
    async (optionId: string) => {
      if (answerState !== 'idle' || !sessionId) return;

      if (intervalRef.current) clearInterval(intervalRef.current);
      setSelectedOption(optionId);

      const question = questions[currentIndex];
      const isCorrect = optionId === question.correctOptionId;
      setAnswerState(isCorrect ? 'correct' : 'incorrect');
      setResults((prev) => [...prev, isCorrect]);

      // Submit answer
      await fetch('/api/v1/quiz/answer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sessionId,
          questionId: question.questionId,
          selectedOptionId: optionId,
          isCorrect,
          timeSpentSeconds: timerRef.current,
          questionType: quizType,
        }),
      });
    },
    [answerState, sessionId, questions, currentIndex, quizType]
  );

  async function handleNext() {
    if (currentIndex + 1 >= questions.length) {
      // Complete quiz
      const res = await fetch('/api/v1/quiz/complete', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ sessionId }),
      });
      const data = await res.json();
      showGameEvents(data.events);
      router.replace(
        `/study/result?correct=${data.correctCount}&total=${data.totalQuestions}&xp=${data.xpEarned}&accuracy=${data.accuracy}&type=${quizType}&level=${jlptLevel}&currentXp=${data.currentXp ?? 0}&xpForNext=${data.xpForNext ?? 100}`
      );
      return;
    }

    setCurrentIndex((prev) => prev + 1);
    setSelectedOption(null);
    setAnswerState('idle');
    setShowHint(false);
  }

  if (loading) {
    return (
      <div className="flex min-h-dvh items-center justify-center">
        <div className="flex flex-col items-center gap-3">
          <Logo size="sm" className="animate-pulse" />
          <p className="text-muted-foreground">퀴즈를 준비하고 있어요...</p>
        </div>
      </div>
    );
  }

  if (questions.length === 0) {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center gap-4 p-4">
        <span className="text-primary">
          {isReview ? (
            <PartyPopper className="size-12" />
          ) : (
            <Frown className="size-12" />
          )}
        </span>
        <p className="text-muted-foreground text-center">
          {isReview
            ? '복습할 문제가 없어요!'
            : '퀴즈 데이터를 불러올 수 없습니다.'}
        </p>
        <Button variant="outline" onClick={() => router.push('/study')}>
          학습으로 돌아가기
        </Button>
      </div>
    );
  }

  const question = questions[currentIndex];
  const progress = ((currentIndex + 1) / questions.length) * 100;

  return (
    <div className="flex min-h-dvh flex-col">
      {/* Header */}
      <div className="flex items-center gap-3 p-4">
        <button
          onClick={() => {
            if (confirm('나가면 진행 상황이 저장돼요. 나가시겠어요?')) {
              router.push('/study');
            }
          }}
        >
          <ArrowLeft className="size-5" />
        </button>
        <span className="flex-1 text-center text-sm font-medium">
          {isReview
            ? '오답 복습'
            : `${jlptLevel} ${quizType === 'VOCABULARY' ? '단어' : '문법'} 퀴즈`}
        </span>
        <span className="text-muted-foreground text-sm">
          {currentIndex + 1}/{questions.length}
        </span>
      </div>

      {/* Progress Bar */}
      <div className="bg-secondary mx-4 h-1.5 overflow-hidden rounded-full">
        <motion.div
          className="bg-primary h-full rounded-full"
          initial={{ width: 0 }}
          animate={{ width: `${progress}%` }}
          transition={{ duration: 0.3 }}
        />
      </div>

      {/* Question */}
      <div className="flex flex-1 flex-col items-center justify-center gap-2 px-4 py-8">
        <AnimatePresence mode="wait">
          <motion.div
            key={currentIndex}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="flex flex-col items-center gap-2"
          >
            <p className="font-jp text-4xl font-bold">
              {question.questionText}
            </p>
            {question.questionSubText && (
              <p className="font-jp text-muted-foreground text-lg">
                {question.questionSubText}
              </p>
            )}
            <p className="text-muted-foreground mt-2 text-sm">
              이 {quizType === 'VOCABULARY' ? '단어' : '문법'}의 뜻은?
            </p>
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Options */}
      <div className="flex flex-col gap-2.5 px-4 pb-4">
        {question.options.map((option, i) => {
          const isSelected = selectedOption === option.id;
          const isCorrectOption = option.id === question.correctOptionId;
          let optionStyle = 'border-border';

          if (answerState !== 'idle') {
            if (isCorrectOption) {
              optionStyle = 'border-hk-success bg-hk-success/10';
            } else if (isSelected && !isCorrectOption) {
              optionStyle = 'border-hk-error bg-hk-error/10';
            } else {
              optionStyle = 'border-border opacity-40';
            }
          } else if (isSelected) {
            optionStyle = 'border-primary bg-primary/5';
          }

          return (
            <motion.button
              key={option.id}
              className={cn(
                'flex items-center gap-3 rounded-xl border-2 px-4 py-3.5 text-left transition-all',
                optionStyle
              )}
              onClick={() => handleAnswer(option.id)}
              disabled={answerState !== 'idle'}
              whileTap={answerState === 'idle' ? { scale: 0.98 } : undefined}
            >
              <span className="bg-secondary flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-bold">
                {i + 1}
              </span>
              <span className="text-sm font-medium">{option.text}</span>
            </motion.button>
          );
        })}
      </div>

      {/* Hint */}
      {answerState === 'idle' && question.hint && (
        <div className="px-4 pb-4">
          <button
            className="text-muted-foreground mx-auto flex items-center gap-1.5 text-sm"
            onClick={() => setShowHint(!showHint)}
          >
            <Lightbulb className="size-4" />
            힌트 보기
          </button>
          <AnimatePresence>
            {showHint && (
              <motion.p
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
                className="font-jp text-muted-foreground mt-2 text-center text-sm"
              >
                {question.hint}
              </motion.p>
            )}
          </AnimatePresence>
        </div>
      )}

      {/* Answer Feedback */}
      <AnimatePresence>
        {answerState !== 'idle' && (
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 25, stiffness: 300 }}
            className={cn(
              'rounded-t-2xl border-t p-5',
              answerState === 'correct'
                ? 'bg-hk-success/5 border-hk-success/30'
                : 'bg-hk-error/5 border-hk-error/30'
            )}
          >
            <div className="flex flex-col gap-3">
              <div className="flex items-center gap-2">
                <span>
                  {answerState === 'correct' ? (
                    <CircleCheck className="text-hk-success size-6" />
                  ) : (
                    <CircleX className="text-hk-error size-6" />
                  )}
                </span>
                <span className="text-lg font-bold">
                  {answerState === 'correct' ? '정답이에요!' : '아쉬워요!'}
                </span>
              </div>

              {answerState === 'incorrect' && (
                <p className="text-muted-foreground text-sm">
                  정답:{' '}
                  {
                    question.options.find(
                      (o) => o.id === question.correctOptionId
                    )?.text
                  }
                </p>
              )}

              {question.hint && (
                <p className="font-jp text-muted-foreground text-sm">
                  {question.hint}
                </p>
              )}

              <Button
                className="h-12 rounded-xl text-base"
                onClick={handleNext}
              >
                {currentIndex + 1 >= questions.length
                  ? '결과 보기'
                  : '다음 문제 →'}
              </Button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
