'use client';

import { useState, useEffect, useRef } from 'react';
import { Search } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';

type SortOrder = 'recent' | 'alphabetical';
type SourceFilter = 'ALL' | 'QUIZ' | 'CONVERSATION' | 'MANUAL';

type WordbookSearchProps = {
  onSearchChange: (query: string) => void;
  onSortChange: (sort: SortOrder) => void;
  onFilterChange: (filter: SourceFilter) => void;
  sort: SortOrder;
  filter: SourceFilter;
};

const FILTER_OPTIONS: { value: SourceFilter; label: string }[] = [
  { value: 'ALL', label: '전체' },
  { value: 'QUIZ', label: '퀴즈' },
  { value: 'CONVERSATION', label: '회화' },
  { value: 'MANUAL', label: '직접추가' },
];

export function WordbookSearch({
  onSearchChange,
  onSortChange,
  onFilterChange,
  sort,
  filter,
}: WordbookSearchProps) {
  const [query, setQuery] = useState('');
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      onSearchChange(query);
    }, 300);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query, onSearchChange]);

  return (
    <div className="flex flex-col gap-3">
      {/* Search Input */}
      <div className="relative">
        <Search className="text-muted-foreground absolute left-3 top-1/2 size-4 -translate-y-1/2" />
        <Input
          placeholder="단어 검색..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          className="pl-9"
        />
      </div>

      {/* Sort Tabs */}
      <Tabs value={sort} onValueChange={(v) => onSortChange(v as SortOrder)}>
        <TabsList className="w-full">
          <TabsTrigger value="recent" className="flex-1">
            최신순
          </TabsTrigger>
          <TabsTrigger value="alphabetical" className="flex-1">
            가나다순
          </TabsTrigger>
        </TabsList>
      </Tabs>

      {/* Source Filter */}
      <div className="flex gap-2">
        {FILTER_OPTIONS.map((option) => (
          <button
            key={option.value}
            className={`rounded-full border px-3 py-1 text-xs font-medium transition-all ${
              filter === option.value
                ? 'border-primary bg-primary/10 text-primary'
                : 'border-border text-muted-foreground'
            }`}
            onClick={() => onFilterChange(option.value)}
          >
            {option.label}
          </button>
        ))}
      </div>
    </div>
  );
}

export type { SortOrder, SourceFilter };
