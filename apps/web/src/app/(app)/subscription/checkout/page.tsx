'use client';

import { useState, useCallback, useEffect, use } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft, Loader2, ShieldCheck } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { useQueryClient } from '@tanstack/react-query';
import { queryKeys } from '@/lib/query-keys';
import { PRICES } from '@/lib/subscription-constants';
import type { CheckoutResponse } from '@/types/subscription';

function formatPrice(price: number): string {
  return new Intl.NumberFormat('ko-KR').format(price);
}

export default function CheckoutPage(props: {
  searchParams: Promise<{
    plan?: string;
    // PortOne 리디렉션 콜백 파라미터
    paymentId?: string;
    code?: string;
    message?: string;
  }>;
}) {
  const searchParams = use(props.searchParams);
  const plan = (searchParams.plan === 'yearly' ? 'yearly' : 'monthly') as 'monthly' | 'yearly';
  const router = useRouter();
  const queryClient = useQueryClient();
  const [loading, setLoading] = useState(false);
  const [activating, setActivating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const amount = plan === 'yearly' ? PRICES.YEARLY : PRICES.MONTHLY;
  const planName = plan === 'yearly' ? '연간 프리미엄' : '월간 프리미엄';

  // PortOne 리디렉션 콜백 처리 (모바일 REDIRECTION 방식)
  useEffect(() => {
    const { paymentId, code, message } = searchParams;
    if (!paymentId) return;

    // 에러 코드가 있으면 결제 실패
    if (code != null && code !== '') {
      setError(message ?? '결제가 실패했습니다');
      return;
    }

    // 결제 성공 → 구독 활성화
    setActivating(true);
    fetch('/api/v1/subscription/activate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ paymentId, plan }),
    })
      .then(async (res) => {
        if (!res.ok) {
          const data = await res.json();
          throw new Error(data.error ?? '구독 활성화에 실패했습니다');
        }
        queryClient.invalidateQueries({ queryKey: queryKeys.subscription });
        router.replace('/subscription/success');
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : '구독 활성화에 실패했습니다');
        setActivating(false);
      });
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

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

      // 리디렉션 URL: 이 페이지로 다시 돌아옴 (paymentId 쿼리 파라미터 포함)
      const redirectUrl = `${window.location.origin}/subscription/checkout?plan=${plan}`;

      // Flutter WebView는 PC로 감지될 수 있으므로, 모바일 기기면 REDIRECTION 강제
      const isMobileDevice =
        /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent) ||
        window.innerWidth < 768;

      const response = await PortOne.requestPayment({
        storeId: checkout.storeId,
        channelKey: checkout.channelKey,
        paymentId: checkout.paymentId,
        orderName: checkout.orderName,
        totalAmount: checkout.totalAmount,
        currency: 'KRW',
        payMethod: 'CARD',
        windowType: isMobileDevice
          ? { pc: 'REDIRECTION', mobile: 'REDIRECTION' }
          : { pc: 'IFRAME', mobile: 'REDIRECTION' },
        redirectUrl,
        customer: {
          customerId: checkout.customerId,
          email: checkout.customerEmail,
          fullName: checkout.customerEmail.split('@')[0],
        },
      });

      // REDIRECTION 모드에서는 여기까지 오지 않음 (페이지가 리디렉트됨)
      // IFRAME 모드에서만 아래 코드가 실행됨

      if (!response) {
        throw new Error('결제 응답을 받지 못했습니다. 다시 시도해주세요.');
      }

      if (response.code != null) {
        throw new Error(response.message ?? `결제에 실패했습니다 (${response.code})`);
      }

      // 3. 결제 검증 + 구독 활성화 (IFRAME 모드)
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
      queryClient.invalidateQueries({ queryKey: queryKeys.subscription });
      router.push('/subscription/success');
    } catch (err) {
      setError(err instanceof Error ? err.message : '결제 중 오류가 발생했습니다');
      setLoading(false);
    }
  }, [plan, router, queryClient]);

  // 리디렉션 콜백 처리 중
  if (activating) {
    return (
      <div className="flex min-h-[40vh] flex-col items-center justify-center gap-4 p-4">
        <Loader2 className="text-primary size-8 animate-spin" />
        <p className="text-muted-foreground text-sm">결제를 확인하고 있습니다...</p>
      </div>
    );
  }

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
