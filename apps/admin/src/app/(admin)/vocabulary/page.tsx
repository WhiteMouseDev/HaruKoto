'use client';

import { Suspense } from 'react';
import Link from 'next/link';
import { useTranslations } from 'next-intl';
import { useSearchParams } from 'next/navigation';
import { ContentTable, type Column } from '@/components/content/content-table';
import { FilterBar } from '@/components/content/filter-bar';
import { ReviewStartButton } from '@/components/content/review-start-button';
import { StatusBadge } from '@/components/ui/status-badge';
import { useContentList } from '@/hooks/use-content-list';
import type { VocabularyItem } from '@/lib/api/admin-content';

function VocabularyContent() {
  const t = useTranslations('table');
  const { data, isLoading, isError, error, refetch } =
    useContentList<VocabularyItem>('vocabulary');
  const searchParams = useSearchParams();
  const currentPage = Number(searchParams.get('page') ?? '1');

  const columns: Column<VocabularyItem>[] = [
    {
      key: 'word',
      header: t('col.word'),
      width: '15%',
    },
    {
      key: 'reading',
      header: t('col.reading'),
      width: '15%',
    },
    {
      key: 'meaningKo',
      header: t('col.meaningKo'),
      width: '25%',
      render: (item) => (
        <span className="text-muted-foreground">{item.meaningKo}</span>
      ),
    },
    {
      key: 'jlptLevel',
      header: 'JLPT',
      width: '8%',
      sortKey: 'jlpt_level',
      render: (item) => (
        <span className="text-xs">{item.jlptLevel}</span>
      ),
    },
    {
      key: 'reviewStatus',
      header: t('col.status'),
      width: '15%',
      sortKey: 'review_status',
      render: (item) => (
        <StatusBadge
          status={item.reviewStatus as 'needs_review' | 'approved' | 'rejected'}
        />
      ),
    },
    {
      key: 'createdAt',
      header: t('col.createdAt'),
      width: '12%',
      sortKey: 'created_at',
      render: (item) => (
        <span className="text-xs text-muted-foreground">
          {new Date(item.createdAt).toLocaleDateString('ja-JP')}
        </span>
      ),
    },
    {
      key: 'actions',
      header: '',
      width: '10%',
      render: (item) => (
        <Link
          href={`/vocabulary/${item.id}`}
          className="text-xs text-muted-foreground underline-offset-4 hover:underline"
        >
          {t('detailLink')}
        </Link>
      ),
    },
  ];

  return (
    <>
      <div className="mb-4">
        <FilterBar />
      </div>
      <ContentTable
        columns={columns}
        data={data?.items}
        isLoading={isLoading}
        isError={isError}
        error={error}
        currentPage={currentPage}
        totalPages={data?.totalPages ?? 1}
        onRetry={() => void refetch()}
        selectable
        contentType="vocabulary"
      />
    </>
  );
}

export default function VocabularyPage() {
  const t = useTranslations('page');

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-xl font-semibold">{t('vocabulary')}</h1>
        <Suspense fallback={null}>
          <ReviewStartButton contentType="vocabulary" />
        </Suspense>
      </div>
      <Suspense fallback={<div className="animate-pulse" />}>
        <VocabularyContent />
      </Suspense>
    </div>
  );
}
