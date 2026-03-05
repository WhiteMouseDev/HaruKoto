import { NextResponse } from 'next/server';
import { prisma } from '@harukoto/database';
import { getPayment } from '@/lib/portone';
import { verifyWebhookSignature } from '@/lib/portone';
import { activateSubscription } from '@/lib/subscription-service';
import { PRICES } from '@/lib/subscription-constants';

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
    const { type, data } = body;

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

      // 기존 결제 레코드 확인
      const existingPayment = await prisma.payment.findUnique({
        where: { portonePaymentId: paymentId },
      });

      if (existingPayment?.status === 'PAID') {
        return NextResponse.json({ ok: true, message: 'Already processed' });
      }

      if (existingPayment && existingPayment.status === 'PENDING') {
        // 결제 금액으로 플랜 판별
        const plan = portonePayment.amount.total === PRICES.YEARLY ? 'yearly' as const : 'monthly' as const;

        await activateSubscription({
          userId: existingPayment.userId,
          plan,
          portonePaymentId: paymentId,
          amount: portonePayment.amount.total,
          billingKey: portonePayment.method?.billingKey,
        });
      }
    }

    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error('Webhook error:', err);
    return NextResponse.json({ error: 'Webhook processing failed' }, { status: 500 });
  }
}
