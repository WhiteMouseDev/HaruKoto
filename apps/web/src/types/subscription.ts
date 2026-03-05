export type SubscriptionPlan = 'free' | 'monthly' | 'yearly';

export type SubscriptionStatusResponse = {
  subscription: {
    isPremium: boolean;
    plan: SubscriptionPlan;
    expiresAt: string | null;
    cancelledAt: string | null;
  };
  aiUsage: {
    chatCount: number;
    chatSeconds: number;
    callCount: number;
    callSeconds: number;
    chatLimit: number;
    callLimit: number;
    chatSecondsLimit: number;
    callSecondsLimit: number;
  };
};

export type CheckoutResponse = {
  paymentId: string;
  storeId: string;
  channelKey: string;
  orderName: string;
  totalAmount: number;
  currency: string;
  customerId: string;
  customerEmail: string;
};

export type PaymentRecord = {
  id: string;
  amount: number;
  currency: string;
  status: 'pending' | 'paid' | 'failed' | 'refunded' | 'cancelled';
  plan: SubscriptionPlan;
  paidAt: string | null;
  createdAt: string;
};

export type PricingPlan = {
  id: SubscriptionPlan;
  name: string;
  price: number;
  originalPrice?: number;
  period: string;
  features: string[];
  recommended?: boolean;
};
