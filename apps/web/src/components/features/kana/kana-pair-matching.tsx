'use client';

import { useState, useCallback, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Progress } from '@/components/ui/progress';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import { Check } from 'lucide-react';

type PairItem = {
  id: string;
  character: string;
  romaji: string;
};

type PairMatchingProps = {
  pairs: PairItem[];
  onComplete: () => void;
};

type CardState = 'default' | 'selected' | 'matched' | 'wrong';

const PAIRS_PER_ROUND = 4;

const shakeAnimation = {
  x: [0, -8, 8, -6, 6, -3, 3, 0],
  transition: { duration: 0.4 },
};

function shuffleArray<T>(array: readonly T[]): T[] {
  const result = [...array];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

export function KanaPairMatching({ pairs, onComplete }: PairMatchingProps) {
  const totalRounds = Math.ceil(pairs.length / PAIRS_PER_ROUND);

  const [currentRound, setCurrentRound] = useState(0);
  const [prevRound, setPrevRound] = useState(0);
  const [matchedIds, setMatchedIds] = useState<Set<string>>(new Set());
  const [selectedKana, setSelectedKana] = useState<string | null>(null);
  const [selectedRomaji, setSelectedRomaji] = useState<string | null>(null);
  const [wrongPair, setWrongPair] = useState<{
    kanaId: string;
    romajiId: string;
  } | null>(null);

  // Reset state when round changes (React recommended pattern)
  if (prevRound !== currentRound) {
    setPrevRound(currentRound);
    setMatchedIds(new Set());
    setSelectedKana(null);
    setSelectedRomaji(null);
    setWrongPair(null);
  }

  // Divide pairs into rounds
  const rounds = useMemo(() => {
    const shuffled = shuffleArray(pairs);
    const result: PairItem[][] = [];
    for (let i = 0; i < shuffled.length; i += PAIRS_PER_ROUND) {
      result.push(shuffled.slice(i, i + PAIRS_PER_ROUND));
    }
    return result;
  }, [pairs]);

  const currentPairs = useMemo(
    () => rounds[currentRound] ?? [],
    [rounds, currentRound]
  );

  // Shuffle romaji column independently per round
  const shuffledRomaji = useMemo(
    () => shuffleArray(currentPairs),
    [currentPairs]
  );

  const checkMatch = useCallback(
    (kanaId: string, romajiId: string) => {
      const kanaPair = currentPairs.find((p) => p.id === kanaId);
      const romajiPair = currentPairs.find((p) => p.id === romajiId);

      if (!kanaPair || !romajiPair) return;

      if (kanaPair.romaji === romajiPair.romaji && kanaPair.id === romajiPair.id) {
        // Correct match
        const newMatched = new Set(matchedIds);
        newMatched.add(kanaId);
        setMatchedIds(newMatched);
        setSelectedKana(null);
        setSelectedRomaji(null);

        // Check if round is complete
        if (newMatched.size === currentPairs.length) {
          setTimeout(() => {
            if (currentRound + 1 >= totalRounds) {
              onComplete();
            } else {
              setCurrentRound((prev) => prev + 1);
            }
          }, 600);
        }
      } else {
        // Wrong match
        setWrongPair({ kanaId, romajiId });
        setTimeout(() => {
          setWrongPair(null);
          setSelectedKana(null);
          setSelectedRomaji(null);
        }, 500);
      }
    },
    [currentPairs, matchedIds, currentRound, totalRounds, onComplete]
  );

  const handleKanaClick = useCallback(
    (id: string) => {
      if (matchedIds.has(id) || wrongPair) return;

      if (selectedKana === id) {
        setSelectedKana(null);
        return;
      }

      setSelectedKana(id);

      if (selectedRomaji) {
        checkMatch(id, selectedRomaji);
      }
    },
    [matchedIds, wrongPair, selectedKana, selectedRomaji, checkMatch]
  );

  const handleRomajiClick = useCallback(
    (id: string) => {
      if (matchedIds.has(id) || wrongPair) return;

      if (selectedRomaji === id) {
        setSelectedRomaji(null);
        return;
      }

      setSelectedRomaji(id);

      if (selectedKana) {
        checkMatch(selectedKana, id);
      }
    },
    [matchedIds, wrongPair, selectedRomaji, selectedKana, checkMatch]
  );

  const getCardState = (
    id: string,
    side: 'kana' | 'romaji'
  ): CardState => {
    if (matchedIds.has(id)) return 'matched';
    if (wrongPair) {
      if (side === 'kana' && wrongPair.kanaId === id) return 'wrong';
      if (side === 'romaji' && wrongPair.romajiId === id) return 'wrong';
    }
    if (side === 'kana' && selectedKana === id) return 'selected';
    if (side === 'romaji' && selectedRomaji === id) return 'selected';
    return 'default';
  };

  const progressPercent =
    totalRounds > 0
      ? Math.round(
          ((currentRound * PAIRS_PER_ROUND + matchedIds.size) / pairs.length) *
            100
        )
      : 0;

  return (
    <div className="flex flex-col gap-6">
      {/* Progress */}
      <div className="flex flex-col gap-2">
        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">짝 맞추기</span>
          <div className="flex items-center gap-2">
            {totalRounds > 1 && (
              <Badge variant="secondary" className="text-xs">
                라운드 {currentRound + 1}/{totalRounds}
              </Badge>
            )}
            <span className="font-medium">
              {matchedIds.size}/{currentPairs.length}
            </span>
          </div>
        </div>
        <Progress value={progressPercent} />
      </div>

      {/* Instruction */}
      <p className="text-muted-foreground text-center text-sm">
        왼쪽 가나와 오른쪽 로마지를 짝지어 주세요
      </p>

      {/* Card Grid */}
      <AnimatePresence mode="wait">
        <motion.div
          key={currentRound}
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -10 }}
          transition={{ duration: 0.25 }}
          className="grid grid-cols-2 gap-3"
        >
          {/* Left Column: Kana */}
          <div className="flex flex-col gap-3">
            {currentPairs.map((pair) => {
              const state = getCardState(pair.id, 'kana');
              return (
                <PairCard
                  key={`kana-${pair.id}`}
                  text={pair.character}
                  state={state}
                  isKana
                  onClick={() => handleKanaClick(pair.id)}
                />
              );
            })}
          </div>

          {/* Right Column: Romaji (shuffled) */}
          <div className="flex flex-col gap-3">
            {shuffledRomaji.map((pair) => {
              const state = getCardState(pair.id, 'romaji');
              return (
                <PairCard
                  key={`romaji-${pair.id}`}
                  text={pair.romaji}
                  state={state}
                  isKana={false}
                  onClick={() => handleRomajiClick(pair.id)}
                />
              );
            })}
          </div>
        </motion.div>
      </AnimatePresence>
    </div>
  );
}

type PairCardProps = {
  text: string;
  state: CardState;
  isKana: boolean;
  onClick: () => void;
};

function PairCard({ text, state, isKana, onClick }: PairCardProps) {
  const isDisabled = state === 'matched';

  return (
    <motion.button
      whileTap={isDisabled ? undefined : { scale: 0.96 }}
      animate={state === 'wrong' ? shakeAnimation : {}}
      onClick={onClick}
      disabled={isDisabled}
      className={cn(
        'relative flex min-h-[60px] items-center justify-center rounded-xl border px-4 py-3 font-medium transition-colors',
        isKana ? 'font-jp text-2xl' : 'text-lg',
        state === 'default' && 'bg-card hover:bg-accent',
        state === 'selected' && 'border-primary ring-primary/30 ring-2',
        state === 'matched' &&
          'border-hk-success bg-hk-success/20 opacity-60 cursor-default',
        state === 'wrong' && 'border-destructive bg-destructive/10'
      )}
    >
      {text}
      {state === 'matched' && (
        <motion.span
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          className="text-hk-success absolute right-2 top-2"
        >
          <Check className="size-4" />
        </motion.span>
      )}
    </motion.button>
  );
}
