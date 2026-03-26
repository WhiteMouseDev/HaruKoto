'use client';

import { useRouter, usePathname, useSearchParams } from 'next/navigation';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { cn } from '@/lib/utils';

type PaginationBarProps = {
  currentPage: number;
  totalPages: number;
};

function getPageNumbers(currentPage: number, totalPages: number): (number | '...')[] {
  if (totalPages <= 7) {
    return Array.from({ length: totalPages }, (_, i) => i + 1);
  }

  const pages: (number | '...')[] = [];
  const neighbors = 2;
  const left = Math.max(2, currentPage - neighbors);
  const right = Math.min(totalPages - 1, currentPage + neighbors);

  pages.push(1);

  if (left > 2) {
    pages.push('...');
  }

  for (let i = left; i <= right; i++) {
    pages.push(i);
  }

  if (right < totalPages - 1) {
    pages.push('...');
  }

  pages.push(totalPages);

  return pages;
}

export function PaginationBar({ currentPage, totalPages }: PaginationBarProps) {
  const t = useTranslations('table');
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  if (totalPages <= 1) return null;

  const goToPage = (page: number) => {
    const params = new URLSearchParams(searchParams.toString());
    params.set('page', String(page));
    router.replace(pathname + '?' + params.toString());
  };

  const pages = getPageNumbers(currentPage, totalPages);

  return (
    <div className="mt-4 flex items-center justify-center gap-1">
      {/* Previous */}
      <button
        onClick={() => goToPage(currentPage - 1)}
        disabled={currentPage <= 1}
        aria-label={t('paginationPrev')}
        className={cn(
          'flex h-8 min-w-[32px] items-center justify-center rounded-md border border-border bg-card px-2 text-sm text-foreground transition-colors',
          'hover:bg-muted/50 disabled:cursor-not-allowed disabled:opacity-50'
        )}
      >
        <ChevronLeft className="size-4" />
        <span className="sr-only">{t('paginationPrev')}</span>
      </button>

      {/* Page numbers */}
      {pages.map((page, index) =>
        page === '...' ? (
          <span
            key={`ellipsis-${index}`}
            className="flex h-8 min-w-[32px] items-center justify-center text-sm text-muted-foreground"
          >
            …
          </span>
        ) : (
          <button
            key={page}
            onClick={() => goToPage(page)}
            aria-label={`Page ${page}`}
            aria-current={page === currentPage ? 'page' : undefined}
            className={cn(
              'flex h-8 min-w-[32px] items-center justify-center rounded-md border border-border text-sm transition-colors',
              page === currentPage
                ? 'bg-primary text-primary-foreground'
                : 'bg-card text-foreground hover:bg-muted/50'
            )}
          >
            {page}
          </button>
        )
      )}

      {/* Next */}
      <button
        onClick={() => goToPage(currentPage + 1)}
        disabled={currentPage >= totalPages}
        aria-label={t('paginationNext')}
        className={cn(
          'flex h-8 min-w-[32px] items-center justify-center rounded-md border border-border bg-card px-2 text-sm text-foreground transition-colors',
          'hover:bg-muted/50 disabled:cursor-not-allowed disabled:opacity-50'
        )}
      >
        <ChevronRight className="size-4" />
        <span className="sr-only">{t('paginationNext')}</span>
      </button>
    </div>
  );
}
