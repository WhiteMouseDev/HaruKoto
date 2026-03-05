'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft, CreditCard, ChevronLeft, ChevronRight } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { usePayments } from '@/hooks/use-payments';

function formatDate(iso: string | null): string {
  if (!iso) return '-';
  return new Date(iso).toLocaleDateString('ko-KR', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

function formatPrice(amount: number): string {
  return new Intl.NumberFormat('ko-KR').format(amount);
}

function statusLabel(status: string): { label: string; variant: 'default' | 'secondary' | 'destructive' | 'outline' } {
  switch (status) {
    case 'paid': return { label: '결제 완료', variant: 'default' };
    case 'pending': return { label: '대기 중', variant: 'secondary' };
    case 'failed': return { label: '실패', variant: 'destructive' };
    case 'refunded': return { label: '환불', variant: 'outline' };
    case 'cancelled': return { label: '취소', variant: 'outline' };
    default: return { label: status, variant: 'secondary' };
  }
}

function planLabel(plan: string): string {
  switch (plan) {
    case 'monthly': return '월간 프리미엄';
    case 'yearly': return '연간 프리미엄';
    default: return plan;
  }
}

export default function PaymentsPage() {
  const router = useRouter();
  const [page, setPage] = useState(1);
  const { data, isLoading } = usePayments(page);

  return (
    <div className="flex flex-col gap-4 p-4">
      {/* Header */}
      <div className="flex items-center gap-3">
        <button
          onClick={() => router.back()}
          className="hover:bg-accent -ml-1 rounded-lg p-1 transition-colors"
        >
          <ArrowLeft className="size-5" />
        </button>
        <h1 className="text-xl font-bold">결제 내역</h1>
      </div>

      {isLoading ? (
        <div className="flex flex-col gap-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="bg-muted h-20 animate-pulse rounded-xl" />
          ))}
        </div>
      ) : !data || data.payments.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center gap-3 py-12">
            <CreditCard className="text-muted-foreground size-10" />
            <p className="text-muted-foreground text-sm">결제 내역이 없습니다</p>
          </CardContent>
        </Card>
      ) : (
        <>
          <div className="flex flex-col gap-3">
            {data.payments.map((payment) => {
              const status = statusLabel(payment.status);
              return (
                <Card key={payment.id}>
                  <CardContent className="flex items-center justify-between p-4">
                    <div className="flex flex-col gap-1">
                      <span className="text-sm font-medium">
                        {planLabel(payment.plan)}
                      </span>
                      <span className="text-muted-foreground text-xs">
                        {formatDate(payment.paidAt ?? payment.createdAt)}
                      </span>
                    </div>
                    <div className="flex flex-col items-end gap-1">
                      <span className="text-sm font-bold">
                        {formatPrice(payment.amount)}원
                      </span>
                      <Badge variant={status.variant} className="text-[10px]">
                        {status.label}
                      </Badge>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>

          {/* Pagination */}
          {data.totalPages > 1 && (
            <div className="flex items-center justify-center gap-4">
              <Button
                variant="outline"
                size="icon"
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page <= 1}
              >
                <ChevronLeft className="size-4" />
              </Button>
              <span className="text-muted-foreground text-sm">
                {page} / {data.totalPages}
              </span>
              <Button
                variant="outline"
                size="icon"
                onClick={() => setPage((p) => Math.min(data.totalPages, p + 1))}
                disabled={page >= data.totalPages}
              >
                <ChevronRight className="size-4" />
              </Button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
