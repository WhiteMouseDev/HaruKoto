import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { PRICES } from '@/lib/subscription-constants';
import { z } from 'zod';

const checkoutSchema = z.object({
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
    const parsed = checkoutSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json({ error: '잘못된 요청입니다' }, { status: 400 });
    }

    const { plan } = parsed.data;
    const amount = plan === 'monthly' ? PRICES.MONTHLY : PRICES.YEARLY;
    const orderName = plan === 'monthly' ? '하루코토 월간 프리미엄' : '하루코토 연간 프리미엄';

    const dbUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: { email: true, nickname: true },
    });

    const paymentId = `harukoto_${plan}_${user.id}_${Date.now()}`;

    const storeId = process.env.NEXT_PUBLIC_PORTONE_STORE_ID;
    const channelKey = process.env.PORTONE_CHANNEL_KEY;

    if (!storeId || !channelKey) {
      return NextResponse.json(
        { error: '결제 설정이 완료되지 않았습니다' },
        { status: 503 }
      );
    }

    // 결제 레코드 미리 생성 (PENDING)
    await prisma.payment.create({
      data: {
        userId: user.id,
        portonePaymentId: paymentId,
        amount,
        plan: plan === 'monthly' ? 'MONTHLY' : 'YEARLY',
        status: 'PENDING',
      },
    });

    return NextResponse.json({
      paymentId,
      storeId,
      channelKey,
      orderName,
      totalAmount: amount,
      currency: 'KRW',
      customerId: user.id,
      customerEmail: dbUser?.email ?? user.email,
    });
  } catch (err) {
    console.error('Checkout error:', err);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
