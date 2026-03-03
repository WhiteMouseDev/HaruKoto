'use client';

import { useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft, RefreshCw, BookOpen, Search } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { useLearnedWords } from '@/hooks/use-learned-words';
import { LearnedWordCard } from '@/components/features/learned-words/learned-word-card';
import { useEffect, useRef } from 'react';

type SortOrder = 'recent' | 'alphabetical' | 'most-studied';
type MasteryFilter = 'ALL' | 'MASTERED' | 'LEARNING';

const FILTER_OPTIONS: { value: MasteryFilter; label: string }[] = [
  { value: 'ALL', label: '전체' },
  { value: 'MASTERED', label: '마스터' },
  { value: 'LEARNING', label: '학습중' },
];

export default function LearnedWordsPage() {
  const router = useRouter();
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [sort, setSort] = useState<SortOrder>('recent');
  const [filter, setFilter] = useState<MasteryFilter>('ALL');
  const [page, setPage] = useState(1);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      setDebouncedSearch(search);
      setPage(1);
    }, 300);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [search]);

  const {
    data,
    isLoading: loading,
    error: queryError,
    refetch,
  } = useLearnedWords({ page, sort, search: debouncedSearch, filter });

  const entries = data?.entries ?? [];
  const totalPages = data?.totalPages ?? 1;
  const summary = data?.summary;
  const error = queryError
    ? queryError instanceof Error
      ? queryError.message
      : '데이터를 불러올 수 없습니다.'
    : null;

  const handleSortChange = useCallback((v: string) => {
    setSort(v as SortOrder);
    setPage(1);
  }, []);

  const handleFilterChange = useCallback((f: MasteryFilter) => {
    setFilter(f);
    setPage(1);
  }, []);

  return (
    <div className="flex flex-col gap-5 p-4">
      {/* Header */}
      <div className="flex items-center gap-3 pt-2">
        <button onClick={() => router.push('/study')}>
          <ArrowLeft className="size-5" />
        </button>
        <h1 className="flex-1 text-2xl font-bold">내가 학습한 단어</h1>
      </div>

      {/* Summary */}
      {summary && (
        <div className="grid grid-cols-3 gap-2">
          <div className="bg-secondary flex flex-col items-center rounded-xl py-3">
            <span className="text-muted-foreground text-xs">전체</span>
            <span className="text-lg font-bold">{summary.totalLearned}</span>
          </div>
          <div className="bg-secondary flex flex-col items-center rounded-xl py-3">
            <span className="text-muted-foreground text-xs">마스터</span>
            <span className="text-primary text-lg font-bold">
              {summary.mastered}
            </span>
          </div>
          <div className="bg-secondary flex flex-col items-center rounded-xl py-3">
            <span className="text-muted-foreground text-xs">학습중</span>
            <span className="text-hk-blue text-lg font-bold">
              {summary.learning}
            </span>
          </div>
        </div>
      )}

      {/* Search */}
      <div className="relative">
        <Search className="text-muted-foreground absolute left-3 top-1/2 size-4 -translate-y-1/2" />
        <Input
          placeholder="단어 검색..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="pl-9"
        />
      </div>

      {/* Sort Tabs */}
      <Tabs value={sort} onValueChange={handleSortChange}>
        <TabsList className="w-full">
          <TabsTrigger value="recent" className="flex-1">
            최신순
          </TabsTrigger>
          <TabsTrigger value="alphabetical" className="flex-1">
            가나다순
          </TabsTrigger>
          <TabsTrigger value="most-studied" className="flex-1">
            많이 푼 순
          </TabsTrigger>
        </TabsList>
      </Tabs>

      {/* Mastery Filter */}
      <div className="flex gap-2">
        {FILTER_OPTIONS.map((option) => (
          <button
            key={option.value}
            className={`rounded-full border px-3 py-1 text-xs font-medium transition-all ${
              filter === option.value
                ? 'border-primary bg-primary/10 text-primary'
                : 'border-border text-muted-foreground'
            }`}
            onClick={() => handleFilterChange(option.value)}
          >
            {option.label}
          </button>
        ))}
      </div>

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
          <Button variant="outline" onClick={() => refetch()} className="gap-2">
            <RefreshCw className="size-4" />
            다시 시도
          </Button>
        </div>
      ) : entries.length === 0 ? (
        <div className="flex flex-col items-center justify-center gap-3 py-16">
          <BookOpen className="text-muted-foreground size-12" />
          <p className="text-muted-foreground text-center">
            {debouncedSearch || filter !== 'ALL'
              ? '검색 결과가 없어요'
              : '아직 학습한 단어가 없어요'}
          </p>
          {!debouncedSearch && filter === 'ALL' && (
            <Button
              variant="outline"
              className="gap-1.5 rounded-xl"
              onClick={() => router.push('/study')}
            >
              학습 시작하기
            </Button>
          )}
        </div>
      ) : (
        <>
          <div className="flex flex-col gap-2">
            {entries.map((entry) => (
              <LearnedWordCard key={entry.id} {...entry} />
            ))}
          </div>

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
    </div>
  );
}
