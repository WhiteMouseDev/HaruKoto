'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { useKanaCharacters } from '@/hooks/use-kana';
import { KanaChart } from '@/components/features/kana/kana-chart';
import { KanaCharacterCard } from '@/components/features/kana/kana-character-card';
import type { KanaCharacterData } from '@/hooks/use-kana';

export default function KanaChartPage() {
  const [selectedType, setSelectedType] = useState<'HIRAGANA' | 'KATAKANA'>(
    'HIRAGANA'
  );
  const [selectedChar, setSelectedChar] = useState<KanaCharacterData | null>(
    null
  );
  const [sheetOpen, setSheetOpen] = useState(false);

  const { data: hiraganaData, isLoading: hiraganaLoading } =
    useKanaCharacters('HIRAGANA', 'basic');
  const { data: katakanaData, isLoading: katakanaLoading } =
    useKanaCharacters('KATAKANA', 'basic');

  const activeData =
    selectedType === 'HIRAGANA' ? hiraganaData : katakanaData;
  const isLoading = hiraganaLoading || katakanaLoading;

  function getCorrespondingChar(char: KanaCharacterData) {
    const otherData =
      char.kanaType === 'HIRAGANA' ? katakanaData : hiraganaData;
    return (
      otherData?.characters.find((c) => c.romaji === char.romaji) ?? null
    );
  }

  function handleCharacterClick(char: KanaCharacterData) {
    setSelectedChar(char);
    setSheetOpen(true);
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <motion.h1
        className="pt-2 text-2xl font-bold"
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
      >
        50음도
      </motion.h1>

      <Tabs
        value={selectedType}
        onValueChange={(v) => setSelectedType(v as 'HIRAGANA' | 'KATAKANA')}
      >
        <TabsList className="w-full">
          <TabsTrigger value="HIRAGANA" className="flex-1">
            히라가나
          </TabsTrigger>
          <TabsTrigger value="KATAKANA" className="flex-1">
            가타카나
          </TabsTrigger>
        </TabsList>
      </Tabs>

      {isLoading ? (
        <div className="flex flex-col gap-2">
          {Array.from({ length: 11 }).map((_, i) => (
            <div
              key={i}
              className="bg-secondary h-12 animate-pulse rounded-lg"
            />
          ))}
        </div>
      ) : (
        <KanaChart
          characters={activeData?.characters ?? []}
          onCharacterClick={handleCharacterClick}
        />
      )}

      <KanaCharacterCard
        character={selectedChar}
        correspondingCharacter={
          selectedChar ? getCorrespondingChar(selectedChar) : null
        }
        open={sheetOpen}
        onOpenChange={setSheetOpen}
      />
    </div>
  );
}
