'use client';

import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { ArrowLeft, Lock, Phone } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { useProfile } from '@/hooks/use-dashboard';
import { cn } from '@/lib/utils';

type AiCharacter = {
  id: string;
  name: string;
  nameJa: string;
  description: string;
  speechStyle: string;
  targetLevel: string;
  avatarEmoji: string;
  unlockCondition: string | null;
  gradient: string;
};

// Phase 0: 하드코딩된 캐릭터 데이터 (추후 DB로 전환)
const CHARACTERS: AiCharacter[] = [
  {
    id: 'haru',
    name: '하루',
    nameJa: 'はる',
    description: '친절한 친구',
    speechStyle: '카주얼 (タメ語)',
    targetLevel: '초급~중급',
    avatarEmoji: '🦊',
    unlockCondition: null,
    gradient: 'from-violet-500/15 to-fuchsia-500/10',
  },
  {
    id: 'yuki',
    name: '유키',
    nameJa: 'ゆき',
    description: '엄격한 선생님',
    speechStyle: '정중체 (です/ます)',
    targetLevel: '중급',
    avatarEmoji: '👩‍🏫',
    unlockCondition: 'N4',
    gradient: 'from-blue-500/15 to-cyan-500/10',
  },
  {
    id: 'riko',
    name: '리코',
    nameJa: 'りこ',
    description: '비즈니스 동료',
    speechStyle: '공손체 (敬語)',
    targetLevel: '고급',
    avatarEmoji: '👨‍💼',
    unlockCondition: 'N3',
    gradient: 'from-amber-500/15 to-orange-500/10',
  },
];

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
  const userLevel = profileData?.profile.jlptLevel ?? 'N5';

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

      {/* Character List */}
      <div className="flex flex-col gap-3">
        {CHARACTERS.map((char) => {
          const unlocked = isUnlocked(char.unlockCondition, userLevel);

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
                      'flex size-14 shrink-0 items-center justify-center rounded-full bg-gradient-to-br text-2xl',
                      char.gradient
                    )}
                  >
                    {unlocked ? char.avatarEmoji : <Lock className="text-muted-foreground size-5" />}
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
                        ? `${char.speechStyle} · ${char.targetLevel}`
                        : `${char.unlockCondition} 도달 시 해금`}
                    </p>
                  </div>

                  {/* Call button */}
                  {unlocked && (
                    <div className="flex size-10 shrink-0 items-center justify-center rounded-full bg-emerald-500/15">
                      <Phone className="size-4 text-emerald-500" />
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
