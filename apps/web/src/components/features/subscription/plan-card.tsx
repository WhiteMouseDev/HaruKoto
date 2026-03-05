'use client';

import { motion } from 'framer-motion';
import { Check, Crown } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import type { PricingPlan } from '@/types/subscription';

type PlanCardProps = {
  plan: PricingPlan;
  currentPlan?: string;
  onSelect: (plan: PricingPlan) => void;
  loading?: boolean;
};

function formatPrice(price: number): string {
  return new Intl.NumberFormat('ko-KR').format(price);
}

export function PlanCard({ plan, currentPlan, onSelect, loading }: PlanCardProps) {
  const isCurrent = currentPlan === plan.id;
  const isFree = plan.id === 'free';

  return (
    <motion.div
      initial={{ y: 10, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ delay: plan.recommended ? 0.1 : 0.2 }}
    >
      <Card
        className={`relative overflow-hidden ${
          plan.recommended
            ? 'border-primary ring-primary/20 ring-2'
            : 'border-border'
        }`}
      >
        {plan.recommended && (
          <div className="bg-primary text-primary-foreground absolute top-0 right-0 rounded-bl-lg px-3 py-1 text-xs font-bold">
            추천
          </div>
        )}

        <CardContent className="flex flex-col gap-4 p-5">
          <div className="flex items-center gap-2">
            {!isFree && <Crown className="text-hk-yellow size-5" />}
            <h3 className="text-lg font-bold">{plan.name}</h3>
          </div>

          <div className="flex items-baseline gap-1">
            {plan.originalPrice && (
              <span className="text-muted-foreground text-sm line-through">
                {formatPrice(plan.originalPrice)}원
              </span>
            )}
            <span className="text-3xl font-extrabold">
              {plan.price === 0 ? '무료' : `${formatPrice(plan.price)}원`}
            </span>
            {plan.period && (
              <span className="text-muted-foreground text-sm">/{plan.period}</span>
            )}
          </div>

          <ul className="flex flex-col gap-2">
            {plan.features.map((feature) => (
              <li key={feature} className="flex items-start gap-2 text-sm">
                <Check className="text-primary mt-0.5 size-4 shrink-0" />
                <span>{feature}</span>
              </li>
            ))}
          </ul>

          <Button
            className="mt-2 w-full"
            variant={plan.recommended ? 'default' : 'outline'}
            size="lg"
            onClick={() => onSelect(plan)}
            disabled={isCurrent || isFree || loading}
          >
            {isCurrent ? '현재 플랜' : isFree ? '현재 무료' : '구독하기'}
          </Button>
        </CardContent>
      </Card>
    </motion.div>
  );
}
