'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { ArrowLeft, Plus, RefreshCw, BookMarked } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import { Button } from '@/components/ui/button';
import { WordbookEntryCard } from '@/components/features/wordbook/wordbook-entry-card';
import { AddWordDialog } from '@/components/features/wordbook/add-word-dialog';
import {
  WordbookSearch,
  type SortOrder,
  type SourceFilter,
} from '@/components/features/wordbook/wordbook-search';

type WordbookEntry = {
  id: string;
  word: string;
  reading: string;
  meaningKo: string;
  source: 'QUIZ' | 'CONVERSATION' | 'MANUAL';
  note?: string;
  createdAt: string;
};

type WordbookResponse = {
  entries: WordbookEntry[];
  total: number;
  page: number;
  totalPages: number;
};

export default function WordbookPage() {
  const router = useRouter();
  const [entries, setEntries] = useState<WordbookEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [sort, setSort] = useState<SortOrder>('recent');
  const [filter, setFilter] = useState<SourceFilter>('ALL');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [dialogOpen, setDialogOpen] = useState(false);

  const fetchEntries = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({
        page: String(page),
        limit: '20',
        sort,
      });
      if (search) params.set('search', search);
      if (filter !== 'ALL') params.set('source', filter);

      const data = await apiFetch<WordbookResponse>(
        `/api/v1/wordbook?${params.toString()}`
      );
      setEntries(data.entries);
      setTotalPages(data.totalPages);
    } catch (err) {
      setError(
        err instanceof Error ? err.message : '단어장을 불러올 수 없습니다.'
      );
    } finally {
      setLoading(false);
    }
  }, [page, sort, search, filter]);

  useEffect(() => {
    fetchEntries();
  }, [fetchEntries]);

  // Reset page when filters change
  useEffect(() => {
    setPage(1);
  }, [search, sort, filter]);

  async function handleAdd(data: {
    word: string;
    reading: string;
    meaningKo: string;
    note?: string;
  }) {
    try {
      await apiFetch('/api/v1/wordbook', {
        method: 'POST',
        body: JSON.stringify(data),
      });
      fetchEntries();
    } catch (err) {
      console.error('Failed to add word:', err);
    }
  }

  async function handleDelete(id: string) {
    try {
      await apiFetch(`/api/v1/wordbook/${id}`, { method: 'DELETE' });
      setEntries((prev) => prev.filter((e) => e.id !== id));
    } catch (err) {
      console.error('Failed to delete word:', err);
    }
  }

  const handleSearchChange = useCallback((query: string) => {
    setSearch(query);
  }, []);

  return (
    <div className="flex flex-col gap-5 p-4">
      {/* Header */}
      <div className="flex items-center gap-3 pt-2">
        <button onClick={() => router.push('/study')}>
          <ArrowLeft className="size-5" />
        </button>
        <h1 className="flex-1 text-2xl font-bold">내 단어장</h1>
        <Button
          size="sm"
          className="gap-1.5 rounded-xl"
          onClick={() => setDialogOpen(true)}
        >
          <Plus className="size-4" />
          추가
        </Button>
      </div>

      {/* Search & Filter */}
      <WordbookSearch
        onSearchChange={handleSearchChange}
        onSortChange={setSort}
        onFilterChange={setFilter}
        sort={sort}
        filter={filter}
      />

      {/* Content */}
      {loading ? (
        <div className="flex flex-col gap-2">
          {[1, 2, 3, 4, 5].map((n) => (
            <div
              key={n}
              className="bg-secondary h-16 animate-pulse rounded-xl"
            />
          ))}
        </div>
      ) : error ? (
        <div className="flex flex-col items-center justify-center gap-4 py-12">
          <p className="text-muted-foreground text-center">{error}</p>
          <Button variant="outline" onClick={fetchEntries} className="gap-2">
            <RefreshCw className="size-4" />
            다시 시도
          </Button>
        </div>
      ) : entries.length === 0 ? (
        <div className="flex flex-col items-center justify-center gap-3 py-16">
          <BookMarked className="text-muted-foreground size-12" />
          <p className="text-muted-foreground text-center">
            {search || filter !== 'ALL'
              ? '검색 결과가 없어요'
              : '단어장이 비어있어요'}
          </p>
          {!search && filter === 'ALL' && (
            <Button
              variant="outline"
              className="gap-1.5 rounded-xl"
              onClick={() => setDialogOpen(true)}
            >
              <Plus className="size-4" />
              첫 단어 추가하기
            </Button>
          )}
        </div>
      ) : (
        <>
          <AnimatePresence mode="popLayout">
            {entries.map((entry) => (
              <WordbookEntryCard
                key={entry.id}
                id={entry.id}
                word={entry.word}
                reading={entry.reading}
                meaningKo={entry.meaningKo}
                source={entry.source}
                createdAt={entry.createdAt}
                onDelete={handleDelete}
              />
            ))}
          </AnimatePresence>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-2 pt-2">
              <Button
                variant="outline"
                size="sm"
                disabled={page <= 1}
                onClick={() => setPage((p) => p - 1)}
              >
                이전
              </Button>
              <span className="text-muted-foreground text-sm">
                {page} / {totalPages}
              </span>
              <Button
                variant="outline"
                size="sm"
                disabled={page >= totalPages}
                onClick={() => setPage((p) => p + 1)}
              >
                다음
              </Button>
            </div>
          )}
        </>
      )}

      {/* Add Word Dialog */}
      <AddWordDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        onAdd={handleAdd}
      />
    </div>
  );
}
