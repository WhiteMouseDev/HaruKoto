'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Crown, ChevronRight, CreditCard } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import {
  useSubscription,
  useCancelSubscription,
  useResumeSubscription,
} from '@/hooks/use-subscription';

function formatDate(iso: string | null): string {
  if (!iso) return '-';
  return new Date(iso).toLocaleDateString('ko-KR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
}

function planLabel(plan: string): string {
  switch (plan) {
    case 'monthly': return '월간 프리미엄';
    case 'yearly': return '연간 프리미엄';
    default: return '무료';
  }
}

export function SubscriptionSection() {
  const router = useRouter();
  const { data, isPending } = useSubscription();
  const cancelMutation = useCancelSubscription();
  const resumeMutation = useResumeSubscription();
  const [cancelDialogOpen, setCancelDialogOpen] = useState(false);

  // 캐시 없이 최초 로딩 중일 때만 스켈레톤
  const showSkeleton = isPending && !data;

  const sub = data?.subscription;
  const isPremium = sub?.isPremium ?? false;
  const isCancelled = !!sub?.cancelledAt;

  return (
    <>
      <div className="flex flex-col gap-1.5">
        <span className="text-muted-foreground px-1 text-xs font-medium">구독</span>
        <Card>
          {showSkeleton ? (
            <CardContent className="p-4">
              <div className="bg-muted h-16 animate-pulse rounded-lg" />
            </CardContent>
          ) : (
            <CardContent className="flex flex-col p-0">
              {/* Current Plan */}
              <div className="flex items-center justify-between px-4 py-3.5">
                <div className="flex items-center gap-3">
                  <Crown className={`size-5 ${isPremium ? 'text-hk-yellow' : 'text-muted-foreground'}`} />
                  <div className="flex flex-col">
                    <span className="text-sm font-medium">
                      {planLabel(sub?.plan ?? 'free')}
                    </span>
                    {isPremium && sub?.expiresAt && (
                      <span className="text-muted-foreground text-[11px]">
                        {isCancelled ? '만료 예정: ' : '다음 결제: '}
                        {formatDate(sub.expiresAt)}
                      </span>
                    )}
                    {isCancelled && (
                      <span className="text-amber-500 text-[11px]">
                        취소됨 - 만료일까지 이용 가능
                      </span>
                    )}
                  </div>
                </div>
                {!isPremium && (
                  <Button
                    size="sm"
                    onClick={() => router.push('/pricing')}
                  >
                    업그레이드
                  </Button>
                )}
              </div>

              {isPremium && (
                <>
                  <Separator />
                  {isCancelled ? (
                    <button
                      className="hover:bg-accent flex items-center justify-between px-4 py-3.5 text-left transition-colors"
                      onClick={() => resumeMutation.mutate()}
                      disabled={resumeMutation.isPending}
                    >
                      <span className="text-primary text-sm font-medium">
                        {resumeMutation.isPending ? '처리 중...' : '구독 재개'}
                      </span>
                      <ChevronRight className="text-muted-foreground size-4" />
                    </button>
                  ) : (
                    <button
                      className="hover:bg-accent flex items-center justify-between px-4 py-3.5 text-left transition-colors"
                      onClick={() => setCancelDialogOpen(true)}
                    >
                      <span className="text-muted-foreground text-sm font-medium">
                        구독 취소
                      </span>
                      <ChevronRight className="text-muted-foreground size-4" />
                    </button>
                  )}
                </>
              )}

              <Separator />

              {/* Payment History */}
              <button
                className="hover:bg-accent flex items-center justify-between px-4 py-3.5 text-left transition-colors"
                onClick={() => router.push('/my/payments')}
              >
                <div className="flex items-center gap-3">
                  <CreditCard className="text-muted-foreground size-5" />
                  <span className="text-sm font-medium">결제 내역</span>
                </div>
                <ChevronRight className="text-muted-foreground size-4" />
              </button>
            </CardContent>
          )}
        </Card>
      </div>

      {/* Cancel Dialog */}
      <Dialog open={cancelDialogOpen} onOpenChange={setCancelDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>구독을 취소하시겠습니까?</DialogTitle>
            <DialogDescription>
              구독을 취소하면 현재 결제 기간이 끝날 때까지 프리미엄 기능을 계속 이용할 수 있습니다.
              이후 무료 플랜으로 전환됩니다.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setCancelDialogOpen(false)}
              disabled={cancelMutation.isPending}
            >
              유지하기
            </Button>
            <Button
              variant="destructive"
              onClick={async () => {
                await cancelMutation.mutateAsync(undefined);
                setCancelDialogOpen(false);
              }}
              disabled={cancelMutation.isPending}
            >
              {cancelMutation.isPending ? '처리 중...' : '구독 취소'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
