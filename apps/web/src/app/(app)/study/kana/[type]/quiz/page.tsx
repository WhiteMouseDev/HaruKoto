'use client';

import { Suspense, use, useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { motion } from 'framer-motion';
import { ArrowLeft, Trophy } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { KanaQuiz } from '@/components/features/kana/kana-quiz';
import { apiFetch } from '@/lib/api';

type Props = {
  params: Promise<{ type: string }>;
};

type QuizQuestion = {
  questionId: string;
  questionText: string;
  questionSubText: string | null;
  options: { id: string; text: string }[];
  correctOptionId: string;
};

export default function KanaQuizPage({ params }: Props) {
  return (
    <Suspense>
      <KanaQuizContent params={params} />
    </Suspense>
  );
}

function KanaQuizContent({ params }: Props) {
  const { type } = use(params);
  const router = useRouter();
  const searchParams = useSearchParams();

  const kanaType = type === 'katakana' ? 'KATAKANA' : 'HIRAGANA';
  const label = kanaType === 'HIRAGANA' ? '히라가나' : '가타카나';
  const mode = searchParams.get('mode') || 'recognition';
  const isMaster = searchParams.get('master') === 'true';
  const stageParam = searchParams.get('stage');
  const stageNumber = isMaster ? undefined : stageParam ? parseInt(stageParam) : undefined;

  const [loading, setLoading] = useState(true);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [questions, setQuestions] = useState<QuizQuestion[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [retryKey, setRetryKey] = useState(0);

  useEffect(() => {
    async function startQuiz() {
      setLoading(true);
      setError(null);
      try {
        const res = await apiFetch<{
          sessionId: string | null;
          questions: QuizQuestion[];
          message?: string;
        }>('/api/v1/kana/quiz/start', {
          method: 'POST',
          body: JSON.stringify({
            kanaType,
            stageNumber,
            quizMode: mode,
            count: isMaster ? 46 : 10,
          }),
        });

        if (!res.sessionId || res.questions.length === 0) {
          setError(res.message || '출제할 문제가 없습니다');
        } else {
          setSessionId(res.sessionId);
          setQuestions(res.questions);
        }
      } catch {
        setError('퀴즈를 시작할 수 없습니다');
      } finally {
        setLoading(false);
      }
    }
    startQuiz();
  }, [kanaType, stageNumber, mode, isMaster, retryKey]);

  const [masterResult, setMasterResult] = useState<{
    correct: number;
    total: number;
    accuracy: number;
    xpEarned: number;
    passed: boolean;
  } | null>(null);

  async function handleComplete(result: {
    correct: number;
    total: number;
    wrongQuestionIds: string[];
  }) {
    if (sessionId) {
      try {
        const res = await apiFetch<{
          accuracy: number;
          xpEarned: number;
          currentXp: number;
          xpForNext: number;
        }>('/api/v1/kana/quiz/complete', {
          method: 'POST',
          body: JSON.stringify({ sessionId }),
        });

        if (isMaster) {
          const accuracy = Math.round((result.correct / result.total) * 100);
          setMasterResult({
            correct: result.correct,
            total: result.total,
            accuracy,
            xpEarned: res.xpEarned,
            passed: accuracy >= 90,
          });
          return;
        }

        // Navigate to result page with KANA type
        const params = new URLSearchParams({
          correct: String(result.correct),
          total: String(result.total),
          accuracy: String(res.accuracy),
          xp: String(res.xpEarned),
          type: 'KANA',
          level: 'N5',
          currentXp: String(res.currentXp),
          xpForNext: String(res.xpForNext),
          sessionId,
        });
        router.replace(`/study/result?${params.toString()}`);
      } catch {
        router.replace('/study/kana');
      }
    }
  }

  if (loading) {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center gap-4 p-4">
        <div className="bg-secondary h-8 w-48 animate-pulse rounded" />
        <div className="bg-secondary h-64 w-full max-w-md animate-pulse rounded-xl" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center gap-4 p-4">
        <p className="text-muted-foreground">{error}</p>
        <Button
          variant="outline"
          onClick={() => router.push(`/study/kana/${type}`)}
        >
          돌아가기
        </Button>
      </div>
    );
  }

  // Master quiz result screen
  if (isMaster && masterResult) {
    return (
      <div className="flex min-h-dvh flex-col p-4">
        <div className="flex items-center gap-2 pb-4">
          <Button
            variant="ghost"
            size="icon"
            className="size-8"
            onClick={() => router.push(`/study/kana/${type}`)}
          >
            <ArrowLeft className="size-4" />
          </Button>
          <h1 className="font-semibold">{label} 마스터 퀴즈 결과</h1>
        </div>

        <motion.div
          className="flex flex-1 flex-col items-center justify-center gap-6"
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ type: 'spring' }}
        >
          <Trophy
            className={`size-16 ${masterResult.passed ? 'text-primary' : 'text-muted-foreground'}`}
          />
          <h2 className="text-2xl font-bold">
            {masterResult.passed ? `${label} 마스터!` : '아쉽게 불합격...'}
          </h2>
          <p className="text-muted-foreground text-center">
            {masterResult.passed
              ? `축하해요! ${label} 46자를 완벽하게 마스터했어요!`
              : '90% 이상 정답이면 통과예요. 다시 도전해보세요!'}
          </p>

          <Card className={masterResult.passed ? 'border-primary' : ''}>
            <CardContent className="flex flex-col items-center gap-2 p-5">
              <span className="text-3xl font-bold">{masterResult.accuracy}%</span>
              <p className="text-muted-foreground text-sm">
                {masterResult.correct}/{masterResult.total} 정답 · +{masterResult.xpEarned} XP
              </p>
            </CardContent>
          </Card>

          <div className="flex w-full max-w-xs flex-col gap-2">
            {!masterResult.passed && (
              <Button
                className="h-12 rounded-xl"
                onClick={() => {
                  setMasterResult(null);
                  setSessionId(null);
                  setQuestions([]);
                  setRetryKey((k) => k + 1);
                }}
              >
                다시 도전하기
              </Button>
            )}
            <Button
              variant={masterResult.passed ? 'default' : 'ghost'}
              className="h-12 rounded-xl"
              onClick={() => router.push(`/study/kana/${type}`)}
            >
              돌아가기
            </Button>
          </div>
        </motion.div>
      </div>
    );
  }

  return (
    <div className="flex min-h-dvh flex-col p-4">
      <div className="flex items-center gap-2 pb-4">
        <Button
          variant="ghost"
          size="icon"
          className="size-8"
          onClick={() => router.push(`/study/kana/${type}`)}
        >
          <ArrowLeft className="size-4" />
        </Button>
        <h1 className="font-semibold">
          {isMaster ? `${label} 마스터 퀴즈` : `${label} 퀴즈`}
        </h1>
      </div>

      <motion.div
        className="flex-1"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
      >
        <KanaQuiz questions={questions} sessionId={sessionId} onComplete={handleComplete} />
      </motion.div>
    </div>
  );
}
