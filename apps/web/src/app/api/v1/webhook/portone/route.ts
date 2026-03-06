import { NextResponse } from 'next/server';
import { prisma } from '@harukoto/database';
import { getPayment } from '@/lib/portone';
import { verifyWebhookSignature } from '@/lib/portone';
import { activateSubscription } from '@/lib/subscription-service';
import { PRICES } from '@/lib/subscription-constants';

const WEBHOOK_TIMESTAMP_TOLERANCE_MS = 5 * 60 * 1000; // 5분

export async function POST(request: Request) {
  try {
    const bodyText = await request.text();
    const signature = request.headers.get('x-portone-signature');
    const webhookSecret = process.env.PORTONE_WEBHOOK_SECRET;

    // 시그니처 검증 (설정된 경우)
    if (webhookSecret && !verifyWebhookSignature(bodyText, signature, webhookSecret)) {
      return NextResponse.json({ error: 'Invalid signature' }, { status: 401 });
    }

    const body = JSON.parse(bodyText);
    const { type, data, timestamp } = body;

    // Replay Attack 방어: timestamp 검증
    if (timestamp) {
      const webhookTime = new Date(timestamp).getTime();
      if (Math.abs(Date.now() - webhookTime) > WEBHOOK_TIMESTAMP_TOLERANCE_MS) {
        return NextResponse.json({ error: 'Webhook timestamp expired' }, { status: 400 });
      }
    }

    if (type === 'Transaction.Paid') {
      const paymentId = data?.paymentId;
      if (!paymentId) {
        return NextResponse.json({ error: 'Missing paymentId' }, { status: 400 });
      }

      // 포트원에서 결제 정보 확인
      const portonePayment = await getPayment(paymentId);
      if (portonePayment.status !== 'PAID') {
        return NextResponse.json({ ok: true, message: 'Not paid yet' });
      }

      // 기존 결제 레코드 확인 (PENDING 상태만 조회하여 중복 처리 방지)
      const existingPayment = await prisma.payment.findUnique({
        where: { portonePaymentId: paymentId },
      });

      if (!existingPayment) {
        return NextResponse.json({ ok: true, message: 'No matching payment record' });
      }

      if (existingPayment.status !== 'PENDING') {
        return NextResponse.json({ ok: true, message: 'Already processed' });
      }

      // DB에 저장된 plan으로 결제 금액 검증 (Tampering 방어)
      const dbPlan = existingPayment.plan === 'MONTHLY' ? 'monthly' as const : 'yearly' as const;
      const expectedAmount = dbPlan === 'monthly' ? PRICES.MONTHLY : PRICES.YEARLY;

      if (portonePayment.amount.total !== expectedAmount) {
        console.error(
          `Payment amount mismatch: expected ${expectedAmount} for ${dbPlan}, got ${portonePayment.amount.total}`,
          { paymentId, userId: existingPayment.userId }
        );
        return NextResponse.json({ error: 'Amount mismatch' }, { status: 400 });
      }

      await activateSubscription({
        userId: existingPayment.userId,
        plan: dbPlan,
        portonePaymentId: paymentId,
        amount: expectedAmount,
        billingKey: portonePayment.method?.billingKey,
      });
    }

    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error('Webhook error:', err);
    return NextResponse.json({ error: 'Webhook processing failed' }, { status: 500 });
  }
}
