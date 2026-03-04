'use client';

import { Fragment } from 'react';
import { motion } from 'framer-motion';
import { cn } from '@/lib/utils';
import type { KanaCharacterData } from '@/hooks/use-kana';

type KanaChartProps = {
  characters: KanaCharacterData[];
  onCharacterClick: (character: KanaCharacterData) => void;
};

const ROWS = [
  { key: 'a', label: '\u2205' },
  { key: 'ka', label: 'k' },
  { key: 'sa', label: 's' },
  { key: 'ta', label: 't' },
  { key: 'na', label: 'n' },
  { key: 'ha', label: 'h' },
  { key: 'ma', label: 'm' },
  { key: 'ya', label: 'y' },
  { key: 'ra', label: 'r' },
  { key: 'wa', label: 'w' },
  { key: 'n', label: 'n' },
] as const;

const COLUMNS = ['a', 'i', 'u', 'e', 'o'] as const;

// Positions that should be empty (no character exists)
const EMPTY_CELLS = new Set([
  'ya-i',
  'ya-e',
  'wa-i',
  'wa-u',
  'wa-e',
]);

function getCellStatus(character: KanaCharacterData) {
  if (character.progress?.mastered) return 'mastered';
  if (character.progress) return 'learned';
  return 'locked';
}

export function KanaChart({ characters, onCharacterClick }: KanaChartProps) {
  // Build a lookup map: row-column → character
  const charMap = new Map<string, KanaCharacterData>();
  for (const char of characters) {
    charMap.set(`${char.row}-${char.column}`, char);
  }

  return (
    <div className="w-full overflow-x-auto">
      <div
        role="grid"
        aria-label="가나 50음도 차트"
        className="grid min-w-[320px] gap-1.5"
        style={{
          gridTemplateColumns: 'auto repeat(5, 1fr)',
        }}
      >
        {/* Column headers */}
        <div />
        {COLUMNS.map((col) => (
          <div
            key={col}
            className="text-muted-foreground flex items-center justify-center text-xs font-medium"
          >
            {col}
          </div>
        ))}

        {/* Rows */}
        {ROWS.map((row, rowIdx) => (
          <Fragment key={row.key}>
            {/* Row header */}
            <div
              className="text-muted-foreground flex min-h-[44px] min-w-[28px] items-center justify-center text-xs font-medium"
            >
              {row.label}
            </div>

            {/* Character cells */}
            {COLUMNS.map((col, colIdx) => {
              const cellKey = `${row.key}-${col}`;

              // Handle the special n row (ん) - only show in the 'a' column
              if (row.key === 'n' && col !== 'a') {
                return <div key={cellKey} />;
              }

              // Empty cells (non-existent kana positions)
              if (EMPTY_CELLS.has(cellKey)) {
                return <div key={cellKey} />;
              }

              const character = charMap.get(cellKey);

              if (!character) {
                return <div key={cellKey} />;
              }

              const status = getCellStatus(character);

              return (
                <motion.button
                  key={cellKey}
                  role="gridcell"
                  aria-label={`${character.character} (${character.romaji})`}
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{
                    delay: (rowIdx * 5 + colIdx) * 0.015,
                    duration: 0.2,
                  }}
                  whileTap={{ scale: 0.9 }}
                  onClick={() => onCharacterClick(character)}
                  className={cn(
                    'font-jp flex min-h-[44px] min-w-[44px] items-center justify-center rounded-lg text-base font-medium transition-colors',
                    status === 'mastered' &&
                      'bg-primary/20 text-primary hover:bg-primary/30',
                    status === 'learned' &&
                      'bg-secondary text-foreground hover:bg-secondary/80',
                    status === 'locked' &&
                      'bg-muted text-muted-foreground opacity-40'
                  )}
                >
                  {character.character}
                </motion.button>
              );
            })}
          </Fragment>
        ))}
      </div>
    </div>
  );
}
