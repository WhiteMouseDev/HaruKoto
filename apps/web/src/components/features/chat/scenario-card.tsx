'use client';

import { motion } from 'framer-motion';
import { Clock, ChevronRight } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';

type Scenario = {
  id: string;
  title: string;
  titleJa: string;
  description: string;
  category: string;
  difficulty: string;
  estimatedMinutes: number;
  keyExpressions: string[];
};

type ScenarioCardProps = {
  scenario: Scenario;
  onSelect: (scenario: Scenario) => void;
};

const DIFFICULTY_LABELS: Record<string, { label: string; color: string }> = {
  BEGINNER: { label: '초급', color: 'bg-hk-green/20 text-hk-green' },
  INTERMEDIATE: { label: '중급', color: 'bg-hk-yellow/20 text-hk-yellow' },
  ADVANCED: { label: '고급', color: 'bg-hk-red/20 text-hk-red' },
};

export function ScenarioCard({ scenario, onSelect }: ScenarioCardProps) {
  const diff = DIFFICULTY_LABELS[scenario.difficulty] ?? {
    label: scenario.difficulty,
    color: 'bg-secondary',
  };

  return (
    <motion.div whileTap={{ scale: 0.98 }}>
      <Card
        className="cursor-pointer border-transparent py-3 transition-colors hover:border-primary/30"
        onClick={() => onSelect(scenario)}
      >
        <CardContent className="flex items-center gap-3 p-3">
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <h4 className="truncate font-semibold">{scenario.title}</h4>
              <Badge
                variant="secondary"
                className={`shrink-0 text-[10px] ${diff.color}`}
              >
                {diff.label}
              </Badge>
            </div>
            <div className="text-muted-foreground mt-1 flex items-center gap-2 text-xs">
              <Clock className="size-3" />
              <span>예상 {scenario.estimatedMinutes}분</span>
            </div>
            {scenario.keyExpressions.length > 0 && (
              <p className="font-jp text-muted-foreground mt-1 truncate text-xs">
                핵심표현: {scenario.keyExpressions.slice(0, 2).join(', ')}
              </p>
            )}
          </div>
          <ChevronRight className="text-muted-foreground size-4 shrink-0" />
        </CardContent>
      </Card>
    </motion.div>
  );
}
