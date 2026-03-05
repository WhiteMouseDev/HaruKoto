'use client';

import { useState, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import {
  FlaskConical,
  ArrowLeft,
  Play,
  RefreshCw,
  Plane,
  Store,
  Briefcase,
  MessageSquare,
  FolderOpen,
  Phone,
  Clock,
  MessageCircle,
} from 'lucide-react';
import { apiFetch } from '@/lib/api';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { CategoryGrid } from '@/components/features/chat/category-grid';
import { ScenarioCard } from '@/components/features/chat/scenario-card';
import { PhoneCallCta } from '@/components/features/chat/phone-call-cta';
import { ConversationHistory } from '@/components/features/chat/conversation-history';
import { useScenarios, type Scenario, type ScenariosResponse } from '@/hooks/use-scenarios';
import { cn } from '@/lib/utils';
import { FoxMascot } from '@/components/brand/fox-mascot';

type StartResponse = {
  conversationId: string;
  firstMessage: {
    messageJa: string;
    messageKo: string;
    hint: string;
  };
};

type SubTab = 'voice' | 'text';

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.08 },
  },
};

const item = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35 } },
};

const CATEGORY_META: Record<string, { icon: ReactNode; label: string }> = {
  TRAVEL: { icon: <Plane className="size-5" />, label: '여행 시나리오' },
  DAILY: { icon: <Store className="size-5" />, label: '일상 시나리오' },
  BUSINESS: {
    icon: <Briefcase className="size-5" />,
    label: '비즈니스 시나리오',
  },
  FREE: {
    icon: <MessageSquare className="size-5" />,
    label: '자유주제 시나리오',
  },
};

export default function ChatPage() {
  const router = useRouter();
  const [activeTab, setActiveTab] = useState<SubTab>('voice');
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const {
    data: scenariosData,
    isLoading: loading,
    error: scenariosError,
    refetch: refetchScenarios,
  } = useScenarios(selectedCategory);

  const scenarios = scenariosData?.scenarios ?? [];
  const scenarioError =
    scenariosError instanceof Error
      ? scenariosError.message
      : scenariosError
        ? '시나리오를 불러올 수 없습니다.'
        : null;

  async function handleStartConversation(scenario: Scenario) {
    setStarting(true);
    try {
      const data = await apiFetch<StartResponse>('/api/v1/chat/start', {
        method: 'POST',
        body: JSON.stringify({ scenarioId: scenario.id }),
      });

      sessionStorage.setItem(
        `chat_${data.conversationId}`,
        JSON.stringify({
          firstMessage: data.firstMessage,
          scenario: {
            title: scenario.title,
            titleJa: scenario.titleJa,
            difficulty: scenario.difficulty,
            situation: scenario.situation,
            yourRole: scenario.yourRole,
            aiRole: scenario.aiRole,
          },
        })
      );

      router.push(`/chat/${data.conversationId}`);
    } catch (err) {
      setError(
        err instanceof Error ? err.message : '대화를 시작할 수 없습니다.'
      );
      setStarting(false);
    }
  }

  async function handleFreeChat() {
    setStarting(true);
    try {
      const data = await apiFetch<ScenariosResponse>(
        '/api/v1/chat/scenarios?category=FREE'
      );
      if (data.scenarios.length > 0) {
        await handleStartConversation(data.scenarios[0]);
      } else {
        setError('자유 대화 시나리오가 없습니다.');
        setStarting(false);
      }
    } catch (err) {
      setError(
        err instanceof Error ? err.message : '대화를 시작할 수 없습니다.'
      );
      setStarting(false);
    }
  }

  // Scenario list view (for text chat)
  if (selectedCategory) {
    const meta = CATEGORY_META[selectedCategory];
    return (
      <motion.div
        className="flex flex-col gap-4 p-4"
        variants={container}
        initial="hidden"
        animate="show"
      >
        <motion.div variants={item} className="flex items-center gap-3 pt-2">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => setSelectedCategory(null)}
          >
            <ArrowLeft className="size-5" />
          </Button>
          <h1 className="flex items-center gap-2 text-xl font-bold">
            {meta?.icon}
            <span>{meta?.label}</span>
          </h1>
        </motion.div>

        {loading ? (
          <div className="space-y-3">
            {[1, 2, 3].map((n) => (
              <div
                key={n}
                className="bg-secondary h-20 animate-pulse rounded-xl"
              />
            ))}
          </div>
        ) : scenarioError ? (
          <div className="flex flex-col items-center gap-3 py-8">
            <p className="text-muted-foreground text-sm">{scenarioError}</p>
            <Button
              variant="outline"
              size="sm"
              onClick={() => refetchScenarios()}
            >
              <RefreshCw className="mr-1.5 size-3.5" />
              다시 시도
            </Button>
          </div>
        ) : scenarios.length === 0 ? (
          <div className="py-8 text-center">
            <p className="text-muted-foreground text-sm">
              아직 시나리오가 없습니다.
            </p>
          </div>
        ) : (
          <motion.div variants={item} className="space-y-2">
            {scenarios.map((scenario) => (
              <ScenarioCard
                key={scenario.id}
                scenario={scenario}
                onSelect={() => handleStartConversation(scenario)}
                onCall={() => router.push(`/chat/call?scenarioId=${scenario.id}`)}
              />
            ))}
          </motion.div>
        )}

        {starting && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30">
            <div className="bg-card flex items-center gap-3 rounded-2xl px-6 py-4 shadow-lg">
              <div className="border-primary size-5 animate-spin rounded-full border-2 border-t-transparent" />
              <span className="text-sm font-medium">대화 시작 중...</span>
            </div>
          </div>
        )}
      </motion.div>
    );
  }

  return (
    <motion.div
      className="flex flex-col gap-5 p-4"
      variants={container}
      initial="hidden"
      animate="show"
    >
      {/* Header */}
      <motion.div variants={item} className="flex items-center gap-2 pt-2">
        <h1 className="text-2xl font-bold">AI 회화</h1>
        <span className="bg-primary/10 text-primary inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium">
          <FlaskConical className="size-3" />
          Beta
        </span>
      </motion.div>

      {/* Sub Tabs */}
      <motion.div variants={item} className="flex gap-1 rounded-2xl bg-secondary p-1">
        <button
          onClick={() => setActiveTab('voice')}
          className={cn(
            'flex flex-1 items-center justify-center gap-1.5 rounded-xl px-3 py-2 text-sm font-medium transition-all',
            activeTab === 'voice'
              ? 'bg-card text-foreground shadow-sm'
              : 'text-muted-foreground hover:text-foreground'
          )}
        >
          <Phone className="size-4" />
          음성통화
        </button>
        <button
          onClick={() => setActiveTab('text')}
          className={cn(
            'flex flex-1 items-center justify-center gap-1.5 rounded-xl px-3 py-2 text-sm font-medium transition-all',
            activeTab === 'text'
              ? 'bg-card text-foreground shadow-sm'
              : 'text-muted-foreground hover:text-foreground'
          )}
        >
          <MessageCircle className="size-4" />
          텍스트 회화
        </button>
      </motion.div>

      {/* Voice Tab Content */}
      {activeTab === 'voice' && (
        <motion.div
          key="voice"
          className="flex flex-col gap-5"
          variants={container}
          initial="hidden"
          animate="show"
        >
          <motion.div variants={item}>
            <PhoneCallCta onClick={() => router.push('/chat/call/contacts')} />
          </motion.div>

          <motion.div variants={item}>
            <h2 className="mb-3 flex items-center gap-1.5 font-semibold">
              <FolderOpen className="size-4" />
              시나리오 통화
            </h2>
            <CategoryGrid
              onSelect={(cat) => setSelectedCategory(cat)}
              variant="call"
            />
          </motion.div>

          <motion.div variants={item}>
            <h2 className="mb-3 flex items-center gap-1.5 font-semibold">
              <Clock className="size-4" />
              최근 통화 기록
            </h2>
            <ConversationHistory filter="voice" />
          </motion.div>
        </motion.div>
      )}

      {/* Text Tab Content */}
      {activeTab === 'text' && (
        <motion.div
          key="text"
          className="flex flex-col gap-5"
          variants={container}
          initial="hidden"
          animate="show"
        >
          <motion.div variants={item}>
            <motion.div whileTap={{ scale: 0.98 }}>
              <Card
                className="border-primary/30 from-primary/10 to-accent cursor-pointer bg-gradient-to-r py-4"
                onClick={handleFreeChat}
              >
                <CardContent className="flex items-center gap-4 p-4">
                  <div className="flex size-12 shrink-0 items-center justify-center rounded-full bg-primary/20">
                    <FoxMascot size={28} />
                  </div>
                  <div className="flex-1">
                    <h3 className="font-semibold">하루와 자유롭게 대화</h3>
                    <p className="text-muted-foreground text-sm">
                      어떤 주제든 일본어로!
                    </p>
                  </div>
                  <Play className="text-primary size-5" />
                </CardContent>
              </Card>
            </motion.div>
          </motion.div>

          <motion.div variants={item}>
            <h2 className="mb-3 flex items-center gap-1.5 font-semibold">
              <FolderOpen className="size-4" />
              상황별 시나리오
            </h2>
            <CategoryGrid onSelect={setSelectedCategory} />
          </motion.div>

          <motion.div variants={item}>
            <h2 className="mb-3 flex items-center gap-1.5 font-semibold">
              <Clock className="size-4" />
              지난 회화 기록
            </h2>
            <ConversationHistory filter="text" />
          </motion.div>
        </motion.div>
      )}

      {/* Starting overlay */}
      {starting && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30">
          <div className="bg-card flex items-center gap-3 rounded-2xl px-6 py-4 shadow-lg">
            <div className="border-primary size-5 animate-spin rounded-full border-2 border-t-transparent" />
            <span className="text-sm font-medium">대화 시작 중...</span>
          </div>
        </div>
      )}

      {error && (
        <div className="bg-hk-error/10 text-hk-error rounded-lg px-4 py-3 text-center text-sm">
          {error}
        </div>
      )}
    </motion.div>
  );
}
