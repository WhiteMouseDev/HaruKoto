'use client';

import { Suspense } from 'react';
import Link from 'next/link';
import { useTranslations } from 'next-intl';
import { useSearchParams } from 'next/navigation';
import { ContentTable, type Column } from '@/components/content/content-table';
import { FilterBar } from '@/components/content/filter-bar';
import { StatusBadge } from '@/components/ui/status-badge';
import { useContentList } from '@/hooks/use-content-list';
import type { ConversationItem } from '@/lib/api/admin-content';

// ScenarioCategory values from the API
const SCENARIO_CATEGORIES = [
  { value: 'TRAVEL', label: '旅行' },
  { value: 'SHOPPING', label: 'ショッピング' },
  { value: 'RESTAURANT', label: 'レストラン' },
  { value: 'BUSINESS', label: 'ビジネス' },
  { value: 'DAILY_LIFE', label: '日常生活' },
  { value: 'EMERGENCY', label: '緊急' },
  { value: 'TRANSPORTATION', label: '交通' },
  { value: 'HEALTHCARE', label: '医療' },
];

function ConversationContent() {
  const t = useTranslations('table');
  const { data, isLoading, isError, error, refetch } =
    useContentList<ConversationItem>('conversation');
  const searchParams = useSearchParams();
  const currentPage = Number(searchParams.get('page') ?? '1');

  const columns: Column<ConversationItem>[] = [
    {
      key: 'title',
      header: 'タイトル',
      width: '25%',
      render: (item) => (
        <span className="truncate">{item.title}</span>
      ),
    },
    {
      key: 'category',
      header: 'カテゴリ',
      width: '15%',
      render: (item) => {
        const cat = SCENARIO_CATEGORIES.find((c) => c.value === item.category);
        return (
          <span className="text-sm">
            {cat?.label ?? item.category}
          </span>
        );
      },
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
        <FilterBar showCategory categories={SCENARIO_CATEGORIES} />
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
      />
    </>
  );
}

export default function ConversationPage() {
  const t = useTranslations('page');

  return (
    <div>
      <h1 className="mb-6 text-xl font-semibold">{t('conversation')}</h1>
      <Suspense fallback={<div className="animate-pulse" />}>
        <ConversationContent />
      </Suspense>
    </div>
  );
}
