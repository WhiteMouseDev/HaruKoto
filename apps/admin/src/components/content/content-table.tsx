'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { Search, Database } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { RejectReasonDialog } from '@/components/content/reject-reason-dialog';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { PaginationBar } from '@/components/ui/pagination-bar';
import { useBulkReview } from '@/hooks/use-bulk-review';

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
  selectable?: boolean;
  contentType?: string;
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
  selectable = false,
  contentType = '',
}: ContentTableProps<T>) {
  const tEmpty = useTranslations('empty');
  const tError = useTranslations('error');
  const tReview = useTranslations('review');

  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [rejectDialogOpen, setRejectDialogOpen] = useState(false);

  const bulkReview = useBulkReview(contentType);

  const visibleColumns = selectable
    ? [{ key: '__checkbox', header: '', width: '40px' } as Column<T>, ...columns]
    : columns;

  const allIds = data?.map((item) => item.id) ?? [];
  const allSelected = allIds.length > 0 && allIds.every((id) => selectedIds.has(id));
  const someSelected = allIds.some((id) => selectedIds.has(id)) && !allSelected;

  function toggleAll() {
    if (allSelected) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(allIds));
    }
  }

  function toggleOne(id: string) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  }

  function handleBulkApprove() {
    bulkReview.mutate(
      { ids: Array.from(selectedIds), action: 'approve' },
      { onSuccess: () => setSelectedIds(new Set()) },
    );
  }

  function handleBulkReject(reason: string) {
    bulkReview.mutate(
      { ids: Array.from(selectedIds), action: 'reject', reason },
      {
        onSuccess: () => {
          setSelectedIds(new Set());
          setRejectDialogOpen(false);
        },
      },
    );
  }

  const selectedCount = selectedIds.size;

  return (
    <div>
      {/* Bulk action toolbar */}
      {selectable && selectedCount > 0 && (
        <div className="mb-3 flex items-center justify-between rounded-lg border border-border bg-muted/50 px-4 py-2">
          <span className="text-sm text-muted-foreground">
            {tReview('bulkSelected', { count: selectedCount })}
          </span>
          <div className="flex items-center gap-2">
            <Button
              variant="default"
              size="sm"
              onClick={handleBulkApprove}
              disabled={bulkReview.isPending}
              className="bg-green-600 text-white hover:bg-green-700"
            >
              {tReview('bulkApprove')}
            </Button>
            <Button
              variant="destructive"
              size="sm"
              onClick={() => setRejectDialogOpen(true)}
              disabled={bulkReview.isPending}
            >
              {tReview('bulkReject')}
            </Button>
          </div>
        </div>
      )}

      <div className="rounded-lg border border-border bg-card">
        <Table>
          <TableHeader>
            <TableRow className="bg-muted/50 hover:bg-muted/50">
              {visibleColumns.map((col) =>
                col.key === '__checkbox' ? (
                  <TableHead key="__checkbox" style={{ width: col.width }}>
                    {selectable && (
                      <Checkbox
                        checked={allSelected ? true : someSelected ? 'indeterminate' : false}
                        onCheckedChange={toggleAll}
                        aria-label="全て選択"
                      />
                    )}
                  </TableHead>
                ) : (
                  <TableHead
                    key={col.key}
                    style={{ width: col.width }}
                    className="text-xs uppercase tracking-wide text-muted-foreground"
                  >
                    {col.header}
                  </TableHead>
                )
              )}
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              // Skeleton rows
              Array.from({ length: 10 }).map((_, i) => (
                <TableRow key={`skeleton-${i}`} className="h-12">
                  {visibleColumns.map((col) => (
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
                  colSpan={visibleColumns.length}
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
                  colSpan={visibleColumns.length}
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
                <TableRow
                  key={item.id}
                  className={`h-12 hover:bg-muted/30 ${selectable && selectedIds.has(item.id) ? 'bg-muted/20' : ''}`}
                >
                  {visibleColumns.map((col) =>
                    col.key === '__checkbox' ? (
                      <TableCell key="__checkbox">
                        <Checkbox
                          checked={selectedIds.has(item.id)}
                          onCheckedChange={() => toggleOne(item.id)}
                          aria-label={`行 ${item.id} を選択`}
                        />
                      </TableCell>
                    ) : (
                      <TableCell key={col.key} className="truncate">
                        {col.render
                          ? col.render(item)
                          : String((item as Record<string, unknown>)[col.key] ?? '')}
                      </TableCell>
                    )
                  )}
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      {!isLoading && !isError && totalPages > 1 && (
        <PaginationBar currentPage={currentPage} totalPages={totalPages} />
      )}

      {selectable && (
        <RejectReasonDialog
          open={rejectDialogOpen}
          onOpenChange={setRejectDialogOpen}
          onConfirm={handleBulkReject}
          isLoading={bulkReview.isPending}
        />
      )}
    </div>
  );
}

// Re-export Database icon for use in empty states with no data at all
export { Database };
