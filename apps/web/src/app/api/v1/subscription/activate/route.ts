import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getPayment } from '@/lib/portone';
import { activateSubscription } from '@/lib/subscription-service';
import { PRICES } from '@/lib/subscription-constants';
import { z } from 'zod';

const activateSchema = z.object({
  paymentId: z.string().min(1),
  plan: z.enum(['monthly', 'yearly']),
});

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const body = await request.json();
    const parsed = activateSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json({ error: '잘못된 요청입니다' }, { status: 400 });
    }

    const { paymentId, plan } = parsed.data;
    const expectedAmount = plan === 'monthly' ? PRICES.MONTHLY : PRICES.YEARLY;

    // 포트원에서 결제 정보 검증
    const portonePayment = await getPayment(paymentId);

    if (portonePayment.status !== 'PAID') {
      return NextResponse.json(
        { error: '결제가 완료되지 않았습니다', portoneStatus: portonePayment.status },
        { status: 400 }
      );
    }

    if (portonePayment.amount.total !== expectedAmount) {
      return NextResponse.json(
        { error: '결제 금액이 일치하지 않습니다' },
        { status: 400 }
      );
    }

    // 구독 활성화
    const subscription = await activateSubscription({
      userId: user.id,
      plan,
      portonePaymentId: paymentId,
      amount: expectedAmount,
      billingKey: portonePayment.method?.billingKey,
    });

    return NextResponse.json({
      success: true,
      subscription: {
        id: subscription.id,
        plan: subscription.plan,
        currentPeriodEnd: subscription.currentPeriodEnd.toISOString(),
      },
    });
  } catch (err) {
    console.error('Activate error:', err);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
