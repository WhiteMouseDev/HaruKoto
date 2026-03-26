'use client';

import { useCallback, useEffect, useState } from 'react';
import { useRouter, usePathname, useSearchParams } from 'next/navigation';
import { useTranslations } from 'next-intl';
import { Input } from '@/components/ui/input';
import { cn } from '@/lib/utils';

type FilterBarProps = {
  showCategory?: boolean;
  categories?: { value: string; label: string }[];
};

const selectClass =
  'h-10 rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-xs outline-none transition-[color,box-shadow] focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50';

const JLPT_LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1'] as const;
const STATUS_OPTIONS = ['needs_review', 'approved', 'rejected'] as const;

export function FilterBar({ showCategory = false, categories = [] }: FilterBarProps) {
  const t = useTranslations('filter');
  const tStatus = useTranslations('status');
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const [searchValue, setSearchValue] = useState(
    searchParams.get('q') ?? ''
  );

  // Debounce search: 300ms
  useEffect(() => {
    const timer = setTimeout(() => {
      const params = new URLSearchParams(searchParams.toString());
      if (searchValue) {
        params.set('q', searchValue);
      } else {
        params.delete('q');
      }
      params.set('page', '1');
      router.replace(pathname + '?' + params.toString());
    }, 300);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchValue]);

  const handleFilterChange = useCallback(
    (key: string, value: string) => {
      const params = new URLSearchParams(searchParams.toString());
      if (value) {
        params.set(key, value);
      } else {
        params.delete(key);
      }
      params.set('page', '1');
      router.replace(pathname + '?' + params.toString());
    },
    [router, pathname, searchParams]
  );

  return (
    <div className="flex items-center gap-4">
      {/* Search input */}
      <Input
        type="search"
        placeholder={t('searchPlaceholder')}
        value={searchValue}
        onChange={(e) => setSearchValue(e.target.value)}
        className="h-10 max-w-xs flex-1"
      />

      {/* JLPT level */}
      <select
        aria-label={t('jlptLabel')}
        defaultValue={searchParams.get('jlpt') ?? ''}
        onChange={(e) => handleFilterChange('jlpt', e.target.value)}
        className={cn(selectClass, 'w-[120px]')}
      >
        <option value="">{t('jlptAll')}</option>
        {JLPT_LEVELS.map((level) => (
          <option key={level} value={level}>
            {level}
          </option>
        ))}
      </select>

      {/* Category — optional */}
      {showCategory && (
        <select
          aria-label={t('categoryLabel')}
          defaultValue={searchParams.get('category') ?? ''}
          onChange={(e) => handleFilterChange('category', e.target.value)}
          className={cn(selectClass, 'w-[160px]')}
        >
          <option value="">{t('categoryAll')}</option>
          {categories.map((cat) => (
            <option key={cat.value} value={cat.value}>
              {cat.label}
            </option>
          ))}
        </select>
      )}

      {/* Status */}
      <select
        aria-label={t('statusLabel')}
        defaultValue={searchParams.get('status') ?? ''}
        onChange={(e) => handleFilterChange('status', e.target.value)}
        className={cn(selectClass, 'w-[144px]')}
      >
        <option value="">{t('statusAll')}</option>
        {STATUS_OPTIONS.map((status) => (
          <option key={status} value={status}>
            {tStatus(
              status === 'needs_review'
                ? 'needsReview'
                : status === 'approved'
                  ? 'approved'
                  : 'rejected'
            )}
          </option>
        ))}
      </select>
    </div>
  );
}
