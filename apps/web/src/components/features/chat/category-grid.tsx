'use client';

import { type ReactNode } from 'react';
import { motion } from 'framer-motion';
import { Plane, Store, Briefcase, MessageSquare } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';

type Category = {
  id: string;
  icon: ReactNode;
  label: string;
  scenarioCount: string;
};

const CATEGORIES: Category[] = [
  {
    id: 'TRAVEL',
    icon: <Plane className="size-7" />,
    label: '여행',
    scenarioCount: '12 시나리오',
  },
  {
    id: 'DAILY',
    icon: <Store className="size-7" />,
    label: '일상',
    scenarioCount: '10 시나리오',
  },
  {
    id: 'BUSINESS',
    icon: <Briefcase className="size-7" />,
    label: '비즈니스',
    scenarioCount: '8 시나리오',
  },
  {
    id: 'FREE',
    icon: <MessageSquare className="size-7" />,
    label: '자유주제',
    scenarioCount: '무제한',
  },
];

type CategoryGridProps = {
  onSelect: (categoryId: string) => void;
};

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.06 },
  },
};

const item = {
  hidden: { opacity: 0, scale: 0.95 },
  show: { opacity: 1, scale: 1, transition: { duration: 0.25 } },
};

export function CategoryGrid({ onSelect }: CategoryGridProps) {
  return (
    <motion.div
      className="grid grid-cols-2 gap-3"
      variants={container}
      initial="hidden"
      animate="show"
    >
      {CATEGORIES.map((cat) => (
        <motion.div key={cat.id} variants={item}>
          <motion.div whileTap={{ scale: 0.97 }}>
            <Card
              className="cursor-pointer border-transparent py-4 transition-colors hover:border-primary/30"
              onClick={() => onSelect(cat.id)}
            >
              <CardContent className="flex flex-col items-center gap-1.5 p-3">
                <span className="text-primary">{cat.icon}</span>
                <span className="font-semibold">{cat.label}</span>
                <span className="text-muted-foreground text-xs">
                  {cat.scenarioCount}
                </span>
              </CardContent>
            </Card>
          </motion.div>
        </motion.div>
      ))}
    </motion.div>
  );
}
