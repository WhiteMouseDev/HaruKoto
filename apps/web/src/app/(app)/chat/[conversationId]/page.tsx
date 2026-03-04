'use client';

import { useState, useEffect, useRef, use } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { ArrowLeft, ClipboardList, Eye, EyeOff, LogOut } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import { showGameEvents } from '@/lib/show-events';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { ChatMessage } from '@/components/features/chat/chat-message';
import { ChatInput } from '@/components/features/chat/chat-input';
import { TypingIndicator } from '@/components/features/chat/typing-indicator';

type Feedback = {
  type: string;
  original: string;
  correction: string;
  explanationKo: string;
};

type Vocabulary = {
  word: string;
  reading: string;
  meaningKo: string;
};

type Message = {
  id: string;
  role: 'ai' | 'user';
  messageJa: string;
  messageKo?: string;
  feedback?: Feedback[];
};

type MessageResponse = {
  messageJa: string;
  messageKo: string;
  feedback: Feedback[];
  hint: string;
  newVocabulary: Vocabulary[];
};

type StartResponse = {
  conversationId: string;
  firstMessage: {
    messageJa: string;
    messageKo: string;
    hint: string;
  };
};

type EndResponse = {
  success: boolean;
  feedbackSummary: Record<string, unknown> | null;
  events?: {
    type: 'level_up' | 'streak' | 'achievement';
    data: Record<string, unknown>;
  }[];
};

type ScenarioInfo = {
  title: string;
  titleJa: string;
  difficulty: string;
  situation: string;
  yourRole: string;
  aiRole: string;
};

const DIFFICULTY_LABELS: Record<string, string> = {
  BEGINNER: '초급',
  INTERMEDIATE: '중급',
  ADVANCED: '고급',
};

export default function ChatConversationPage({
  params,
}: {
  params: Promise<{ conversationId: string }>;
}) {
  const { conversationId } = use(params);
  const router = useRouter();
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const [messages, setMessages] = useState<Message[]>([]);
  const [scenario, setScenario] = useState<ScenarioInfo | null>(null);
  const [showTranslation, setShowTranslation] = useState(true);
  const [isTyping, setIsTyping] = useState(false);
  const [currentHint, setCurrentHint] = useState<string | null>(null);
  const [showHint, setShowHint] = useState(false);
  const [allVocabulary, setAllVocabulary] = useState<Vocabulary[]>([]);
  const [ending, setEnding] = useState(false);
  const [initialized, setInitialized] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Load initial conversation data
  useEffect(() => {
    // The conversation was started from the scenario selection page
    // The first AI message will come from the start API response stored in sessionStorage
    const stored = sessionStorage.getItem(`chat_${conversationId}`);
    if (stored) {
      try {
        const data = JSON.parse(stored) as {
          firstMessage: StartResponse['firstMessage'];
          scenario: ScenarioInfo;
        };
        setScenario(data.scenario);
        setMessages([
          {
            id: 'ai-0',
            role: 'ai',
            messageJa: data.firstMessage.messageJa,
            messageKo: data.firstMessage.messageKo,
          },
        ]);
        setCurrentHint(data.firstMessage.hint || null);
        setInitialized(true);
        sessionStorage.removeItem(`chat_${conversationId}`);
      } catch {
        fetchConversationFromServer();
      }
    } else {
      // No stored data (e.g. page refresh) — fetch from server
      fetchConversationFromServer();
    }

    async function fetchConversationFromServer() {
      try {
        const data = await apiFetch<{
          messages: Message[];
          scenario: ScenarioInfo | null;
          endedAt: string | null;
        }>(`/api/v1/chat/${conversationId}`);
        if (data.scenario) setScenario(data.scenario);
        if (data.messages.length > 0) setMessages(data.messages);
      } catch {
        // Conversation not found or unauthorized — stay on minimal UI
      } finally {
        setInitialized(true);
      }
    }
  }, [conversationId]);

  // Scroll to bottom on new messages
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isTyping]);

  async function handleSendMessage(text: string) {
    const userMsg: Message = {
      id: `user-${Date.now()}`,
      role: 'user',
      messageJa: text,
    };
    setMessages((prev) => [...prev, userMsg]);
    setIsTyping(true);
    setShowHint(false);
    setError(null);

    try {
      const data = await apiFetch<MessageResponse>('/api/v1/chat/message', {
        method: 'POST',
        body: JSON.stringify({ conversationId, message: text }),
      });

      // Update user message with feedback
      setMessages((prev) =>
        prev.map((m) =>
          m.id === userMsg.id ? { ...m, feedback: data.feedback } : m
        )
      );

      // Add AI response
      const aiMsg: Message = {
        id: `ai-${Date.now()}`,
        role: 'ai',
        messageJa: data.messageJa,
        messageKo: data.messageKo,
      };
      setMessages((prev) => [...prev, aiMsg]);
      setCurrentHint(data.hint || null);

      if (data.newVocabulary.length > 0) {
        setAllVocabulary((prev) => [...prev, ...data.newVocabulary]);
      }
    } catch (err) {
      setError(
        err instanceof Error ? err.message : '메시지 전송에 실패했습니다.'
      );
    } finally {
      setIsTyping(false);
    }
  }

  function handleHint() {
    setShowHint((prev) => !prev);
  }

  async function handleEndConversation() {
    setEnding(true);
    try {
      const data = await apiFetch<EndResponse>('/api/v1/chat/end', {
        method: 'POST',
        body: JSON.stringify({ conversationId }),
      });

      showGameEvents(data.events);

      // Store feedback and vocabulary for the feedback page
      sessionStorage.setItem(
        `feedback_${conversationId}`,
        JSON.stringify({
          feedbackSummary: data.feedbackSummary,
          vocabulary: allVocabulary,
          scenario,
        })
      );

      router.push(`/chat/${conversationId}/feedback`);
    } catch (err) {
      setError(
        err instanceof Error ? err.message : '대화를 종료할 수 없습니다.'
      );
      setEnding(false);
    }
  }

  if (!initialized) {
    return (
      <div className="flex min-h-dvh flex-col">
        <div className="flex items-center gap-3 border-b p-3">
          <div className="bg-secondary h-5 w-32 animate-pulse rounded" />
        </div>
        <div className="flex-1 space-y-4 p-4">
          <div className="bg-secondary h-20 animate-pulse rounded-xl" />
          <div className="bg-secondary h-16 w-3/4 animate-pulse rounded-xl" />
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-dvh flex-col">
      {/* Header */}
      <div className="shrink-0 border-b bg-background/80 backdrop-blur-sm">
        <div className="flex items-center gap-2 p-3">
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => router.push('/chat')}
          >
            <ArrowLeft className="size-5" />
          </Button>
          <div className="min-w-0 flex-1">
            <h1 className="truncate text-sm font-semibold">
              {scenario?.title ?? 'AI 회화'}
            </h1>
            {scenario && (
              <p className="text-muted-foreground truncate text-xs">
                {DIFFICULTY_LABELS[scenario.difficulty] ?? scenario.difficulty} ·
                역할: {scenario.yourRole}
              </p>
            )}
          </div>
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => setShowTranslation(!showTranslation)}
            title={showTranslation ? '번역 숨기기' : '번역 보기'}
          >
            {showTranslation ? (
              <Eye className="size-4" />
            ) : (
              <EyeOff className="size-4" />
            )}
          </Button>
        </div>
      </div>

      {/* Messages area */}
      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-lg space-y-4 p-4">
          {/* Situation context */}
          {scenario?.situation && (
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
            >
              <Card className="border-primary/20 bg-primary/5 py-3">
                <CardContent className="px-4 py-0">
                  <p className="flex items-center gap-1 text-xs font-medium text-primary">
                    <ClipboardList className="size-3.5" />
                    상황 설명
                  </p>
                  <p className="mt-1 text-sm">{scenario.situation}</p>
                  <p className="text-muted-foreground mt-1 text-xs">
                    나의 역할: {scenario.yourRole} · AI 역할: {scenario.aiRole}
                  </p>
                </CardContent>
              </Card>
            </motion.div>
          )}

          {/* Chat messages */}
          <AnimatePresence>
            {messages.map((msg) => (
              <ChatMessage
                key={msg.id}
                role={msg.role}
                messageJa={msg.messageJa}
                messageKo={msg.messageKo}
                feedback={msg.feedback}
                showTranslation={showTranslation}
                voiceEnabled
              />
            ))}
          </AnimatePresence>

          {/* Typing indicator */}
          {isTyping && (
            <div className="flex justify-start">
              <div className="bg-card rounded-2xl rounded-tl-sm border px-2 py-1 shadow-sm">
                <TypingIndicator />
              </div>
            </div>
          )}

          {/* Error */}
          {error && (
            <div className="bg-hk-error/10 text-hk-error rounded-lg px-4 py-2 text-center text-xs">
              {error}
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>
      </div>

      {/* End conversation button */}
      {messages.length >= 2 && (
        <div className="flex justify-center border-t bg-background/80 px-4 py-2 backdrop-blur-sm">
          <Button
            variant="outline"
            size="sm"
            onClick={handleEndConversation}
            disabled={ending || isTyping}
            className="text-muted-foreground gap-1.5 text-xs"
          >
            <LogOut className="size-3.5" />
            {ending ? '종료 중...' : '대화 끝내기'}
          </Button>
        </div>
      )}

      {/* Input area */}
      <ChatInput
        onSend={handleSendMessage}
        onHint={handleHint}
        hint={showHint ? currentHint : null}
        disabled={isTyping || ending}
        voiceEnabled
      />
    </div>
  );
}
