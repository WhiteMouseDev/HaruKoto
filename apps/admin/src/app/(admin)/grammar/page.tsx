'use client';

import { Suspense } from 'react';
import Link from 'next/link';
import { useTranslations } from 'next-intl';
import { useSearchParams } from 'next/navigation';
import { ContentTable, type Column } from '@/components/content/content-table';
import { FilterBar } from '@/components/content/filter-bar';
import { StatusBadge } from '@/components/ui/status-badge';
import { useContentList } from '@/hooks/use-content-list';
import type { GrammarItem } from '@/lib/api/admin-content';

function GrammarContent() {
  const t = useTranslations('table');
  const { data, isLoading, isError, error, refetch } =
    useContentList<GrammarItem>('grammar');
  const searchParams = useSearchParams();
  const currentPage = Number(searchParams.get('page') ?? '1');

  const columns: Column<GrammarItem>[] = [
    {
      key: 'pattern',
      header: 'パターン',
      width: '20%',
    },
    {
      key: 'explanation',
      header: '説明',
      width: '30%',
      render: (item) => (
        <span className="truncate text-muted-foreground">{item.explanation}</span>
      ),
    },
    {
      key: 'jlptLevel',
      header: 'JLPT',
      width: '8%',
      render: (item) => (
        <span className="text-xs">{item.jlptLevel}</span>
      ),
    },
    {
      key: 'reviewStatus',
      header: 'ステータス',
      width: '15%',
      render: (item) => (
        <StatusBadge
          status={item.reviewStatus as 'needs_review' | 'approved' | 'rejected'}
        />
      ),
    },
    {
      key: 'updatedAt',
      header: '更新日',
      width: '12%',
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
          href={`/grammar/${item.id}`}
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
        contentType="grammar"
      />
    </>
  );
}

export default function GrammarPage() {
  const t = useTranslations('page');

  return (
    <div>
      <h1 className="mb-6 text-xl font-semibold">{t('grammar')}</h1>
      <Suspense fallback={<div className="animate-pulse" />}>
        <GrammarContent />
      </Suspense>
    </div>
  );
}
