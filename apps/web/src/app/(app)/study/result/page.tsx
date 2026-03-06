'use client';

import { Suspense, useState, useEffect } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Trophy,
  Zap,
  Target,
  RotateCcw,
  Home,
  PartyPopper,
  ThumbsUp,
  Dumbbell,
  BookmarkPlus,
  Check,
  ChevronDown,
  RefreshCw,
  BookOpen,
  FileX,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Confetti } from '@/components/ui/confetti';
import { useCountUp } from '@/hooks/use-count-up';
import { useWrongAnswers, useRecommendations } from '@/hooks/use-quiz';
import { useAddWord } from '@/hooks/use-wordbook';
import { playSound } from '@/lib/sounds';

export default function QuizResultPage() {
  return (
    <Suspense>
      <ResultContent />
    </Suspense>
  );
}

function ResultContent() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const [showWrongList, setShowWrongList] = useState(false);
  const [savedWords, setSavedWords] = useState<Set<string>>(new Set());
  const [bulkSaving, setBulkSaving] = useState(false);

  const correct = parseInt(searchParams.get('correct') || '0');
  const total = parseInt(searchParams.get('total') || '0');
  const xp = parseInt(searchParams.get('xp') || '0');
  const accuracy = parseInt(searchParams.get('accuracy') || '0');
  const quizType = searchParams.get('type') || 'VOCABULARY';
  const jlptLevel = searchParams.get('level') || 'N5';
  const isKana = quizType === 'KANA';
  const currentXp = parseInt(searchParams.get('currentXp') || '0');
  const xpForNext = parseInt(searchParams.get('xpForNext') || '100');
  const sessionId = searchParams.get('sessionId');

  useEffect(() => {
    playSound('complete');
  }, []);

  const hasWrongAnswers = total - correct > 0 && !isKana;
  const { data: wrongAnswersData } = useWrongAnswers(
    hasWrongAnswers ? sessionId : null
  );
  const wrongAnswers = wrongAnswersData?.wrongAnswers ?? [];

  const { data: recommendations } = useRecommendations();

  const addWordMutation = useAddWord();

  function saveToWordbook(item: {
    questionId: string;
    word: string;
    reading: string | null;
    meaningKo: string;
  }) {
    if (savedWords.has(item.questionId)) return;
    addWordMutation.mutate(
      {
        word: item.word,
        reading: item.reading || item.word,
        meaningKo: item.meaningKo,
        source: 'QUIZ',
      },
      {
        onSuccess: () => {
          setSavedWords((prev) => new Set(prev).add(item.questionId));
        },
      }
    );
  }

  async function saveAllToWordbook() {
    if (bulkSaving) return;
    setBulkSaving(true);
    const unsaved = wrongAnswers.filter((w) => !savedWords.has(w.questionId));
    for (const item of unsaved) {
      try {
        await addWordMutation.mutateAsync({
          word: item.word,
          reading: item.reading || item.word,
          meaningKo: item.meaningKo,
          source: 'QUIZ',
        });
        setSavedWords((prev) => new Set(prev).add(item.questionId));
      } catch {
        // Continue with remaining items
      }
    }
    setBulkSaving(false);
  }

  const allSaved =
    wrongAnswers.length > 0 &&
    wrongAnswers.every((w) => savedWords.has(w.questionId));

  const ResultIcon =
    accuracy >= 80 ? PartyPopper : accuracy >= 50 ? ThumbsUp : Dumbbell;
  const message =
    accuracy >= 80
      ? '훌륭해요!'
      : accuracy >= 50
        ? '잘 하셨어요!'
        : '다음엔 더 잘할 수 있어요!';

  const animatedAccuracy = useCountUp(accuracy, 0.8, 0.7);
  const animatedCorrect = useCountUp(correct, 0.6, 0.5);
  const animatedXp = useCountUp(xp, 0.6, 0.5);

  const wrongCount = total - correct;

  return (
    <div className="flex min-h-dvh flex-col items-center gap-6 p-6 pb-10">
      {/* Confetti for high accuracy */}
      {accuracy >= 80 && <Confetti duration={2000} />}

      {/* Mascot & Message */}
      <motion.div
        className="flex flex-col items-center gap-2 pt-6"
        initial={{ scale: 0.8, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ duration: 0.5, type: 'spring' }}
      >
        <ResultIcon className="text-primary size-14" />
        <h1 className="text-2xl font-bold">{message}</h1>
      </motion.div>

      {/* Score Card */}
      <motion.div
        className="w-full max-w-sm"
        initial={{ y: 30, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.2 }}
      >
        <Card>
          <CardContent className="flex flex-col items-center gap-5 p-6">
            {/* Accuracy Circle */}
            <div className="relative flex size-28 items-center justify-center">
              <svg
                className="absolute size-full -rotate-90"
                viewBox="0 0 100 100"
              >
                <circle
                  cx="50"
                  cy="50"
                  r="42"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="8"
                  className="text-secondary"
                />
                <motion.circle
                  cx="50"
                  cy="50"
                  r="42"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="8"
                  strokeLinecap="round"
                  className="text-primary"
                  strokeDasharray={`${2 * Math.PI * 42}`}
                  initial={{ strokeDashoffset: 2 * Math.PI * 42 }}
                  animate={{
                    strokeDashoffset:
                      2 * Math.PI * 42 * (1 - accuracy / 100),
                  }}
                  transition={{ duration: 1, delay: 0.5, ease: 'easeOut' }}
                />
              </svg>
              <div className="flex flex-col items-center">
                <span className="text-2xl font-bold">
                  {animatedAccuracy}%
                </span>
                <span className="text-muted-foreground text-xs">정답률</span>
              </div>
            </div>

            {/* Stats */}
            <div className="grid w-full grid-cols-3 gap-3">
              <div className="bg-secondary flex flex-col items-center gap-1 rounded-xl p-3">
                <Target className="text-primary size-4" />
                <span className="text-lg font-bold">
                  {animatedCorrect}/{total}
                </span>
                <span className="text-muted-foreground text-[10px]">
                  정답
                </span>
              </div>
              <div className="bg-secondary flex flex-col items-center gap-1 rounded-xl p-3">
                <Zap className="text-hk-yellow size-4" />
                <span className="text-lg font-bold">+{animatedXp}</span>
                <span className="text-muted-foreground text-[10px]">XP</span>
                <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-black/10 dark:bg-white/10">
                  <motion.div
                    className="bg-hk-yellow h-full rounded-full"
                    initial={{ width: 0 }}
                    animate={{
                      width: `${Math.min(Math.round((currentXp / xpForNext) * 100), 100)}%`,
                    }}
                    transition={{
                      duration: 0.8,
                      delay: 0.7,
                      ease: 'easeOut',
                    }}
                  />
                </div>
                <span className="text-muted-foreground text-[9px]">
                  다음 레벨까지 {xpForNext - currentXp} XP
                </span>
              </div>
              <div className="bg-secondary flex flex-col items-center gap-1 rounded-xl p-3">
                <Trophy className="text-hk-blue size-4" />
                <span className="text-lg font-bold">{wrongCount}</span>
                <span className="text-muted-foreground text-[10px]">
                  오답
                </span>
              </div>
            </div>
          </CardContent>
        </Card>
      </motion.div>

      {/* Wrong Answers Accordion */}
      {wrongAnswers.length > 0 && (
        <motion.div
          className="w-full max-w-sm"
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.35 }}
        >
          <Card>
            <CardContent className="flex flex-col gap-3 p-4">
              <button
                className="flex items-center justify-between"
                onClick={() => setShowWrongList((v) => !v)}
              >
                <div className="flex items-center gap-2">
                  <Trophy className="text-hk-error size-4" />
                  <span className="text-sm font-semibold">
                    틀린{' '}
                    {isKana
                      ? '문자'
                      : quizType === 'VOCABULARY'
                        ? '단어'
                        : '문법'}{' '}
                    {wrongAnswers.length}개
                  </span>
                </div>
                <motion.div
                  animate={{ rotate: showWrongList ? -180 : 0 }}
                  transition={{ duration: 0.2 }}
                >
                  <ChevronDown className="text-muted-foreground size-4" />
                </motion.div>
              </button>

              <AnimatePresence>
                {showWrongList && (
                  <motion.div
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: 'auto', opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    transition={{ duration: 0.2 }}
                    className="overflow-hidden"
                  >
                    <div className="flex flex-col gap-2.5">
                      {wrongAnswers.map((item, i) => (
                        <motion.div
                          key={item.questionId}
                          className="bg-secondary flex flex-col gap-2 rounded-xl p-3"
                          initial={{ opacity: 0, y: 10 }}
                          animate={{ opacity: 1, y: 0 }}
                          transition={{ delay: i * 0.08 }}
                        >
                          {/* Word header */}
                          <div className="flex items-center justify-between">
                            <div className="flex items-center gap-2">
                              <span className="font-jp text-base font-bold">
                                {item.word}
                              </span>
                              {item.reading && (
                                <span className="font-jp text-muted-foreground text-xs">
                                  {item.reading}
                                </span>
                              )}
                            </div>
                            {quizType === 'VOCABULARY' && (
                              <button
                                className={`shrink-0 rounded-md p-1.5 transition-colors ${
                                  savedWords.has(item.questionId)
                                    ? 'text-primary bg-primary/10'
                                    : 'text-muted-foreground hover:bg-secondary-foreground/10'
                                }`}
                                onClick={() => saveToWordbook(item)}
                                disabled={savedWords.has(item.questionId)}
                              >
                                {savedWords.has(item.questionId) ? (
                                  <Check className="size-4" />
                                ) : (
                                  <BookmarkPlus className="size-4" />
                                )}
                              </button>
                            )}
                          </div>

                          {/* Meaning */}
                          <p className="text-muted-foreground text-sm">
                            {item.meaningKo}
                          </p>

                          {/* Example sentence */}
                          {item.exampleSentence && (
                            <div className="rounded-lg bg-card p-2.5">
                              <p className="font-jp text-sm">
                                {item.exampleSentence}
                              </p>
                              {item.exampleTranslation && (
                                <p className="text-muted-foreground mt-1 text-xs">
                                  {item.exampleTranslation}
                                </p>
                              )}
                            </div>
                          )}
                        </motion.div>
                      ))}

                      {quizType === 'VOCABULARY' && (
                        <Button
                          variant="outline"
                          size="sm"
                          className="mt-1 rounded-lg"
                          onClick={saveAllToWordbook}
                          disabled={bulkSaving || allSaved}
                        >
                          {allSaved ? (
                            <>
                              <Check className="mr-1.5 size-3.5" />
                              모두 저장됨
                            </>
                          ) : (
                            <>
                              <BookmarkPlus className="mr-1.5 size-3.5" />
                              {bulkSaving
                                ? '저장 중...'
                                : '모두 단어장에 저장'}
                            </>
                          )}
                        </Button>
                      )}
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </CardContent>
          </Card>
        </motion.div>
      )}

      {/* Recommendation CTA */}
      {!isKana && (
        <motion.div
          className="flex w-full max-w-sm flex-col gap-3"
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.45 }}
        >
          <h3 className="text-sm font-semibold">다음에 이걸 해보세요</h3>

          {/* Review due words */}
          {recommendations && recommendations.reviewDueCount > 0 && (
            <div
              className="border-primary/30 bg-primary/5 cursor-pointer rounded-2xl border p-4 transition-colors hover:bg-primary/10"
              onClick={() =>
                router.replace(
                  `/study/quiz?type=VOCABULARY&level=${jlptLevel}&count=10&mode=review`
                )
              }
            >
              <div className="flex items-center gap-2">
                <RefreshCw className="text-primary size-4" />
                <span className="text-sm font-semibold">
                  잊어버리기 쉬운 단어
                </span>
              </div>
              <p className="text-muted-foreground mt-1 text-xs">
                복습할 단어 {recommendations.reviewDueCount}개
              </p>
              <p className="text-primary mt-2 text-xs font-medium">
                바로 시작 →
              </p>
            </div>
          )}

          {/* Wrong answers review */}
          {wrongCount > 0 && (
            <div
              className="border-hk-error/30 bg-hk-error/5 cursor-pointer rounded-2xl border p-4 transition-colors hover:bg-hk-error/10"
              onClick={() =>
                router.replace(
                  `/study/quiz?type=${quizType}&level=${jlptLevel}&count=10&mode=review`
                )
              }
            >
              <div className="flex items-center gap-2">
                <FileX className="text-hk-error size-4" />
                <span className="text-sm font-semibold">
                  이번에 틀린 단어 복습
                </span>
              </div>
              <p className="text-muted-foreground mt-1 text-xs">
                {wrongCount}개 단어
              </p>
              <p className="text-hk-error mt-2 text-xs font-medium">
                오답 복습 →
              </p>
            </div>
          )}

          {/* New words */}
          {recommendations && recommendations.newWordsCount > 0 && (
            <div
              className="cursor-pointer rounded-2xl border p-4 transition-colors hover:bg-secondary"
              onClick={() =>
                router.replace(
                  `/study/quiz?type=VOCABULARY&level=${jlptLevel}&count=10`
                )
              }
            >
              <div className="flex items-center gap-2">
                <BookOpen className="text-muted-foreground size-4" />
                <span className="text-sm font-semibold">새로운 단어 학습</span>
              </div>
              <p className="text-muted-foreground mt-1 text-xs">
                아직 안 본 단어 {recommendations.newWordsCount}개
              </p>
              <p className="text-primary mt-2 text-xs font-medium">
                학습 시작 →
              </p>
            </div>
          )}
        </motion.div>
      )}

      {/* Actions */}
      <motion.div
        className="flex w-full max-w-sm flex-col gap-2.5"
        initial={{ y: 20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.5 }}
      >
        <Button
          className="h-12 rounded-xl text-base"
          onClick={() =>
            isKana
              ? router.replace('/study/kana')
              : router.replace(
                  `/study/quiz?type=${quizType}&level=${jlptLevel}&count=10`
                )
          }
        >
          <RotateCcw className="mr-2 size-4" />
          {isKana ? '가나 학습으로 돌아가기' : '한 번 더 도전'}
        </Button>
        <Button
          variant="ghost"
          className="h-12 rounded-xl text-base"
          onClick={() => router.replace('/home')}
        >
          <Home className="mr-2 size-4" />
          홈으로 돌아가기
        </Button>
      </motion.div>
    </div>
  );
}
