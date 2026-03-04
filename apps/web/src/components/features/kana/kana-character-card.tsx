'use client';

import { motion } from 'framer-motion';
import { Volume2, BookOpen } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet';
import type { KanaCharacterData } from '@/hooks/use-kana';

type KanaCharacterCardProps = {
  character: KanaCharacterData | null;
  correspondingCharacter?: KanaCharacterData | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
};

function getStatusLabel(character: KanaCharacterData) {
  if (character.progress?.mastered) return '마스터';
  if (character.progress) return '학습중';
  return '미학습';
}

function getStatusBadgeClass(character: KanaCharacterData) {
  if (character.progress?.mastered) return 'bg-primary/10 text-primary';
  if (character.progress) return 'bg-hk-blue/10 text-hk-blue';
  return 'bg-muted text-muted-foreground';
}

export function KanaCharacterCard({
  character,
  correspondingCharacter,
  open,
  onOpenChange,
}: KanaCharacterCardProps) {
  if (!character) return null;

  const status = getStatusLabel(character);
  const badgeClass = getStatusBadgeClass(character);

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="bottom" className="rounded-t-2xl">
        <SheetHeader>
          <div className="flex items-center justify-between">
            <SheetTitle>문자 상세</SheetTitle>
            <Badge variant="ghost" className={badgeClass}>
              {status}
            </Badge>
          </div>
        </SheetHeader>

        <div className="flex flex-col items-center gap-6 px-4 pb-6">
          {/* Large character display */}
          <motion.div
            initial={{ scale: 0.8, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ duration: 0.3, type: 'spring' }}
            className="bg-secondary flex size-32 items-center justify-center rounded-2xl"
          >
            <span className="font-jp text-6xl font-bold">
              {character.character}
            </span>
          </motion.div>

          {/* Romaji + pronunciation */}
          <div className="flex flex-col items-center gap-1">
            <span className="text-xl font-semibold">{character.romaji}</span>
            <span className="text-muted-foreground text-sm">
              발음: {character.pronunciation}
            </span>
          </div>

          {/* Corresponding kana */}
          {correspondingCharacter ? (
            <div className="bg-secondary flex items-center gap-3 rounded-xl p-3">
              <span className="font-jp text-2xl">
                {correspondingCharacter.character}
              </span>
              <div>
                <p className="text-sm font-medium">
                  대응{' '}
                  {correspondingCharacter.kanaType === 'HIRAGANA'
                    ? '히라가나'
                    : '가타카나'}
                </p>
                <p className="text-muted-foreground text-xs">
                  {correspondingCharacter.romaji}
                </p>
              </div>
            </div>
          ) : (
            <div className="text-muted-foreground flex items-center gap-1.5 text-sm">
              <BookOpen className="size-4" />
              <span>
                대응{' '}
                {character.kanaType === 'HIRAGANA' ? '가타카나' : '히라가나'}:{' '}
                {character.romaji}
              </span>
            </div>
          )}

          {/* Example word */}
          {character.exampleWord && (
            <motion.div
              initial={{ y: 10, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              transition={{ delay: 0.1, duration: 0.2 }}
              className="bg-secondary w-full rounded-xl px-4 py-3"
            >
              <div className="flex items-center gap-2">
                <Volume2 className="text-primary size-4 shrink-0" />
                <span className="text-muted-foreground text-xs">예시 단어</span>
              </div>
              <div className="mt-1.5 flex items-baseline gap-2">
                <span className="font-jp text-lg font-bold">
                  {character.exampleWord}
                </span>
                {character.exampleReading && (
                  <span className="font-jp text-muted-foreground text-sm">
                    {character.exampleReading}
                  </span>
                )}
              </div>
              {character.exampleMeaning && (
                <p className="text-muted-foreground mt-0.5 text-sm">
                  {character.exampleMeaning}
                </p>
              )}
            </motion.div>
          )}

          {/* Progress stats */}
          {character.progress && (
            <div className="grid w-full grid-cols-3 gap-2">
              <div className="bg-secondary flex flex-col items-center rounded-lg py-2">
                <span className="text-muted-foreground text-xs">정답</span>
                <span className="text-sm font-bold">
                  {character.progress.correctCount}
                </span>
              </div>
              <div className="bg-secondary flex flex-col items-center rounded-lg py-2">
                <span className="text-muted-foreground text-xs">오답</span>
                <span className="text-sm font-bold">
                  {character.progress.incorrectCount}
                </span>
              </div>
              <div className="bg-secondary flex flex-col items-center rounded-lg py-2">
                <span className="text-muted-foreground text-xs">연속</span>
                <span className="text-sm font-bold">
                  {character.progress.streak}회
                </span>
              </div>
            </div>
          )}
        </div>
      </SheetContent>
    </Sheet>
  );
}
