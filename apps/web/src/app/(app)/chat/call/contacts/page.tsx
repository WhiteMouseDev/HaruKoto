'use client';

import { useMemo } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { ArrowLeft, Lock, Phone, Heart } from 'lucide-react';
import Image from 'next/image';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { useProfile } from '@/hooks/use-dashboard';
import {
  useCharacters,
  useCharacterStats,
  useCharacterFavorites,
  useToggleFavorite,
} from '@/hooks/use-characters';
import { cn } from '@/lib/utils';

const LEVEL_ORDER = ['N5', 'N4', 'N3', 'N2', 'N1'];

function isUnlocked(condition: string | null, userLevel: string): boolean {
  if (!condition) return true;
  const userIdx = LEVEL_ORDER.indexOf(userLevel);
  const requiredIdx = LEVEL_ORDER.indexOf(condition);
  return userIdx >= requiredIdx;
}

const container = {
  hidden: { opacity: 0 },
  show: { opacity: 1, transition: { staggerChildren: 0.1 } },
};

const item = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35 } },
};

export default function ContactsPage() {
  const router = useRouter();
  const { data: profileData } = useProfile();
  const { data: characters, isLoading } = useCharacters();
  const { data: stats } = useCharacterStats();
  const { data: favorites } = useCharacterFavorites();
  const { mutate: toggleFavorite } = useToggleFavorite();
  const userLevel = profileData?.profile.jlptLevel ?? 'N5';

  const sortedCharacters = useMemo(() => {
    if (!characters) return [];
    return [...characters].sort((a, b) => {
      const aFav = favorites?.has(a.id) ? 1 : 0;
      const bFav = favorites?.has(b.id) ? 1 : 0;
      if (aFav !== bFav) return bFav - aFav;
      return a.order - b.order;
    });
  }, [characters, favorites]);

  return (
    <motion.div
      className="flex flex-col gap-4 p-4"
      variants={container}
      initial="hidden"
      animate="show"
    >
      {/* Header */}
      <motion.div variants={item} className="flex items-center gap-2 pt-2">
        <Button
          variant="ghost"
          size="icon"
          className="size-8"
          onClick={() => router.push('/chat')}
        >
          <ArrowLeft className="size-4" />
        </Button>
        <h1 className="text-2xl font-bold">연락처</h1>
      </motion.div>

      {/* Loading */}
      {isLoading && (
        <div className="flex justify-center py-12">
          <div className="size-6 animate-spin rounded-full border-2 border-primary/30 border-t-primary" />
        </div>
      )}

      {/* Character List */}
      <div className="flex flex-col gap-3">
        {sortedCharacters.map((char) => {
          const unlocked = isUnlocked(char.unlockCondition, userLevel);
          const callCount = stats?.[char.id] ?? 0;
          const isFavorite = favorites?.has(char.id) ?? false;

          return (
            <motion.div key={char.id} variants={item}>
              <Card
                className={cn(
                  'transition-colors',
                  unlocked
                    ? 'cursor-pointer hover:bg-accent/50'
                    : 'opacity-60'
                )}
                onClick={() => {
                  if (unlocked) {
                    router.push(`/chat/call?characterId=${char.id}`);
                  }
                }}
              >
                <CardContent className="flex items-center gap-4 p-4">
                  {/* Avatar */}
                  <div
                    className={cn(
                      'flex size-14 shrink-0 items-center justify-center rounded-full bg-gradient-to-br text-2xl overflow-hidden',
                      char.gradient ?? 'from-violet-500/15 to-fuchsia-500/10'
                    )}
                  >
                    {!unlocked ? (
                      <Lock className="text-muted-foreground size-5" />
                    ) : char.avatarUrl ? (
                      <Image
                        src={char.avatarUrl}
                        alt={char.name}
                        width={56}
                        height={56}
                        className="size-full object-cover"
                      />
                    ) : (
                      char.avatarEmoji
                    )}
                  </div>

                  {/* Info */}
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <h3 className="font-semibold">
                        {char.name}
                        <span className="font-jp ml-1 text-sm font-normal text-muted-foreground">
                          ({char.nameJa})
                        </span>
                      </h3>
                    </div>
                    <p className="text-muted-foreground text-sm">
                      {char.description}
                    </p>
                    <p className="text-muted-foreground mt-0.5 text-xs">
                      {unlocked
                        ? `${char.speechStyle} · ${char.targetLevel}${callCount > 0 ? ` · ${callCount}회 통화` : ''}`
                        : `${char.unlockCondition} 도달 시 해금`}
                    </p>
                  </div>

                  {/* Favorite + Call */}
                  {unlocked && (
                    <div className="flex shrink-0 items-center gap-2">
                      <button
                        type="button"
                        className="flex size-8 items-center justify-center rounded-full transition-colors hover:bg-accent"
                        onClick={(e) => {
                          e.stopPropagation();
                          toggleFavorite(char.id);
                        }}
                      >
                        <Heart
                          className={cn(
                            'size-4 transition-colors',
                            isFavorite
                              ? 'fill-rose-500 text-rose-500'
                              : 'text-muted-foreground'
                          )}
                        />
                      </button>
                      <div className="flex size-10 items-center justify-center rounded-full bg-emerald-500/15">
                        <Phone className="size-4 text-emerald-500" />
                      </div>
                    </div>
                  )}
                </CardContent>
              </Card>
            </motion.div>
          );
        })}
      </div>

      {/* Info */}
      <motion.p
        variants={item}
        className="text-muted-foreground text-center text-xs"
      >
        JLPT 레벨이 올라가면 새로운 캐릭터가 해금됩니다
      </motion.p>
    </motion.div>
  );
}
