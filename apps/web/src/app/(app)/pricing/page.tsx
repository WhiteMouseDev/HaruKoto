'use client';

import { useRouter } from 'next/navigation';
import { ArrowLeft } from 'lucide-react';
import { PlanCard } from '@/components/features/subscription/plan-card';
import { FeatureComparison } from '@/components/features/subscription/feature-comparison';
import { useSubscription } from '@/hooks/use-subscription';
import { PRICING_PLANS } from '@/lib/subscription-constants';
import type { PricingPlan } from '@/types/subscription';

export default function PricingPage() {
  const router = useRouter();
  const { data } = useSubscription();

  const handleSelect = (plan: PricingPlan) => {
    if (plan.id === 'free') return;
    router.push(`/subscription/checkout?plan=${plan.id}`);
  };

  return (
    <div className="flex flex-col gap-6 p-4 pb-24">
      {/* Header */}
      <div className="flex items-center gap-3">
        <button
          onClick={() => router.back()}
          className="hover:bg-accent -ml-1 rounded-lg p-1 transition-colors"
        >
          <ArrowLeft className="size-5" />
        </button>
        <h1 className="text-xl font-bold">프리미엄 플랜</h1>
      </div>

      {/* Plan Cards */}
      <div className="flex flex-col gap-4">
        {PRICING_PLANS.map((plan) => (
          <PlanCard
            key={plan.id}
            plan={plan}
            currentPlan={data?.subscription.plan}
            onSelect={handleSelect}
          />
        ))}
      </div>

      {/* Feature Comparison */}
      <div className="flex flex-col gap-2">
        <h2 className="px-1 text-sm font-bold">기능 비교</h2>
        <FeatureComparison />
      </div>

      {/* Footer note */}
      <p className="text-muted-foreground text-center text-xs">
        구독은 언제든 취소할 수 있으며, 현재 결제 기간이 끝날 때까지 프리미엄 기능을 이용할 수 있습니다.
      </p>
    </div>
  );
}
