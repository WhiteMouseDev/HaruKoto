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
import type { ConversationItem } from '@/lib/api/admin-content';

function ConversationContent() {
  const t = useTranslations('table');
  const tCat = useTranslations('category');
  const { data, isLoading, isError, error, refetch } =
    useContentList<ConversationItem>('conversation');
  const searchParams = useSearchParams();
  const currentPage = Number(searchParams.get('page') ?? '1');

  // ScenarioCategory values from the API — labels via i18n
  const SCENARIO_CATEGORIES = [
    'TRAVEL', 'SHOPPING', 'RESTAURANT', 'BUSINESS',
    'DAILY_LIFE', 'EMERGENCY', 'TRANSPORTATION', 'HEALTHCARE',
  ].map((key) => ({ value: key, label: tCat(key) }));

  const columns: Column<ConversationItem>[] = [
    {
      key: 'title',
      header: t('col.title'),
      width: '25%',
      render: (item) => (
        <span className="truncate">{item.title}</span>
      ),
    },
    {
      key: 'category',
      header: t('col.category'),
      width: '15%',
      sortKey: 'category',
      render: (item) => (
        <span className="text-sm">
          {tCat(item.category)}
        </span>
      ),
    },
    {
      key: 'jlptLevel',
      header: 'JLPT',
      width: '8%',
      render: (item) => (
        <span className="text-xs">{item.jlptLevel ?? '—'}</span>
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
      key: 'updatedAt',
      header: t('col.updatedAt'),
      width: '12%',
      sortKey: 'created_at',
      render: (item) => (
        <span className="text-xs text-muted-foreground">
          {new Date(item.updatedAt || item.createdAt).toLocaleDateString('ja-JP')}
        </span>
      ),
    },
    {
      key: 'actions',
      header: '',
      width: '15%',
      render: (item) => (
        <Link
          href={`/conversation/${item.id}`}
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
        <FilterBar showCategory categories={SCENARIO_CATEGORIES} showJlpt={false} />
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
        contentType="conversation"
      />
    </>
  );
}

export default function ConversationPage() {
  const t = useTranslations('page');

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-xl font-semibold">{t('conversation')}</h1>
        <Suspense fallback={null}>
          <ReviewStartButton contentType="conversation" />
        </Suspense>
      </div>
      <Suspense fallback={<div className="animate-pulse" />}>
        <ConversationContent />
      </Suspense>
    </div>
  );
}
