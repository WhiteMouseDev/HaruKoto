export type SubscriptionPlan = 'free' | 'monthly' | 'yearly';

export type SubscriptionStatus = {
  isPremium: boolean;
  plan: SubscriptionPlan;
  expiresAt: string | null;
  trialEndsAt: string | null;
  cancelledAt: string | null;
};
