'use client';

import { useState, useEffect, use } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { ArrowLeft, RotateCcw, Shuffle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { FeedbackScores } from '@/components/features/chat/feedback-scores';
import { FeedbackDetails } from '@/components/features/chat/feedback-details';

type FeedbackSummary = {
  overallScore: number;
  fluency: number;
  accuracy: number;
  vocabularyDiversity: number;
  naturalness: number;
  strengths: string[];
  improvements: string[];
  recommendedExpressions: string[];
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
  const [feedback, setFeedback] = useState<StoredFeedback | null>(null);

  useEffect(() => {
    const stored = sessionStorage.getItem(`feedback_${conversationId}`);
    if (stored) {
      try {
        setFeedback(JSON.parse(stored));
        sessionStorage.removeItem(`feedback_${conversationId}`);
      } catch {
        fetchFeedbackFromServer();
      }
    } else {
      fetchFeedbackFromServer();
    }

    async function fetchFeedbackFromServer() {
      try {
        const res = await fetch(`/api/v1/chat/${conversationId}`);
        if (!res.ok) return;
        const data = await res.json();
        if (data.feedbackSummary) {
          setFeedback({
            feedbackSummary: data.feedbackSummary,
            vocabulary: [],
            scenario: data.scenario,
          });
        }
      } catch {
        // Failed to load — stay on "no data" state
      }
    }
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

      {/* Details */}
      <motion.div variants={item}>
        <FeedbackDetails
          strengths={feedbackSummary.strengths ?? []}
          improvements={feedbackSummary.improvements ?? []}
          recommendedExpressions={feedbackSummary.recommendedExpressions ?? []}
          vocabulary={vocabulary ?? []}
        />
      </motion.div>

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
