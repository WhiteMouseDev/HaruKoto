'use client';

import { useState, useEffect, useCallback, useRef, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ArrowLeft,
  BookmarkPlus,
  Check,
  CircleCheck,
  CircleX,
  Flame,
  Frown,
  Lightbulb,
  PartyPopper,
  Volume2,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { cn } from '@/lib/utils';
import { showGameEvents } from '@/lib/show-events';
import { playSound } from '@/lib/sounds';
import { Logo } from '@/components/brand/logo';
import {
  useStartQuiz,
  useResumeQuiz,
  useAnswerQuestion,
  useCompleteQuiz,
  type QuizQuestion,
} from '@/hooks/use-quiz';
import { useAddWord } from '@/hooks/use-wordbook';
import { MatchingPairQuiz, type MatchingPair } from '@/components/features/quiz/matching-pair';
import { ClozeQuiz, type ClozeQuizQuestion } from '@/components/features/quiz/cloze-quiz';
import { SentenceArrangeQuiz, type SentenceArrangeQuestion as SentenceArrangeQ } from '@/components/features/quiz/sentence-arrange';
import { TypingQuiz, type TypingQuestion } from '@/components/features/quiz/typing-quiz';

function speakJapanese(text: string) {
  if (typeof window === 'undefined' || !window.speechSynthesis) return;
  window.speechSynthesis.cancel();
  const cleaned = text.replace(/\{blank\}/g, '');
  const utterance = new SpeechSynthesisUtterance(cleaned);
  utterance.lang = 'ja-JP';
  utterance.rate = 0.8;
  window.speechSynthesis.speak(utterance);
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
  const [resolvedMode, setResolvedMode] = useState<string | null>(mode);
  const isReview = resolvedMode === 'review';
  const isMatching = resolvedMode === 'matching';
  const isCloze = resolvedMode === 'cloze';
  const isArrange = resolvedMode === 'arrange';
  const isTyping = resolvedMode === 'typing';

  const [sessionId, setSessionId] = useState<string | null>(null);
  const [questions, setQuestions] = useState<QuizQuestion[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [selectedOption, setSelectedOption] = useState<string | null>(null);
  const [answerState, setAnswerState] = useState<AnswerState>('idle');
  const [showHint, setShowHint] = useState(false);
  const [loading, setLoading] = useState(true);
  const [, setResults] = useState<boolean[]>([]);
  const [wordSaved, setWordSaved] = useState(false);
  const [streak, setStreak] = useState(0);
  const timerRef = useRef<number>(0);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const startQuizMutation = useStartQuiz();
  const resumeQuizMutation = useResumeQuiz();
  const answerMutation = useAnswerQuestion();
  const completeQuizMutation = useCompleteQuiz();
  const addWordMutation = useAddWord();

  // Start or resume quiz
  useEffect(() => {
    async function initQuiz() {
      try {
        if (resumeSessionId) {
          const data = await resumeQuizMutation.mutateAsync({
            sessionId: resumeSessionId,
          });
          if (data.questions) {
            setSessionId(data.sessionId);
            setQuestions(data.questions);
            const answeredCount = data.answeredQuestionIds.length;
            setCurrentIndex(answeredCount);
            const restoredResults = Array.from(
              { length: answeredCount },
              (_, i) => i < data.correctCount
            );
            setResults(restoredResults);

            // Resolve mode from session quizType
            if (data.quizType) {
              const modeMap: Record<string, string> = {
                CLOZE: 'cloze',
                SENTENCE_ARRANGE: 'arrange',
              };
              if (modeMap[data.quizType]) {
                setResolvedMode(modeMap[data.quizType]);
              }
            }
          }
        } else {
          const data = await startQuizMutation.mutateAsync({
            quizType,
            jlptLevel,
            count,
            mode: mode || undefined,
          });
          setSessionId(data.sessionId);
          setQuestions(data.questions);
        }
      } catch (err) {
        console.error('Failed to init quiz:', err);
      } finally {
        setLoading(false);
      }
    }
    initQuiz();
  // eslint-disable-next-line react-hooks/exhaustive-deps
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
      setStreak((prev) => (isCorrect ? prev + 1 : 0));
      setResults((prev) => [...prev, isCorrect]);
      playSound(isCorrect ? 'correct' : 'incorrect');

      // Submit answer
      answerMutation.mutate({
        sessionId,
        questionId: question.questionId,
        selectedOptionId: optionId,
        isCorrect,
        timeSpentSeconds: timerRef.current,
        questionType: quizType,
      });
    },
    [answerState, sessionId, questions, currentIndex, quizType, answerMutation]
  );

  async function handleNext() {
    if (currentIndex + 1 >= questions.length) {
      // Complete quiz
      const data = await completeQuizMutation.mutateAsync({
        sessionId: sessionId!,
      });
      showGameEvents(data.events);
      router.replace(
        `/study/result?correct=${data.correctCount}&total=${data.totalQuestions}&xp=${data.xpEarned}&accuracy=${data.accuracy}&type=${quizType}&level=${jlptLevel}&currentXp=${data.currentXp ?? 0}&xpForNext=${data.xpForNext ?? 100}&sessionId=${sessionId}`
      );
      return;
    }

    setCurrentIndex((prev) => prev + 1);
    setSelectedOption(null);
    setAnswerState('idle');
    setShowHint(false);
    setWordSaved(false);
  }

  function handleSaveToWordbook() {
    if (addWordMutation.isPending || wordSaved) return;
    const q = questions[currentIndex];
    const correctOption = q.options.find((o) => o.id === q.correctOptionId);
    if (!correctOption) return;

    addWordMutation.mutate(
      {
        word: q.questionText,
        reading: q.questionSubText || q.questionText,
        meaningKo: correctOption.text,
        source: 'QUIZ',
      },
      {
        onSuccess: () => setWordSaved(true),
      }
    );
  }

  // Matching quiz state & handlers
  const [matchingRound, setMatchingRound] = useState(0);
  const PAIRS_PER_ROUND = 5;

  const matchingPairs: MatchingPair[] = isMatching
    ? questions.map((q) => {
        const correctOption = q.options.find((o) => o.id === q.correctOptionId);
        return {
          id: q.questionId,
          left: q.questionText,
          right: correctOption?.text || '',
        };
      })
    : [];

  const matchingRounds: MatchingPair[][] = [];
  for (let i = 0; i < matchingPairs.length; i += PAIRS_PER_ROUND) {
    matchingRounds.push(matchingPairs.slice(i, i + PAIRS_PER_ROUND));
  }
  const currentMatchingRound = matchingRounds[matchingRound] || [];

  const [matchingResults, setMatchingResults] = useState<{
    correct: number;
    total: number;
    wrongPairIds: string[];
  }>({ correct: 0, total: 0, wrongPairIds: [] });

  function handleMatchResult(pairId: string, isCorrect: boolean) {
    if (!sessionId) return;
    const question = questions.find((q) => q.questionId === pairId);
    if (question) {
      answerMutation.mutate({
        sessionId,
        questionId: pairId,
        selectedOptionId: isCorrect ? question.correctOptionId : 'wrong',
        isCorrect,
        timeSpentSeconds: 0,
        questionType: quizType,
      });
    }
  }

  async function handleMatchingComplete(result: {
    correct: number;
    total: number;
    wrongPairIds: string[];
  }) {
    const accumulated = {
      correct: matchingResults.correct + result.correct,
      total: matchingResults.total + result.total,
      wrongPairIds: [...matchingResults.wrongPairIds, ...result.wrongPairIds],
    };

    if (matchingRound + 1 < matchingRounds.length) {
      setMatchingResults(accumulated);
      setMatchingRound((r) => r + 1);
    } else {
      // All rounds done — complete quiz
      const data = await completeQuizMutation.mutateAsync({
        sessionId: sessionId!,
      });
      showGameEvents(data.events);
      router.replace(
        `/study/result?correct=${data.correctCount}&total=${data.totalQuestions}&xp=${data.xpEarned}&accuracy=${data.accuracy}&type=${quizType}&level=${jlptLevel}&currentXp=${data.currentXp ?? 0}&xpForNext=${data.xpForNext ?? 100}&sessionId=${sessionId}`
      );
    }
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
      <div className="flex min-h-[calc(100dvh-5rem)] flex-col items-center justify-center gap-4 p-4">
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
            : '이 레벨의 콘텐츠를 준비하고 있어요'}
        </p>
        <Button variant="outline" onClick={() => router.push('/study')}>
          학습으로 돌아가기
        </Button>
      </div>
    );
  }

  // Matching mode rendering
  if (isMatching) {
    const matchingProgress =
      matchingRounds.length > 0
        ? Math.round((matchingRound / matchingRounds.length) * 100)
        : 0;

    return (
      <div className="flex min-h-[calc(100dvh-5rem)] flex-col">
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
            {jlptLevel} {quizType === 'VOCABULARY' ? '단어' : '문법'} 매칭
          </span>
          <span className="text-muted-foreground text-sm">
            {matchingRound + 1}/{matchingRounds.length}
          </span>
        </div>

        {/* Progress */}
        {matchingRounds.length > 1 && (
          <div className="px-4 pb-2">
            <Progress value={matchingProgress} />
          </div>
        )}

        {/* Matching Quiz */}
        <div className="flex-1 px-4 py-6">
          <MatchingPairQuiz
            key={matchingRound}
            pairs={currentMatchingRound}
            onComplete={handleMatchingComplete}
            onMatchResult={handleMatchResult}
          />
        </div>
      </div>
    );
  }

  // Cloze mode rendering
  if (isCloze) {
    const clozeQuestions: ClozeQuizQuestion[] = questions.map((q) => ({
      questionId: q.questionId,
      sentence: q.sentence || q.questionText,
      translation: q.translation || '',
      options: q.options,
      correctOptionId: q.correctOptionId,
      explanation: q.explanation || '',
      grammarPoint: q.grammarPoint || null,
    }));

    async function handleClozeComplete() {
      const data = await completeQuizMutation.mutateAsync({
        sessionId: sessionId!,
      });
      showGameEvents(data.events);
      router.replace(
        `/study/result?correct=${data.correctCount}&total=${data.totalQuestions}&xp=${data.xpEarned}&accuracy=${data.accuracy}&type=CLOZE&level=${jlptLevel}&currentXp=${data.currentXp ?? 0}&xpForNext=${data.xpForNext ?? 100}&sessionId=${sessionId}`
      );
    }

    function handleClozeAnswer(
      questionId: string,
      selectedOptionId: string,
      isCorrect: boolean
    ) {
      if (!sessionId) return;
      answerMutation.mutate({
        sessionId,
        questionId,
        selectedOptionId,
        isCorrect,
        timeSpentSeconds: 0,
        questionType: 'CLOZE',
      });
    }

    return (
      <ClozeQuiz
        questions={clozeQuestions}
        sessionId={sessionId!}
        onAnswer={handleClozeAnswer}
        onComplete={handleClozeComplete}
      />
    );
  }

  // Sentence arrange mode rendering
  if (isArrange) {
    const arrangeQuestions: SentenceArrangeQ[] = questions.map((q) => ({
      questionId: q.questionId,
      koreanSentence: q.koreanSentence || q.questionText,
      japaneseSentence: q.japaneseSentence || '',
      tokens: q.tokens || [],
      explanation: q.explanation || '',
      grammarPoint: q.grammarPoint || null,
    }));

    async function handleArrangeComplete() {
      const data = await completeQuizMutation.mutateAsync({
        sessionId: sessionId!,
      });
      showGameEvents(data.events);
      router.replace(
        `/study/result?correct=${data.correctCount}&total=${data.totalQuestions}&xp=${data.xpEarned}&accuracy=${data.accuracy}&type=SENTENCE_ARRANGE&level=${jlptLevel}&currentXp=${data.currentXp ?? 0}&xpForNext=${data.xpForNext ?? 100}&sessionId=${sessionId}`
      );
    }

    function handleArrangeAnswer(questionId: string, isCorrect: boolean) {
      if (!sessionId) return;
      answerMutation.mutate({
        sessionId,
        questionId,
        selectedOptionId: isCorrect ? questionId : 'wrong',
        isCorrect,
        timeSpentSeconds: 0,
        questionType: 'SENTENCE_ARRANGE',
      });
    }

    return (
      <SentenceArrangeQuiz
        questions={arrangeQuestions}
        sessionId={sessionId!}
        onAnswer={handleArrangeAnswer}
        onComplete={handleArrangeComplete}
      />
    );
  }

  // Typing mode rendering
  if (isTyping) {
    const typingQuestions: TypingQuestion[] = questions.map((q) => ({
      questionId: q.questionId,
      prompt: q.prompt || q.questionText,
      answer: q.answer || '',
      hint: q.hint || null,
      distractors: q.distractors || [],
    }));

    async function handleTypingComplete() {
      const data = await completeQuizMutation.mutateAsync({
        sessionId: sessionId!,
      });
      showGameEvents(data.events);
      router.replace(
        `/study/result?correct=${data.correctCount}&total=${data.totalQuestions}&xp=${data.xpEarned}&accuracy=${data.accuracy}&type=VOCABULARY&level=${jlptLevel}&currentXp=${data.currentXp ?? 0}&xpForNext=${data.xpForNext ?? 100}&sessionId=${sessionId}`
      );
    }

    function handleTypingAnswer(questionId: string, isCorrect: boolean) {
      if (!sessionId) return;
      answerMutation.mutate({
        sessionId,
        questionId,
        selectedOptionId: isCorrect ? questionId : 'wrong',
        isCorrect,
        timeSpentSeconds: 0,
        questionType: 'VOCABULARY',
      });
    }

    return (
      <TypingQuiz
        questions={typingQuestions}
        sessionId={sessionId!}
        onAnswer={handleTypingAnswer}
        onComplete={handleTypingComplete}
      />
    );
  }

  const question = questions[currentIndex];
  const progress = ((currentIndex + 1) / questions.length) * 100;

  return (
    <div className="flex min-h-[calc(100dvh-5rem)] flex-col">
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

      {/* Progress Bar + Streak Counter */}
      <div className="relative mx-4">
        <div className="bg-secondary h-1.5 overflow-hidden rounded-full">
          <motion.div
            className="bg-primary h-full rounded-full"
            initial={{ width: 0 }}
            animate={{ width: `${progress}%` }}
            transition={{ duration: 0.3 }}
          />
        </div>
        <AnimatePresence>
          {streak >= 3 && answerState !== 'idle' && (
            <motion.div
              initial={{ opacity: 0, y: -4 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -4 }}
              transition={{ type: 'spring', damping: 15, stiffness: 300 }}
              className="mt-1.5 flex items-center justify-center gap-1"
            >
              <Flame className="size-3.5 text-orange-500" />
              <span className="text-xs font-bold text-orange-500">
                {streak}연속 정답!
              </span>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Question */}
      <div className="flex flex-1 flex-col items-center justify-center gap-2 px-4 py-4">
        <AnimatePresence mode="wait">
          <motion.div
            key={currentIndex}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="flex flex-col items-center gap-2"
          >
            <p className="font-jp text-4xl font-bold">
              {question.questionText.includes('{blank}')
                ? question.questionText.split('{blank}').map((part, i, arr) => (
                    <span key={i}>
                      {part}
                      {i < arr.length - 1 && (
                        <span className="border-primary/40 mx-1 inline-block min-w-[48px] border-b-2 border-dashed align-baseline">
                          &nbsp;&nbsp;&nbsp;&nbsp;
                        </span>
                      )}
                    </span>
                  ))
                : question.questionText}
            </p>
            {question.questionSubText && (
              <p className="font-jp text-muted-foreground text-lg">
                {question.questionSubText}
              </p>
            )}
            <button
              type="button"
              onClick={() => speakJapanese(question.questionText)}
              className="text-muted-foreground hover:text-primary mt-1 transition-colors"
              aria-label="발음 듣기"
            >
              <Volume2 className="size-5" />
            </button>
            <p className="text-muted-foreground mt-1 text-sm">
              이 {quizType === 'VOCABULARY' ? '단어' : '문법'}의 뜻은?
            </p>
          </motion.div>
        </AnimatePresence>

      </div>

      {/* Options */}
      <div className="flex flex-col gap-2.5 px-4 pb-4">
        <AnimatePresence mode="wait">
          <motion.div
            key={currentIndex}
            initial="hidden"
            animate="visible"
            className="flex flex-col gap-2.5"
          >
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

              const getAnimateVariant = () => {
                if (answerState === 'idle') return 'visible';
                if (isCorrectOption) return 'pulse';
                if (isSelected && !isCorrectOption) return 'shake';
                return 'visible';
              };

              return (
                <motion.button
                  key={option.id}
                  className={cn(
                    'flex items-center gap-3 rounded-xl border-2 px-4 py-3.5 text-left transition-colors',
                    optionStyle
                  )}
                  onClick={() => handleAnswer(option.id)}
                  disabled={answerState !== 'idle'}
                  whileTap={answerState === 'idle' ? { scale: 0.98 } : undefined}
                  variants={{
                    hidden: { opacity: 0, y: 12 },
                    visible: {
                      opacity: 1,
                      y: 0,
                      x: 0,
                      scale: 1,
                      transition: { delay: i * 0.06, duration: 0.25 },
                    },
                    pulse: {
                      opacity: 1,
                      y: 0,
                      scale: [1, 1.04, 1],
                      transition: { duration: 0.3 },
                    },
                    shake: {
                      opacity: 1,
                      y: 0,
                      x: [0, -8, 8, -6, 6, -3, 3, 0],
                      transition: { duration: 0.4 },
                    },
                  }}
                  initial="hidden"
                  animate={getAnimateVariant()}
                >
                  <span className="bg-secondary flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-bold">
                    {i + 1}
                  </span>
                  <span className="text-sm font-medium">{option.text}</span>
                </motion.button>
              );
            })}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Hint — invisible (not removed) when answered to prevent layout shift */}
      {question.hint && (
        <div className={cn('px-4 pb-4', answerState !== 'idle' && 'invisible')}>
          <button
            className="text-muted-foreground mx-auto flex items-center gap-1.5 text-sm"
            onClick={() => setShowHint(!showHint)}
            disabled={answerState !== 'idle'}
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
              'fixed bottom-0 left-0 right-0 z-30 mx-auto max-w-lg rounded-t-2xl border-t p-5 pb-24',
              answerState === 'correct'
                ? 'bg-emerald-50 border-emerald-200 dark:bg-emerald-950 dark:border-emerald-800'
                : 'bg-rose-100 border-rose-300 dark:bg-rose-950 dark:border-rose-800'
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
                  {answerState === 'correct'
                    ? streak >= 5
                      ? '대단해요!'
                      : streak >= 3
                        ? '연속 정답!'
                        : '정답이에요!'
                    : '아쉬워요!'}
                </span>
                {answerState === 'correct' && streak >= 3 && (
                  <span className="ml-auto flex items-center gap-1 text-sm font-bold text-orange-500">
                    <Flame className="size-4" />
                    {streak}
                  </span>
                )}
              </div>

              {answerState === 'incorrect' && (
                <div className="flex items-center justify-between">
                  <p className="text-muted-foreground text-sm">
                    정답:{' '}
                    {
                      question.options.find(
                        (o) => o.id === question.correctOptionId
                      )?.text
                    }
                  </p>
                  {quizType === 'VOCABULARY' && (
                    <button
                      className={cn(
                        'flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-semibold transition-colors',
                        wordSaved
                          ? 'border-emerald-300 bg-emerald-100 text-emerald-700 dark:border-emerald-700 dark:bg-emerald-950 dark:text-emerald-400'
                          : 'border-amber-300 bg-amber-50 text-amber-700 hover:bg-amber-100 dark:border-amber-600 dark:bg-amber-950 dark:text-amber-400'
                      )}
                      onClick={handleSaveToWordbook}
                      disabled={addWordMutation.isPending || wordSaved}
                    >
                      {wordSaved ? (
                        <>
                          <Check className="size-3.5" />
                          저장됨
                        </>
                      ) : (
                        <>
                          <BookmarkPlus className="size-3.5" />
                          단어장에 추가
                        </>
                      )}
                    </button>
                  )}
                </div>
              )}

              {answerState === 'incorrect' && question.hint && (
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
