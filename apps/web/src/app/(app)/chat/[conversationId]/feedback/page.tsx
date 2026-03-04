'use client';

import { useState, useEffect, useRef, use } from 'react';
import { useRouter } from 'next/navigation';
import { useQueryClient } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import { ArrowLeft, RotateCcw, Shuffle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { FeedbackScores } from '@/components/features/chat/feedback-scores';
import { FeedbackDetails } from '@/components/features/chat/feedback-details';
import { FeedbackTranscript } from '@/components/features/chat/feedback-transcript';
import { ExpressionFlashcards } from '@/components/features/chat/expression-flashcards';
import { queryKeys } from '@/lib/query-keys';

type GrammarCorrection = {
  original: string;
  corrected: string;
  explanation: string;
};

type RecommendedExpression = {
  ja: string;
  ko: string;
};

type TranslatedMessage = {
  role: 'user' | 'assistant';
  ja: string;
  ko: string;
};

type TranscriptMessage = {
  role: 'user' | 'assistant';
  text: string;
};

type FeedbackSummary = {
  overallScore: number;
  fluency: number;
  accuracy: number;
  vocabularyDiversity: number;
  naturalness: number;
  strengths: string[];
  improvements: string[];
  recommendedExpressions: RecommendedExpression[] | string[];
  corrections?: GrammarCorrection[];
  translatedTranscript?: TranslatedMessage[];
};

type Vocabulary = {
  word: string;
  reading: string;
  meaningKo: string;
};

type ScenarioInfo = {
  title: string;
  titleJa: string;
  difficulty: string;
  situation: string;
  yourRole: string;
  aiRole: string;
};

type StoredFeedback = {
  feedbackSummary: FeedbackSummary | null;
  transcript?: TranscriptMessage[];
  vocabulary: Vocabulary[];
  scenario: ScenarioInfo | null;
};

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.1 },
  },
};

const item = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: { duration: 0.4 } },
};

export default function FeedbackPage({
  params,
}: {
  params: Promise<{ conversationId: string }>;
}) {
  const { conversationId } = use(params);
  const router = useRouter();
  const queryClient = useQueryClient();
  const hasInvalidated = useRef(false);

  useEffect(() => {
    if (hasInvalidated.current) return;
    hasInvalidated.current = true;

    queryClient.invalidateQueries({ queryKey: queryKeys.dashboard });
    queryClient.invalidateQueries({ queryKey: queryKeys.notifications });
    queryClient.invalidateQueries({ queryKey: queryKeys.chatHistory });
    queryClient.invalidateQueries({ queryKey: queryKeys.profile });
  }, [queryClient]);

  const [feedback, setFeedback] = useState<StoredFeedback | null>(() => {
    if (typeof window === 'undefined') return null;
    const stored = sessionStorage.getItem(`feedback_${conversationId}`);
    if (stored) {
      try {
        const parsed = JSON.parse(stored);
        sessionStorage.removeItem(`feedback_${conversationId}`);
        return parsed;
      } catch {
        return null;
      }
    }
    return null;
  });

  useEffect(() => {
    // Skip server fetch if sessionStorage had data (already set via initializer)
    if (feedback) return;

    let cancelled = false;

    async function fetchFeedbackFromServer() {
      try {
        const res = await fetch(`/api/v1/chat/${conversationId}`);
        if (!res.ok || cancelled) return;
        const data = await res.json();
        if (data.feedbackSummary && !cancelled) {
          const transcript: TranscriptMessage[] =
            data.messages?.map(
              (m: { role: string; messageJa?: string; content?: string }) => ({
                role: m.role === 'ai' ? 'assistant' : m.role,
                text: m.messageJa ?? m.content ?? '',
              })
            ) ?? [];
          setFeedback({
            feedbackSummary: data.feedbackSummary,
            transcript,
            vocabulary: [],
            scenario: data.scenario,
          });
        }
      } catch {
        // Failed to load — stay on "no data" state
      }
    }

    fetchFeedbackFromServer();
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [conversationId]);

  // Loading / no data state
  if (!feedback || !feedback.feedbackSummary) {
    return (
      <div className="flex flex-col gap-4 p-4">
        <div className="flex items-center gap-3 pt-2">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => router.push('/chat')}
          >
            <ArrowLeft className="size-5" />
          </Button>
          <h1 className="text-xl font-bold">회화 리포트</h1>
        </div>
        <div className="flex flex-col items-center gap-3 py-12">
          <span className="text-4xl">🦊</span>
          <p className="text-muted-foreground text-sm">
            피드백 데이터를 불러올 수 없습니다.
          </p>
          <Button variant="outline" onClick={() => router.push('/chat')}>
            대화 목록으로
          </Button>
        </div>
      </div>
    );
  }

  const { feedbackSummary, vocabulary, scenario } = feedback;

  // Normalize expressions: can be string[] or {ja, ko}[]
  const normalizedExpressions = (feedbackSummary.recommendedExpressions ?? [])
    .map((expr) =>
      typeof expr === 'string'
        ? { ja: expr, ko: '' }
        : expr
    )
    .filter((e) => e.ja);

  return (
    <motion.div
      className="flex flex-col gap-4 p-4 pb-8"
      variants={container}
      initial="hidden"
      animate="show"
    >
      {/* Header */}
      <motion.div variants={item} className="flex items-center gap-3 pt-2">
        <Button
          variant="ghost"
          size="icon"
          onClick={() => router.push('/chat')}
        >
          <ArrowLeft className="size-5" />
        </Button>
        <h1 className="text-xl font-bold">회화 리포트</h1>
      </motion.div>

      {/* Scores */}
      <motion.div variants={item}>
        <FeedbackScores
          overallScore={feedbackSummary.overallScore}
          fluency={feedbackSummary.fluency}
          accuracy={feedbackSummary.accuracy}
          vocabularyDiversity={feedbackSummary.vocabularyDiversity}
          naturalness={feedbackSummary.naturalness}
        />
      </motion.div>

      {/* Transcript */}
      {feedbackSummary.translatedTranscript &&
        feedbackSummary.translatedTranscript.length > 0 && (
          <motion.div variants={item}>
            <FeedbackTranscript
              translatedTranscript={feedbackSummary.translatedTranscript}
              corrections={feedbackSummary.corrections ?? []}
            />
          </motion.div>
        )}

      {/* Details */}
      <motion.div variants={item}>
        <FeedbackDetails
          strengths={feedbackSummary.strengths ?? []}
          improvements={feedbackSummary.improvements ?? []}
          recommendedExpressions={feedbackSummary.recommendedExpressions ?? []}
          vocabulary={vocabulary ?? []}
        />
      </motion.div>

      {/* Expression Flashcards + Corrections → Wordbook */}
      {(normalizedExpressions.length > 0 ||
        (feedbackSummary.corrections ?? []).length > 0) && (
        <motion.div variants={item}>
          <ExpressionFlashcards
            expressions={normalizedExpressions}
            corrections={feedbackSummary.corrections ?? []}
            conversationId={conversationId}
          />
        </motion.div>
      )}

      {/* Action buttons */}
      <motion.div variants={item} className="mt-2 space-y-3">
        {scenario && (
          <Button
            className="w-full gap-2"
            onClick={() => router.push('/chat')}
          >
            <RotateCcw className="size-4" />
            같은 시나리오 다시하기
          </Button>
        )}
        <Button
          variant="outline"
          className="w-full gap-2"
          onClick={() => router.push('/chat')}
        >
          <Shuffle className="size-4" />
          다른 시나리오 도전하기
        </Button>
      </motion.div>
    </motion.div>
  );
}
