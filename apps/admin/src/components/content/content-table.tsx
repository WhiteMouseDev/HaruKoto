'use client';

import { useTranslations } from 'next-intl';
import { Search, Database } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { PaginationBar } from '@/components/ui/pagination-bar';

export type Column<T> = {
  key: string;
  header: string;
  width: string;
  render?: (item: T) => React.ReactNode;
};

type ContentTableProps<T> = {
  columns: Column<T>[];
  data: T[] | undefined;
  isLoading: boolean;
  isError: boolean;
  error: Error | null;
  currentPage: number;
  totalPages: number;
  onRetry?: () => void;
};

export function ContentTable<T extends { id: string }>({
  columns,
  data,
  isLoading,
  isError,
  error,
  currentPage,
  totalPages,
  onRetry,
}: ContentTableProps<T>) {
  const tEmpty = useTranslations('empty');
  const tError = useTranslations('error');

  return (
    <div>
      <div className="rounded-lg border border-border bg-card">
        <Table>
          <TableHeader>
            <TableRow className="bg-muted/50 hover:bg-muted/50">
              {columns.map((col) => (
                <TableHead
                  key={col.key}
                  style={{ width: col.width }}
                  className="text-xs uppercase tracking-wide text-muted-foreground"
                >
                  {col.header}
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              // Skeleton rows
              Array.from({ length: 10 }).map((_, i) => (
                <TableRow key={`skeleton-${i}`} className="h-12">
                  {columns.map((col) => (
                    <TableCell key={col.key}>
                      <span className="block h-4 animate-pulse rounded bg-muted" />
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : isError ? (
              // Error state
              <TableRow>
                <TableCell
                  colSpan={columns.length}
                  className="py-16 text-center"
                >
                  <div className="flex flex-col items-center gap-4">
                    <p className="text-sm text-muted-foreground">
                      {error?.message || tError('failedToLoad')}
                    </p>
                    {onRetry && (
                      <Button variant="outline" size="sm" onClick={onRetry}>
                        {tError('retry')}
                      </Button>
                    )}
                  </div>
                </TableCell>
              </TableRow>
            ) : !data || data.length === 0 ? (
              // Empty state
              <TableRow>
                <TableCell
                  colSpan={columns.length}
                  className="py-16 text-center"
                >
                  <div className="flex flex-col items-center gap-3">
                    <Search className="size-12 text-muted-foreground" />
                    <h3 className="text-lg font-semibold">
                      {tEmpty('heading')}
                    </h3>
                    <p className="text-sm text-muted-foreground">
                      {tEmpty('noResults')}
                    </p>
                  </div>
                </TableCell>
              </TableRow>
            ) : (
              // Data rows
              data.map((item) => (
                <TableRow key={item.id} className="h-12 hover:bg-muted/30">
                  {columns.map((col) => (
                    <TableCell key={col.key} className="truncate">
                      {col.render
                        ? col.render(item)
                        : String((item as Record<string, unknown>)[col.key] ?? '')}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      {!isLoading && !isError && totalPages > 1 && (
        <PaginationBar currentPage={currentPage} totalPages={totalPages} />
      )}
    </div>
  );
}

// Re-export Database icon for use in empty states with no data at all
export { Database };
