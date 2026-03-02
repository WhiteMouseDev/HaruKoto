'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import { X } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

type WordSource = 'QUIZ' | 'CONVERSATION' | 'MANUAL';

type WordbookEntryCardProps = {
  id: string;
  word: string;
  reading: string;
  meaningKo: string;
  source: WordSource;
  createdAt: string;
  onDelete: (id: string) => void;
};

const SOURCE_CONFIG: Record<WordSource, { label: string; className: string }> = {
  QUIZ: { label: '퀴즈', className: 'bg-hk-blue/10 text-hk-blue' },
  CONVERSATION: { label: '회화', className: 'bg-hk-success/10 text-hk-success' },
  MANUAL: { label: '직접추가', className: 'bg-secondary text-muted-foreground' },
};

export function WordbookEntryCard({
  id,
  word,
  reading,
  meaningKo,
  source,
  createdAt,
  onDelete,
}: WordbookEntryCardProps) {
  const [confirming, setConfirming] = useState(false);
  const sourceConfig = SOURCE_CONFIG[source];

  function handleDelete() {
    if (!confirming) {
      setConfirming(true);
      return;
    }
    onDelete(id);
  }

  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, x: -100 }}
      transition={{ duration: 0.2 }}
    >
      <Card>
        <CardContent className="flex items-center gap-3 px-4 py-3">
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <span className="font-jp text-lg font-bold truncate">{word}</span>
              <span className="font-jp text-muted-foreground text-sm shrink-0">
                {reading}
              </span>
            </div>
            <p className="text-sm text-muted-foreground truncate">{meaningKo}</p>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <Badge variant="ghost" className={sourceConfig.className}>
              {sourceConfig.label}
            </Badge>

            {confirming ? (
              <div className="flex items-center gap-1">
                <Button
                  variant="destructive"
                  size="sm"
                  className="h-7 px-2 text-xs"
                  onClick={handleDelete}
                >
                  삭제
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className="h-7 px-2 text-xs"
                  onClick={() => setConfirming(false)}
                >
                  취소
                </Button>
              </div>
            ) : (
              <button
                className="text-muted-foreground hover:text-foreground transition-colors p-1"
                onClick={handleDelete}
              >
                <X className="size-4" />
              </button>
            )}
          </div>
        </CardContent>
      </Card>
    </motion.div>
  );
}
