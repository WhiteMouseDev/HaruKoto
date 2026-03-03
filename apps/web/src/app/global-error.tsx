'use client';

import * as Sentry from '@sentry/nextjs';
import { useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { RefreshCw } from 'lucide-react';

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    Sentry.captureException(error);
  }, [error]);

  return (
    <html lang="ko">
      <body>
        <div className="flex min-h-[50dvh] flex-col items-center justify-center gap-4 p-6 text-center">
          <span className="text-4xl">🦊</span>
          <h2 className="text-lg font-semibold">문제가 발생했습니다</h2>
          <p className="text-muted-foreground max-w-sm text-sm">
            예상치 못한 오류가 발생했습니다. 다시 시도해주세요.
          </p>
          <Button variant="outline" onClick={reset} className="gap-1.5">
            <RefreshCw className="size-4" />
            새로고침
          </Button>
        </div>
      </body>
    </html>
  );
}
