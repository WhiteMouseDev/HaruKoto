import { NextResponse } from 'next/server';
import { prisma } from '@harukoto/database';
import { payWithBillingKey } from '@/lib/portone';
import { PRICES, getSubscriptionPeriodEnd } from '@/lib/subscription-constants';

// Vercel Cron 또는 외부 크론에서 호출
// Authorization 헤더로 CRON_SECRET 검증
export async function POST(request: Request) {
  try {
    const authHeader = request.headers.get('authorization');
    const cronSecret = process.env.CRON_SECRET;

    if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // 만료된 활성 구독 중 billingKey가 있는 것 조회
    const expiredSubscriptions = await prisma.subscription.findMany({
      where: {
        status: 'ACTIVE',
        plan: { not: 'FREE' },
        billingKey: { not: null },
        currentPeriodEnd: { lte: new Date() },
      },
      include: {
        user: { select: { id: true, email: true } },
      },
      take: 50, // 배치 제한
    });

    const results: { id: string; success: boolean; error?: string }[] = [];

    for (const sub of expiredSubscriptions) {
      try {
        const plan = sub.plan === 'YEARLY' ? 'yearly' as const : 'monthly' as const;
        const amount = plan === 'yearly' ? PRICES.YEARLY : PRICES.MONTHLY;
        const paymentId = `harukoto_renewal_${sub.id}_${Date.now()}`;

        // 빌링키로 자동 결제
        await payWithBillingKey({
          paymentId,
          billingKey: sub.billingKey!,
          orderName: plan === 'yearly' ? '하루코토 연간 프리미엄 갱신' : '하루코토 월간 프리미엄 갱신',
          amount,
          customerId: sub.userId,
        });

        const newPeriodEnd = getSubscriptionPeriodEnd(plan, new Date());

        // 구독 갱신
        await prisma.$transaction([
          prisma.subscription.update({
            where: { id: sub.id },
            data: {
              currentPeriodStart: new Date(),
              currentPeriodEnd: newPeriodEnd,
            },
          }),
          prisma.payment.create({
            data: {
              userId: sub.userId,
              subscriptionId: sub.id,
              portonePaymentId: paymentId,
              amount,
              plan: sub.plan,
              status: 'PAID',
              paidAt: new Date(),
            },
          }),
          prisma.user.update({
            where: { id: sub.userId },
            data: { subscriptionExpiresAt: newPeriodEnd },
          }),
        ]);

        results.push({ id: sub.id, success: true });
      } catch (err) {
        console.error(`Renewal failed for subscription ${sub.id}:`, err);

        // 결제 실패 시 PAST_DUE로 변경
        await prisma.subscription.update({
          where: { id: sub.id },
          data: { status: 'PAST_DUE' },
        }).catch(() => {});

        results.push({
          id: sub.id,
          success: false,
          error: err instanceof Error ? err.message : 'Unknown error',
        });
      }
    }

    // 취소된 구독 중 만료된 것 처리
    await prisma.subscription.updateMany({
      where: {
        status: 'CANCELLED',
        currentPeriodEnd: { lte: new Date() },
      },
      data: { status: 'EXPIRED' },
    });

    // 만료된 구독의 User isPremium 해제
    const expiredUserIds = await prisma.subscription.findMany({
      where: {
        status: { in: ['EXPIRED', 'PAST_DUE'] },
        user: { isPremium: true },
      },
      select: { userId: true },
      distinct: ['userId'],
    });

    // 다른 활성 구독이 없는 유저만 isPremium 해제
    for (const { userId } of expiredUserIds) {
      const hasActive = await prisma.subscription.findFirst({
        where: { userId, status: 'ACTIVE', currentPeriodEnd: { gt: new Date() } },
      });
      if (!hasActive) {
        await prisma.user.update({
          where: { id: userId },
          data: { isPremium: false, subscriptionExpiresAt: null },
        });
      }
    }

    return NextResponse.json({
      processed: expiredSubscriptions.length,
      results,
    });
  } catch (err) {
    console.error('Cron renewal error:', err);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
