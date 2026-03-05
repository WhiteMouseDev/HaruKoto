'use client';

import { use, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { ArrowLeft, ArrowRight, PartyPopper, RotateCcw, Zap } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';
import { useKanaStages, useKanaCharacters, useUpdateKanaProgress, useCompleteKanaStage, type KanaCharacterData } from '@/hooks/use-kana';
import { KanaFlashcard } from '@/components/features/kana/kana-flashcard';
import { KanaPairMatching } from '@/components/features/kana/kana-pair-matching';
import { KanaQuiz } from '@/components/features/kana/kana-quiz';
import { apiFetch } from '@/lib/api';

type Props = {
  params: Promise<{ type: string; number: string }>;
};

type Phase = 'intro' | 'practice' | 'matching' | 'quiz' | 'review' | 'complete';

type QuizQuestion = {
  questionId: string;
  questionText: string;
  questionSubText: string | null;
  options: { id: string; text: string }[];
  correctOptionId: string;
};

export default function KanaStageLearningPage({ params }: Props) {
  const { type, number: stageNum } = use(params);
  const router = useRouter();
  const stageNumber = parseInt(stageNum);
  const kanaType = type === 'katakana' ? 'KATAKANA' : 'HIRAGANA';

  const { data: stagesData } = useKanaStages(kanaType);
  const { data: charsData } = useKanaCharacters(kanaType);
  const updateProgress = useUpdateKanaProgress();
  const completeStage = useCompleteKanaStage();

  const [phase, setPhase] = useState<Phase>('intro');
  const [introIndex, setIntroIndex] = useState(0);
  const [practiceIndex, setPracticeIndex] = useState(0);
  const [quizQuestions, setQuizQuestions] = useState<QuizQuestion[]>([]);
  const [quizSessionId, setQuizSessionId] = useState<string | null>(null);
  const [quizResult, setQuizResult] = useState<{ correct: number; total: number } | null>(null);
  const [xpEarned, setXpEarned] = useState(0);
  const [reviewCharacters, setReviewCharacters] = useState<KanaCharacterData[]>([]);
  const [reviewIndex, setReviewIndex] = useState(0);

  const stage = stagesData?.stages?.find((s) => s.stageNumber === stageNumber);
  const stageCharacters = charsData?.characters?.filter((c) =>
    stage?.characters.includes(c.character)
  ) ?? [];

  // Record progress when intro finishes each character
  const recordIntroProgress = useCallback(
    (kanaId: string) => {
      updateProgress.mutate({ kanaId, learned: true });
    },
    [updateProgress]
  );

  // Start quiz
  async function startQuiz() {
    try {
      const res = await apiFetch<{
        sessionId: string;
        questions: QuizQuestion[];
      }>('/api/v1/kana/quiz/start', {
        method: 'POST',
        body: JSON.stringify({
          kanaType,
          stageNumber,
          quizMode: 'recognition',
          count: 5,
        }),
      });
      setQuizSessionId(res.sessionId);
      setQuizQuestions(res.questions);
      setPhase('quiz');
    } catch {
      // fallback
      setPhase('complete');
    }
  }

  // Handle quiz completion
  async function handleQuizComplete(result: {
    correct: number;
    total: number;
    wrongQuestionIds: string[];
  }) {
    setQuizResult(result);

    if (quizSessionId) {
      try {
        const res = await apiFetch<{ xpEarned: number }>('/api/v1/kana/quiz/complete', {
          method: 'POST',
          body: JSON.stringify({ sessionId: quizSessionId }),
        });
        setXpEarned(res.xpEarned);
      } catch {
        // Ignore
      }
    }

    if (stage) {
      const score = Math.round((result.correct / result.total) * 100);
      completeStage.mutate({ stageId: stage.id, quizScore: score });
    }

    // If there are wrong answers, go to review phase first
    if (result.wrongQuestionIds.length > 0) {
      // The questionId from the quiz corresponds to the kana character ID
      const wrongChars = stageCharacters.filter((c) =>
        result.wrongQuestionIds.includes(c.id)
      );
      if (wrongChars.length > 0) {
        setReviewCharacters(wrongChars);
        setReviewIndex(0);
        setPhase('review');
        return;
      }
    }

    setPhase('complete');
  }

  const isLoading = !stagesData || !charsData;

  if (isLoading) {
    return (
      <div className="flex flex-col gap-4 p-4">
        <div className="bg-secondary h-8 w-48 animate-pulse rounded" />
        <div className="bg-secondary h-64 animate-pulse rounded-xl" />
      </div>
    );
  }

  if (!stage || stageCharacters.length === 0) {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center gap-4 p-4">
        <p className="text-muted-foreground text-center">
          {!stage ? '존재하지 않는 단계입니다.' : '이 단계의 문자를 불러올 수 없습니다.'}
        </p>
        <Button
          variant="outline"
          onClick={() => router.push(`/study/kana/${type}`)}
        >
          돌아가기
        </Button>
      </div>
    );
  }

  const currentIntroChar = stageCharacters[introIndex];
  const currentPracticeChar = stageCharacters[practiceIndex];

  return (
    <div className="flex min-h-dvh flex-col p-4">
      {/* Header */}
      <div className="flex items-center gap-2 pb-4">
        <Button
          variant="ghost"
          size="icon"
          className="size-8"
          onClick={() => router.push(`/study/kana/${type}`)}
        >
          <ArrowLeft className="size-4" />
        </Button>
        <div className="flex-1">
          <h1 className="font-semibold">
            Stage {stageNumber}: {stage.title}
          </h1>
          <p className="text-muted-foreground text-xs">{stage.description}</p>
        </div>
      </div>

      {/* Phase: Intro */}
      <AnimatePresence mode="wait">
        {phase === 'intro' && currentIntroChar && (
          <motion.div
            key={`intro-${introIndex}`}
            className="flex flex-1 flex-col items-center gap-5 pt-2"
            initial={{ opacity: 0, x: 50 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -50 }}
          >
            <div className="flex w-full items-center gap-3">
              <Progress
                value={((introIndex + 1) / stageCharacters.length) * 100}
                className="h-2 flex-1"
              />
              <span className="text-muted-foreground shrink-0 text-xs font-medium">
                {introIndex + 1}/{stageCharacters.length}
              </span>
            </div>

            <div className="flex flex-1 flex-col items-center justify-center gap-6">
              <div className="flex size-36 items-center justify-center rounded-3xl border bg-gradient-to-br from-background to-primary/5 shadow-lg">
                <span className="font-jp text-primary text-8xl font-bold drop-shadow-sm">
                  {currentIntroChar.character}
                </span>
              </div>

              <div className="flex flex-col items-center gap-1">
                <span className="text-primary text-3xl font-extrabold">{currentIntroChar.romaji}</span>
                <span className="text-muted-foreground text-lg">
                  {currentIntroChar.pronunciation}
                </span>
              </div>

              {currentIntroChar.exampleWord && (
                <div className="bg-secondary/80 flex flex-col items-center gap-0.5 rounded-xl px-5 py-3">
                  <span className="font-jp text-lg font-semibold">
                    {currentIntroChar.exampleWord}
                  </span>
                  <span className="text-muted-foreground text-sm">
                    {currentIntroChar.exampleReading} · {currentIntroChar.exampleMeaning}
                  </span>
                </div>
              )}
            </div>

            <Button
              className="h-12 w-full max-w-[280px] rounded-xl text-base font-semibold"
              onClick={() => {
                recordIntroProgress(currentIntroChar.id);
                if (introIndex < stageCharacters.length - 1) {
                  setIntroIndex((i) => i + 1);
                } else {
                  setPracticeIndex(0);
                  setPhase('practice');
                }
              }}
            >
              {introIndex < stageCharacters.length - 1 ? (
                <>
                  다음 <ArrowRight className="ml-1 size-4" />
                </>
              ) : (
                '연습하기'
              )}
            </Button>
          </motion.div>
        )}

        {/* Phase: Practice (Flashcards) */}
        {phase === 'practice' && currentPracticeChar && (
          <motion.div
            key={`practice-${practiceIndex}`}
            className="flex flex-1 flex-col items-center gap-5 pt-2"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <div className="flex w-full items-center gap-3">
              <Progress
                value={((practiceIndex + 1) / stageCharacters.length) * 100}
                className="h-2 flex-1"
              />
              <span className="text-muted-foreground shrink-0 text-xs font-medium">
                {practiceIndex + 1}/{stageCharacters.length}
              </span>
            </div>

            <div className="flex flex-1 items-center">
              <KanaFlashcard
              character={currentPracticeChar.character}
              romaji={currentPracticeChar.romaji}
              pronunciation={currentPracticeChar.pronunciation}
              exampleWord={currentPracticeChar.exampleWord}
              exampleReading={currentPracticeChar.exampleReading}
              exampleMeaning={currentPracticeChar.exampleMeaning}
              onKnow={() => {
                updateProgress.mutate({
                  kanaId: currentPracticeChar.id,
                  learned: true,
                });
                if (practiceIndex < stageCharacters.length - 1) {
                  setPracticeIndex((i) => i + 1);
                } else {
                  setPhase('matching');
                }
              }}
              onDontKnow={() => {
                updateProgress.mutate({
                  kanaId: currentPracticeChar.id,
                  learned: false,
                });
                if (practiceIndex < stageCharacters.length - 1) {
                  setPracticeIndex((i) => i + 1);
                } else {
                  setPhase('matching');
                }
              }}
            />
            </div>
          </motion.div>
        )}

        {/* Phase: Pair Matching */}
        {phase === 'matching' && stageCharacters.length > 0 && (
          <motion.div
            key="matching"
            className="flex flex-1 flex-col"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <KanaPairMatching
              pairs={stageCharacters.map((c) => ({
                id: c.id,
                character: c.character,
                romaji: c.romaji,
              }))}
              onComplete={() => startQuiz()}
            />
          </motion.div>
        )}

        {/* Phase: Quiz */}
        {phase === 'quiz' && quizQuestions.length > 0 && (
          <motion.div
            key="quiz"
            className="flex flex-1 flex-col"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <KanaQuiz
              questions={quizQuestions}
              sessionId={quizSessionId}
              onComplete={handleQuizComplete}
            />
          </motion.div>
        )}

        {/* Phase: Review (wrong answers) */}
        {phase === 'review' && reviewCharacters.length > 0 && (
          <motion.div
            key={`review-${reviewIndex}`}
            className="flex flex-1 flex-col items-center gap-5 pt-2"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <div className="flex w-full items-center gap-3">
              <div className="flex items-center gap-1.5">
                <RotateCcw className="text-muted-foreground size-3.5" />
                <span className="text-muted-foreground text-xs font-medium">복습</span>
              </div>
              <Progress
                value={((reviewIndex + 1) / reviewCharacters.length) * 100}
                className="h-2 flex-1"
              />
              <span className="text-muted-foreground shrink-0 text-xs font-medium">
                {reviewIndex + 1}/{reviewCharacters.length}
              </span>
            </div>

            <div className="flex flex-1 items-center">
              <KanaFlashcard
              character={reviewCharacters[reviewIndex].character}
              romaji={reviewCharacters[reviewIndex].romaji}
              pronunciation={reviewCharacters[reviewIndex].pronunciation}
              exampleWord={reviewCharacters[reviewIndex].exampleWord}
              exampleReading={reviewCharacters[reviewIndex].exampleReading}
              exampleMeaning={reviewCharacters[reviewIndex].exampleMeaning}
              onKnow={() => {
                if (reviewIndex < reviewCharacters.length - 1) {
                  setReviewIndex((i) => i + 1);
                } else {
                  setPhase('complete');
                }
              }}
              onDontKnow={() => {
                if (reviewIndex < reviewCharacters.length - 1) {
                  setReviewIndex((i) => i + 1);
                } else {
                  setPhase('complete');
                }
              }}
            />
            </div>
          </motion.div>
        )}

        {/* Phase: Complete */}
        {phase === 'complete' && (
          <motion.div
            key="complete"
            className="flex flex-1 flex-col items-center justify-center gap-6"
            initial={{ scale: 0.8, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ type: 'spring' }}
          >
            <PartyPopper className="text-primary size-16" />
            <h2 className="text-2xl font-bold">단계 완료!</h2>
            <p className="text-muted-foreground text-center">
              {stage.title}을(를) 학습했어요!
            </p>

            {quizResult && (
              <Card>
                <CardContent className="flex flex-col items-center gap-2 p-5">
                  <div className="flex items-center gap-2">
                    <Zap className="text-hk-yellow size-5" />
                    <span className="text-lg font-bold">+{xpEarned} XP</span>
                  </div>
                  <p className="text-muted-foreground text-sm">
                    퀴즈 결과: {quizResult.correct}/{quizResult.total} 정답
                  </p>
                </CardContent>
              </Card>
            )}

            <div className="flex w-full max-w-xs flex-col gap-2">
              <Button
                className="h-12 rounded-xl"
                onClick={() => router.push(`/study/kana/${type}`)}
              >
                다음 단계로
              </Button>
              <Button
                variant="ghost"
                className="h-12 rounded-xl"
                onClick={() => router.push('/study/kana')}
              >
                가나 학습 홈으로
              </Button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
