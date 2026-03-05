'use client';

import { useState, useCallback, use } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft, Loader2, ShieldCheck } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { PRICES } from '@/lib/subscription-constants';
import type { CheckoutResponse } from '@/types/subscription';

function formatPrice(price: number): string {
  return new Intl.NumberFormat('ko-KR').format(price);
}

export default function CheckoutPage(props: {
  searchParams: Promise<{ plan?: string }>;
}) {
  const searchParams = use(props.searchParams);
  const plan = (searchParams.plan === 'yearly' ? 'yearly' : 'monthly') as 'monthly' | 'yearly';
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const amount = plan === 'yearly' ? PRICES.YEARLY : PRICES.MONTHLY;
  const planName = plan === 'yearly' ? '연간 프리미엄' : '월간 프리미엄';

  const handlePayment = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      // 1. 서버에서 결제 파라미터 가져오기
      const checkoutRes = await fetch('/api/v1/subscription/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ plan }),
      });

      if (!checkoutRes.ok) {
        const data = await checkoutRes.json();
        throw new Error(data.error ?? '결제 준비에 실패했습니다');
      }

      const checkout: CheckoutResponse = await checkoutRes.json();

      // 2. PortOne SDK 로드 + 결제 요청
      const PortOne = await import('@portone/browser-sdk/v2');
      const response = await PortOne.requestPayment({
        storeId: checkout.storeId,
        channelKey: checkout.channelKey,
        paymentId: checkout.paymentId,
        orderName: checkout.orderName,
        totalAmount: checkout.totalAmount,
        currency: 'KRW',
        payMethod: 'CARD',
        windowType: { pc: 'IFRAME', mobile: 'REDIRECTION' },
        redirectUrl: `${window.location.origin}/subscription/success`,
        customer: {
          customerId: checkout.customerId,
          email: checkout.customerEmail,
        },
      });

      if (response?.code != null) {
        // 사용자 취소 또는 에러
        if (response.code === 'FAILURE_TYPE_PG') {
          throw new Error(response.message ?? '결제가 실패했습니다');
        }
        // 사용자가 결제창을 닫은 경우
        setLoading(false);
        return;
      }

      // 3. 결제 검증 + 구독 활성화
      const activateRes = await fetch('/api/v1/subscription/activate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          paymentId: checkout.paymentId,
          plan,
        }),
      });

      if (!activateRes.ok) {
        const data = await activateRes.json();
        throw new Error(data.error ?? '구독 활성화에 실패했습니다');
      }

      // 4. 성공 페이지로 이동
      router.push('/subscription/success');
    } catch (err) {
      setError(err instanceof Error ? err.message : '결제 중 오류가 발생했습니다');
      setLoading(false);
    }
  }, [plan, router]);

  return (
    <div className="flex flex-col gap-6 p-4">
      {/* Header */}
      <div className="flex items-center gap-3">
        <button
          onClick={() => router.back()}
          className="hover:bg-accent -ml-1 rounded-lg p-1 transition-colors"
        >
          <ArrowLeft className="size-5" />
        </button>
        <h1 className="text-xl font-bold">결제</h1>
      </div>

      {/* Order Summary */}
      <Card>
        <CardContent className="flex flex-col gap-4 p-5">
          <h2 className="text-lg font-bold">{planName}</h2>

          <div className="flex items-center justify-between">
            <span className="text-muted-foreground text-sm">결제 금액</span>
            <span className="text-2xl font-extrabold">{formatPrice(amount)}원</span>
          </div>

          {plan === 'yearly' && (
            <div className="bg-primary/10 text-primary rounded-lg px-3 py-2 text-center text-sm font-medium">
              월 {formatPrice(Math.round(PRICES.YEARLY / 12))}원 (32% 할인)
            </div>
          )}

          <div className="text-muted-foreground flex flex-col gap-1 text-xs">
            <span>
              {plan === 'monthly'
                ? '매월 자동 갱신되며, 언제든 취소할 수 있습니다.'
                : '매년 자동 갱신되며, 언제든 취소할 수 있습니다.'}
            </span>
          </div>
        </CardContent>
      </Card>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-600 dark:border-red-900 dark:bg-red-950 dark:text-red-400">
          {error}
        </div>
      )}

      {/* Pay Button */}
      <Button
        size="lg"
        className="w-full text-base"
        onClick={handlePayment}
        disabled={loading}
      >
        {loading ? (
          <>
            <Loader2 className="mr-2 size-4 animate-spin" />
            처리 중...
          </>
        ) : (
          `${formatPrice(amount)}원 결제하기`
        )}
      </Button>

      {/* Security note */}
      <div className="text-muted-foreground flex items-center justify-center gap-1 text-xs">
        <ShieldCheck className="size-3.5" />
        <span>안전한 결제 (포트원 인증)</span>
      </div>
    </div>
  );
}
