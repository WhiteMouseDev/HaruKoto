/**
 * PortOne V2 REST API 래퍼
 * @see https://developers.portone.io/api/rest-v2
 */

const PORTONE_API_BASE = 'https://api.portone.io';

function getHeaders() {
  const secret = process.env.PORTONE_V2_SECRET_KEY;
  if (!secret) throw new Error('PORTONE_V2_SECRET_KEY is not set');
  return {
    'Content-Type': 'application/json',
    Authorization: `PortOne ${secret}`,
  };
}

// 결제 정보 조회
export type PortOnePayment = {
  id: string;
  status: string;
  amount: { total: number; paid: number };
  method?: { type: string; billingKey?: string };
  customer?: { id: string; email: string };
  customData?: string;
};

export async function getPayment(paymentId: string): Promise<PortOnePayment> {
  const res = await fetch(`${PORTONE_API_BASE}/payments/${encodeURIComponent(paymentId)}`, {
    method: 'GET',
    headers: getHeaders(),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`PortOne getPayment failed: ${res.status} ${body}`);
  }
  return res.json();
}

// 빌링키 결제 (정기결제 갱신)
export async function payWithBillingKey(params: {
  paymentId: string;
  billingKey: string;
  orderName: string;
  amount: number;
  currency?: string;
  customerId: string;
}): Promise<PortOnePayment> {
  const res = await fetch(`${PORTONE_API_BASE}/payments/${encodeURIComponent(params.paymentId)}/billing-key`, {
    method: 'POST',
    headers: getHeaders(),
    body: JSON.stringify({
      billingKey: params.billingKey,
      orderName: params.orderName,
      amount: { total: params.amount },
      currency: params.currency ?? 'KRW',
      customer: { id: params.customerId },
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`PortOne billingKey payment failed: ${res.status} ${body}`);
  }
  return res.json();
}

// 결제 취소 (환불)
export async function cancelPayment(params: {
  paymentId: string;
  reason: string;
  amount?: number;
}): Promise<{ cancellation: { id: string; totalAmount: number } }> {
  const res = await fetch(`${PORTONE_API_BASE}/payments/${encodeURIComponent(params.paymentId)}/cancel`, {
    method: 'POST',
    headers: getHeaders(),
    body: JSON.stringify({
      reason: params.reason,
      amount: params.amount,
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`PortOne cancelPayment failed: ${res.status} ${body}`);
  }
  return res.json();
}

// 웹훅 시그니처 검증
export function verifyWebhookSignature(
  body: string,
  signature: string | null,
  secret: string
): boolean {
  if (!signature) return false;
  // PortOne V2 웹훅은 HMAC-SHA256 시그니처 사용
  // 실제 환경에서는 crypto.subtle 또는 node:crypto 사용
  try {
    const crypto = require('node:crypto');
    const expected = crypto
      .createHmac('sha256', secret)
      .update(body)
      .digest('hex');
    return crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expected)
    );
  } catch {
    return false;
  }
}
