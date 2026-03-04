'use client';

import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import Image from 'next/image';
import { Clock, Star, ChevronRight, Phone, MessageSquare } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useChatHistory } from '@/hooks/use-chat-history';

const listItem = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3 } },
};

function formatDate(dateStr: string) {
  const d = new Date(dateStr);
  const month = d.getMonth() + 1;
  const day = d.getDate();
  const hours = String(d.getHours()).padStart(2, '0');
  const mins = String(d.getMinutes()).padStart(2, '0');
  return `${month}/${day} ${hours}:${mins}`;
}

function ScoreBadge({ score }: { score: number | null }) {
  if (score === null) return null;

  const stars = Math.round((score / 100) * 5 * 10) / 10;
  const color =
    score >= 80
      ? 'text-hk-yellow'
      : score >= 50
        ? 'text-amber-400'
        : 'text-muted-foreground';

  return (
    <span className={`flex items-center gap-0.5 text-xs font-semibold ${color}`}>
      <Star className="size-3 fill-current" />
      {stars.toFixed(1)}
    </span>
  );
}

type ConversationHistoryProps = {
  filter?: 'voice' | 'text';
};

export function ConversationHistory({ filter }: ConversationHistoryProps = {}) {
  const router = useRouter();
  const {
    data,
    isLoading: loading,
    hasNextPage,
    fetchNextPage,
    isFetchingNextPage: loadingMore,
  } = useChatHistory();

  const allItems = data?.pages.flatMap((page) => page.history) ?? [];

  // Filter by conversation type if specified
  const items = filter
    ? allItems.filter((item) => {
        // Voice: no scenario (direct call) or FREE category
        const isVoice = !item.scenario || item.scenario.category === 'FREE';
        return filter === 'voice' ? isVoice : !isVoice;
      })
    : allItems;

  if (loading) {
    return (
      <div className="space-y-2">
        {[1, 2, 3].map((n) => (
          <div
            key={n}
            className="bg-secondary h-16 animate-pulse rounded-xl"
          />
        ))}
      </div>
    );
  }

  if (items.length === 0) {
    return (
      <div className="py-6 text-center">
        <p className="text-muted-foreground text-sm">
          아직 회화 기록이 없어요.
        </p>
      </div>
    );
  }

  return (
    <motion.div
      className="space-y-2"
      initial="hidden"
      animate="show"
      transition={{ staggerChildren: 0.06 }}
    >
      {items.map((item) => {
        const isVoiceCall = !item.scenario || item.scenario.category === 'FREE';

        return (
          <motion.div key={item.id} variants={listItem}>
            <Card
              className="cursor-pointer transition-colors hover:bg-accent/50"
              onClick={() => router.push(`/chat/${item.id}/feedback`)}
            >
              <CardContent className="flex items-center gap-3 px-4 py-3">
                {/* Icon */}
                <div className="bg-secondary flex size-10 shrink-0 items-center justify-center rounded-full overflow-hidden">
                  {item.character?.avatarUrl ? (
                    <Image
                      src={item.character.avatarUrl}
                      alt={item.character.name}
                      width={40}
                      height={40}
                      className="size-full object-cover"
                    />
                  ) : isVoiceCall ? (
                    <Phone className="text-primary size-4" />
                  ) : (
                    <MessageSquare className="text-primary size-4" />
                  )}
                </div>

                {/* Content */}
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">
                    {item.character
                      ? `${item.character.name}와의 통화`
                      : item.scenario?.title ?? '음성 통화'}
                  </p>
                  <div className="text-muted-foreground mt-0.5 flex items-center gap-2 text-xs">
                    <span className="flex items-center gap-0.5">
                      <Clock className="size-3" />
                      {formatDate(item.createdAt)}
                    </span>
                    <span>{item.messageCount}턴</span>
                  </div>
                </div>

                {/* Score + Arrow */}
                <div className="flex items-center gap-2">
                  <ScoreBadge score={item.overallScore} />
                  <ChevronRight className="text-muted-foreground size-4" />
                </div>
              </CardContent>
            </Card>
          </motion.div>
        );
      })}

      {hasNextPage && (
        <Button
          variant="ghost"
          className="w-full text-sm"
          onClick={() => fetchNextPage()}
          disabled={loadingMore}
        >
          {loadingMore ? '불러오는 중...' : '더 보기'}
        </Button>
      )}
    </motion.div>
  );
}
