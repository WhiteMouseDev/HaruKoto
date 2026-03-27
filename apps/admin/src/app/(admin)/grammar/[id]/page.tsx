'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useTranslations } from 'next-intl';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { toast } from 'sonner';
import { ArrowLeft } from 'lucide-react';

import { useContentDetail } from '@/hooks/use-content-detail';
import { ReviewHeader } from '@/components/content/review-header';
import { RejectReasonDialog } from '@/components/content/reject-reason-dialog';
import { AuditTimeline } from '@/components/content/audit-timeline';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';

type GrammarDetail = {
  id: string;
  pattern: string;
  meaningKo: string;
  explanation: string | null;
  exampleSentences: unknown[] | null;
  jlptLevel: string;
  reviewStatus: 'needs_review' | 'approved' | 'rejected';
  createdAt: string;
  updatedAt: string | null;
};

const grammarSchema = z.object({
  pattern: z.string().min(1),
  meaningKo: z.string().min(1),
  explanation: z.string().optional(),
  exampleSentences: z
    .string()
    .optional()
    .refine(
      (val) => {
        if (!val || val.trim() === '') return true;
        try {
          const parsed = JSON.parse(val);
          return Array.isArray(parsed);
        } catch {
          return false;
        }
      },
      { message: '有効なJSON配列を入力してください' },
    ),
});

type GrammarFormValues = z.infer<typeof grammarSchema>;

export default function GrammarDetailPage() {
  const { id } = useParams<{ id: string }>();
  const t = useTranslations('edit');
  const tReview = useTranslations('review');
  const [rejectDialogOpen, setRejectDialogOpen] = useState(false);

  const { detailQuery, patchMutation, reviewMutation, auditQuery } =
    useContentDetail<GrammarDetail>('grammar', id);

  const data = detailQuery.data;

  const {
    register,
    handleSubmit,
    formState: { dirtyFields },
    reset,
  } = useForm<GrammarFormValues>({
    resolver: zodResolver(grammarSchema),
    values: data
      ? {
          pattern: data.pattern,
          meaningKo: data.meaningKo,
          explanation: data.explanation ?? '',
          exampleSentences: data.exampleSentences
            ? JSON.stringify(data.exampleSentences, null, 2)
            : '',
        }
      : undefined,
  });

  function onSave(values: GrammarFormValues) {
    const changed: Record<string, unknown> = {};
    (Object.keys(dirtyFields) as (keyof GrammarFormValues)[]).forEach((key) => {
      if (key === 'exampleSentences') {
        const val = values[key];
        changed[key] = val && val.trim() ? (JSON.parse(val) as unknown[]) : null;
      } else {
        changed[key] = values[key];
      }
    });

    if (Object.keys(changed).length === 0) {
      toast.info('変更がありません');
      return;
    }

    patchMutation.mutate(changed, {
      onSuccess: () => {
        toast.success(t('saveSuccess'));
        reset(values);
      },
      onError: () => {
        toast.error(t('saveError'));
      },
    });
  }

  function handleApprove() {
    reviewMutation.mutate(
      { action: 'approve' },
      { onSuccess: () => toast.success(tReview('approveSuccess')) },
    );
  }

  function handleRejectConfirm(reason: string) {
    reviewMutation.mutate(
      { action: 'reject', reason },
      {
        onSuccess: () => {
          setRejectDialogOpen(false);
          toast.success(tReview('rejectSuccess'));
        },
      },
    );
  }

  if (detailQuery.isLoading || !data) {
    return (
      <div className="mx-auto max-w-3xl space-y-4 p-6">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-10 animate-pulse rounded bg-muted" />
        ))}
      </div>
    );
  }

  if (detailQuery.isError) {
    return (
      <div className="p-6 text-sm text-destructive">
        データの読み込みに失敗しました
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl space-y-6 p-6">
      <Link
        href="/grammar"
        className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="size-4" />
        {t('backToList')}
      </Link>

      <h1 className="text-xl font-semibold">{t('title.grammar')}</h1>

      <ReviewHeader
        reviewStatus={data.reviewStatus}
        onApprove={handleApprove}
        onReject={() => setRejectDialogOpen(true)}
        isLoading={reviewMutation.isPending}
      />

      <form onSubmit={handleSubmit(onSave)} className="space-y-6">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <div className="space-y-1.5">
            <Label htmlFor="pattern">{t('field.pattern')}</Label>
            <Input id="pattern" {...register('pattern')} />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="meaningKo">{t('field.meaningKo')}</Label>
            <Input id="meaningKo" {...register('meaningKo')} />
          </div>

          <div className="space-y-1.5 md:col-span-2">
            <Label htmlFor="explanation">{t('field.explanation')}</Label>
            <Textarea id="explanation" rows={4} {...register('explanation')} />
          </div>

          <div className="space-y-1.5 md:col-span-2">
            <Label htmlFor="exampleSentences">{t('field.exampleSentences')}</Label>
            <Textarea
              id="exampleSentences"
              rows={6}
              placeholder='[{"ja": "例文", "ko": "예문"}]'
              {...register('exampleSentences')}
            />
          </div>
        </div>

        <Button type="submit" disabled={patchMutation.isPending} className="bg-primary">
          {t('save')}
        </Button>
      </form>

      <AuditTimeline
        entries={auditQuery.data}
        isLoading={auditQuery.isLoading}
      />

      <RejectReasonDialog
        open={rejectDialogOpen}
        onOpenChange={setRejectDialogOpen}
        onConfirm={handleRejectConfirm}
        isLoading={reviewMutation.isPending}
      />
    </div>
  );
}
