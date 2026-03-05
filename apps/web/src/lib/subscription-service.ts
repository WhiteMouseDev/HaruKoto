import { prisma } from '@harukoto/database';
import { AI_LIMITS, getSubscriptionPeriodEnd } from './subscription-constants';

// 구독 상태 조회
export async function getSubscriptionStatus(userId: string) {
  const subscription = await prisma.subscription.findFirst({
    where: {
      userId,
      status: { in: ['ACTIVE', 'CANCELLED'] },
    },
    orderBy: { createdAt: 'desc' },
  });

  // 취소된 구독도 만료일 전이면 프리미엄 유지
  const isPremium =
    !!subscription &&
    subscription.plan !== 'FREE' &&
    (subscription.status === 'ACTIVE' || subscription.status === 'CANCELLED') &&
    subscription.currentPeriodEnd > new Date();

  return {
    isPremium,
    plan: subscription?.plan.toLowerCase() as 'free' | 'monthly' | 'yearly' ?? 'free',
    expiresAt: subscription?.currentPeriodEnd?.toISOString() ?? null,
    cancelledAt: subscription?.cancelledAt?.toISOString() ?? null,
    subscription,
  };
}

// AI 사용량 조회 (오늘)
export async function getDailyAiUsage(userId: string) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const usage = await prisma.dailyAiUsage.findUnique({
    where: {
      userId_date: { userId, date: today },
    },
  });

  return {
    chatCount: usage?.chatCount ?? 0,
    chatSeconds: usage?.chatSeconds ?? 0,
    callCount: usage?.callCount ?? 0,
    callSeconds: usage?.callSeconds ?? 0,
  };
}

// AI 사용 제한 체크
export async function checkAiLimit(
  userId: string,
  type: 'chat' | 'call'
): Promise<{ allowed: boolean; reason?: string }> {
  const { isPremium } = await getSubscriptionStatus(userId);
  const limits = isPremium ? AI_LIMITS.PREMIUM : AI_LIMITS.FREE;
  const usage = await getDailyAiUsage(userId);

  if (type === 'chat') {
    if (usage.chatCount >= limits.CHAT_COUNT) {
      return { allowed: false, reason: '오늘의 AI 채팅 횟수를 초과했습니다.' };
    }
    if (usage.chatSeconds >= limits.CHAT_SECONDS) {
      return { allowed: false, reason: '오늘의 AI 채팅 시간을 초과했습니다.' };
    }
  } else {
    if (usage.callCount >= limits.CALL_COUNT) {
      return { allowed: false, reason: '오늘의 AI 통화 횟수를 초과했습니다.' };
    }
    if (usage.callSeconds >= limits.CALL_SECONDS) {
      return { allowed: false, reason: '오늘의 AI 통화 시간을 초과했습니다.' };
    }
  }

  return { allowed: true };
}

// AI 사용량 기록
export async function trackAiUsage(
  userId: string,
  type: 'chat' | 'call',
  durationSeconds: number
) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const countField = type === 'chat' ? 'chatCount' : 'callCount';
  const secondsField = type === 'chat' ? 'chatSeconds' : 'callSeconds';

  await prisma.dailyAiUsage.upsert({
    where: {
      userId_date: { userId, date: today },
    },
    update: {
      [countField]: { increment: 1 },
      [secondsField]: { increment: durationSeconds },
    },
    create: {
      userId,
      date: today,
      [countField]: 1,
      [secondsField]: durationSeconds,
    },
  });
}

// 구독 활성화
export async function activateSubscription(params: {
  userId: string;
  plan: 'monthly' | 'yearly';
  portonePaymentId: string;
  amount: number;
  billingKey?: string;
}) {
  const now = new Date();
  const periodEnd = getSubscriptionPeriodEnd(params.plan, now);

  // 기존 활성 구독 만료 처리
  await prisma.subscription.updateMany({
    where: {
      userId: params.userId,
      status: 'ACTIVE',
    },
    data: {
      status: 'EXPIRED',
    },
  });

  // 새 구독 생성
  const subscription = await prisma.subscription.create({
    data: {
      userId: params.userId,
      plan: params.plan === 'monthly' ? 'MONTHLY' : 'YEARLY',
      status: 'ACTIVE',
      billingKey: params.billingKey,
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
    },
  });

  // 결제 기록 업데이트 (checkout에서 PENDING으로 이미 생성됨)
  await prisma.payment.updateMany({
    where: {
      portonePaymentId: params.portonePaymentId,
      userId: params.userId,
    },
    data: {
      subscriptionId: subscription.id,
      status: 'PAID',
      paidAt: now,
    },
  });

  // User isPremium 업데이트
  await prisma.user.update({
    where: { id: params.userId },
    data: {
      isPremium: true,
      subscriptionExpiresAt: periodEnd,
    },
  });

  return subscription;
}

// 구독 취소 (기간 만료 시 해지)
export async function cancelSubscription(userId: string, reason?: string) {
  const subscription = await prisma.subscription.findFirst({
    where: { userId, status: 'ACTIVE', plan: { not: 'FREE' } },
    orderBy: { createdAt: 'desc' },
  });

  if (!subscription) {
    throw new Error('활성 구독이 없습니다.');
  }

  await prisma.subscription.update({
    where: { id: subscription.id },
    data: {
      status: 'CANCELLED',
      cancelledAt: new Date(),
      cancelReason: reason,
    },
  });

  return subscription;
}

// 취소 철회
export async function resumeSubscription(userId: string) {
  const subscription = await prisma.subscription.findFirst({
    where: {
      userId,
      status: 'CANCELLED',
      currentPeriodEnd: { gt: new Date() },
    },
    orderBy: { createdAt: 'desc' },
  });

  if (!subscription) {
    throw new Error('취소된 구독이 없거나 이미 만료되었습니다.');
  }

  await prisma.subscription.update({
    where: { id: subscription.id },
    data: {
      status: 'ACTIVE',
      cancelledAt: null,
      cancelReason: null,
    },
  });

  return subscription;
}

// 결제 내역 조회
export async function getPaymentHistory(userId: string, page: number = 1, pageSize: number = 10) {
  const [payments, total] = await Promise.all([
    prisma.payment.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * pageSize,
      take: pageSize,
    }),
    prisma.payment.count({ where: { userId } }),
  ]);

  return {
    payments: payments.map((p) => ({
      id: p.id,
      amount: p.amount,
      currency: p.currency,
      status: p.status.toLowerCase() as 'pending' | 'paid' | 'failed' | 'refunded' | 'cancelled',
      plan: p.plan.toLowerCase() as 'free' | 'monthly' | 'yearly',
      paidAt: p.paidAt?.toISOString() ?? null,
      createdAt: p.createdAt.toISOString(),
    })),
    total,
    page,
    pageSize,
    totalPages: Math.ceil(total / pageSize),
  };
}
