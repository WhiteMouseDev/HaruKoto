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
import { TtsPlayer } from '@/components/content/tts-player';
import { AuditTimeline } from '@/components/content/audit-timeline';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';

type ConversationDetail = {
  id: string;
  title: string;
  titleJa: string | null;
  description: string | null;
  situation: string | null;
  yourRole: string | null;
  aiRole: string | null;
  systemPrompt: string | null;
  keyExpressions: unknown[] | null;
  category: string;
  reviewStatus: 'needs_review' | 'approved' | 'rejected';
  createdAt: string;
  updatedAt: string | null;
};

const jsonArraySchema = z
  .string()
  .optional()
  .refine(
    (val) => {
      if (!val || val.trim() === '') return true;
      try {
        return Array.isArray(JSON.parse(val));
      } catch {
        return false;
      }
    },
    { message: '有効なJSON配列を入力してください' },
  );

const conversationSchema = z.object({
  title: z.string().min(1),
  titleJa: z.string().optional(),
  description: z.string().optional(),
  situation: z.string().optional(),
  yourRole: z.string().optional(),
  aiRole: z.string().optional(),
  systemPrompt: z.string().optional(),
  keyExpressions: jsonArraySchema,
});

type ConversationFormValues = z.infer<typeof conversationSchema>;

export default function ConversationDetailPage() {
  const { id } = useParams<{ id: string }>();
  const t = useTranslations('edit');
  const tReview = useTranslations('review');
  const [rejectDialogOpen, setRejectDialogOpen] = useState(false);

  const { detailQuery, patchMutation, reviewMutation, auditQuery } =
    useContentDetail<ConversationDetail>('conversation', id);

  const data = detailQuery.data;

  const {
    register,
    handleSubmit,
    formState: { dirtyFields },
    reset,
  } = useForm<ConversationFormValues>({
    resolver: zodResolver(conversationSchema),
    values: data
      ? {
          title: data.title,
          titleJa: data.titleJa ?? '',
          description: data.description ?? '',
          situation: data.situation ?? '',
          yourRole: data.yourRole ?? '',
          aiRole: data.aiRole ?? '',
          systemPrompt: data.systemPrompt ?? '',
          keyExpressions: data.keyExpressions
            ? JSON.stringify(data.keyExpressions, null, 2)
            : '',
        }
      : undefined,
  });

  function onSave(values: ConversationFormValues) {
    const changed: Record<string, unknown> = {};
    (Object.keys(dirtyFields) as (keyof ConversationFormValues)[]).forEach((key) => {
      if (key === 'keyExpressions') {
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
        {Array.from({ length: 6 }).map((_, i) => (
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
        href="/conversation"
        className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="size-4" />
        {t('backToList')}
      </Link>

      <h1 className="text-xl font-semibold">{t('title.conversation')}</h1>

      <ReviewHeader
        reviewStatus={data.reviewStatus}
        onApprove={handleApprove}
        onReject={() => setRejectDialogOpen(true)}
        isLoading={reviewMutation.isPending}
      />

      <TtsPlayer
        contentType="conversation"
        itemId={id}
        itemLabel={data.situation ?? data.titleJa ?? ''}
      />

      <form onSubmit={handleSubmit(onSave)} className="space-y-6">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <div className="space-y-1.5">
            <Label htmlFor="title">{t('field.title')}</Label>
            <Input id="title" {...register('title')} />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="titleJa">{t('field.titleJa')}</Label>
            <Input id="titleJa" {...register('titleJa')} />
          </div>

          <div className="space-y-1.5 md:col-span-2">
            <Label htmlFor="description">{t('field.description')}</Label>
            <Textarea id="description" rows={2} {...register('description')} />
          </div>

          <div className="space-y-1.5 md:col-span-2">
            <Label htmlFor="situation">{t('field.situation')}</Label>
            <Textarea id="situation" rows={3} {...register('situation')} />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="yourRole">{t('field.yourRole')}</Label>
            <Textarea id="yourRole" rows={2} {...register('yourRole')} />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="aiRole">{t('field.aiRole')}</Label>
            <Textarea id="aiRole" rows={2} {...register('aiRole')} />
          </div>

          <div className="space-y-1.5 md:col-span-2">
            <Label htmlFor="systemPrompt">{t('field.systemPrompt')}</Label>
            <Textarea id="systemPrompt" rows={6} {...register('systemPrompt')} />
          </div>

          <div className="space-y-1.5 md:col-span-2">
            <Label htmlFor="keyExpressions">{t('field.keyExpressions')}</Label>
            <Textarea
              id="keyExpressions"
              rows={4}
              placeholder='["表現1","表現2"]'
              {...register('keyExpressions')}
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
