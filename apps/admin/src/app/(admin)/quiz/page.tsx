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
import type { QuizItem } from '@/lib/api/admin-content';

function QuizContent() {
  const t = useTranslations('table');
  const { data, isLoading, isError, error, refetch } =
    useContentList<QuizItem>('quiz');
  const searchParams = useSearchParams();
  const currentPage = Number(searchParams.get('page') ?? '1');

  const columns: Column<QuizItem>[] = [
    {
      key: 'sentence',
      header: '問題文',
      width: '30%',
      render: (item) => (
        <span className="truncate">{item.sentence}</span>
      ),
    },
    {
      key: 'quizType',
      header: '種類',
      width: '12%',
      render: (item) => (
        <span className="text-xs text-muted-foreground">
          {item.quizType === 'cloze' ? 'cloze' : 'sentence-arrange'}
        </span>
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
      width: '13%',
      render: (item) => (
        <Link
          href={`/quiz/${item.id}`}
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
        contentType="quiz"
      />
    </>
  );
}

export default function QuizPage() {
  const t = useTranslations('page');

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-xl font-semibold">{t('quiz')}</h1>
        <Suspense fallback={null}>
          <ReviewStartButton contentType="quiz" />
        </Suspense>
      </div>
      <Suspense fallback={<div className="animate-pulse" />}>
        <QuizContent />
      </Suspense>
    </div>
  );
}
