import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getSubscriptionStatus, getDailyAiUsage } from '@/lib/subscription-service';
import { AI_LIMITS } from '@/lib/subscription-constants';

export async function GET() {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const [status, usage] = await Promise.all([
      getSubscriptionStatus(user.id),
      getDailyAiUsage(user.id),
    ]);

    const limits = status.isPremium ? AI_LIMITS.PREMIUM : AI_LIMITS.FREE;

    return NextResponse.json({
      subscription: {
        isPremium: status.isPremium,
        plan: status.plan,
        expiresAt: status.expiresAt,
        cancelledAt: status.cancelledAt,
      },
      aiUsage: {
        ...usage,
        chatLimit: limits.CHAT_COUNT,
        callLimit: limits.CALL_COUNT,
        chatSecondsLimit: limits.CHAT_SECONDS,
        callSecondsLimit: limits.CALL_SECONDS,
      },
    });
  } catch (err) {
    console.error('Subscription status error:', err);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
