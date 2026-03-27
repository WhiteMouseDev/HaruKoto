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
import { useReviewQueue } from '@/hooks/use-review-queue';
import { ReviewHeader } from '@/components/content/review-header';
import { QueueNavigationBar } from '@/components/content/queue-navigation-bar';
import { RejectReasonDialog } from '@/components/content/reject-reason-dialog';
import { TtsPlayer } from '@/components/content/tts-player';
import { AuditTimeline } from '@/components/content/audit-timeline';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';

type VocabularyDetail = {
  id: string;
  word: string;
  reading: string;
  meaningKo: string;
  jlptLevel: string;
  partOfSpeech: string | null;
  exampleSentence: string | null;
  exampleReading: string | null;
  exampleTranslation: string | null;
  reviewStatus: 'needs_review' | 'approved' | 'rejected';
  createdAt: string;
  updatedAt: string | null;
};

const vocabularySchema = z.object({
  word: z.string().min(1),
  reading: z.string().min(1),
  meaningKo: z.string().min(1),
  partOfSpeech: z.string().optional(),
  exampleSentence: z.string().optional(),
  exampleReading: z.string().optional(),
  exampleTranslation: z.string().optional(),
});

type VocabularyFormValues = z.infer<typeof vocabularySchema>;

export default function VocabularyDetailPage() {
  const { id } = useParams<{ id: string }>();
  const t = useTranslations('edit');
  const tReview = useTranslations('review');
  const [rejectDialogOpen, setRejectDialogOpen] = useState(false);

  const { detailQuery, patchMutation, reviewMutation, auditQuery } =
    useContentDetail<VocabularyDetail>('vocabulary', id);

  const {
    isInQueue,
    position,
    total,
    goNext,
    goPrev,
    hasPrev,
    hasNext,
    exitQueue,
    isLastItem,
  } = useReviewQueue('vocabulary');

  const data = detailQuery.data;

  const {
    register,
    handleSubmit,
    formState: { dirtyFields },
    reset,
  } = useForm<VocabularyFormValues>({
    resolver: zodResolver(vocabularySchema),
    values: data
      ? {
          word: data.word,
          reading: data.reading,
          meaningKo: data.meaningKo,
          partOfSpeech: data.partOfSpeech ?? '',
          exampleSentence: data.exampleSentence ?? '',
          exampleReading: data.exampleReading ?? '',
          exampleTranslation: data.exampleTranslation ?? '',
        }
      : undefined,
  });

  function onSave(values: VocabularyFormValues) {
    // Send only dirty fields
    const changed: Record<string, unknown> = {};
    (Object.keys(dirtyFields) as (keyof VocabularyFormValues)[]).forEach((key) => {
      changed[key] = values[key];
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
      {
        onSuccess: () => {
          toast.success(tReview('approveSuccess'));
          if (isInQueue) {
            if (isLastItem) {
              toast.info(tReview('queueComplete'));
              setTimeout(exitQueue, 800);
            } else {
              toast.info(tReview('autoAdvance'));
              setTimeout(goNext, 800);
            }
          }
        },
      },
    );
  }

  function handleRejectConfirm(reason: string) {
    reviewMutation.mutate(
      { action: 'reject', reason },
      {
        onSuccess: () => {
          setRejectDialogOpen(false);
          toast.success(tReview('rejectSuccess'));
          if (isInQueue) {
            if (isLastItem) {
              toast.info(tReview('queueComplete'));
              setTimeout(exitQueue, 800);
            } else {
              toast.info(tReview('autoAdvance'));
              setTimeout(goNext, 800);
            }
          }
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
        href="/vocabulary"
        className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="size-4" />
        {t('backToList')}
      </Link>

      <h1 className="text-xl font-semibold">{t('title.vocabulary')}</h1>

      {isInQueue && (
        <QueueNavigationBar
          position={position}
          total={total}
          hasPrev={hasPrev}
          hasNext={hasNext}
          onPrev={goPrev}
          onNext={goNext}
          onExit={exitQueue}
        />
      )}

      <ReviewHeader
        reviewStatus={data.reviewStatus}
        onApprove={handleApprove}
        onReject={() => setRejectDialogOpen(true)}
        isLoading={reviewMutation.isPending}
      />

      <TtsPlayer
        contentType="vocabulary"
        itemId={id}
        itemLabel={data.word}
      />

      <form onSubmit={handleSubmit(onSave)} className="space-y-6">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <div className="space-y-1.5">
            <Label htmlFor="word">{t('field.word')}</Label>
            <Input id="word" {...register('word')} />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="reading">{t('field.reading')}</Label>
            <Input id="reading" {...register('reading')} />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="meaningKo">{t('field.meaningKo')}</Label>
            <Input id="meaningKo" {...register('meaningKo')} />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="partOfSpeech">{t('field.partOfSpeech')}</Label>
            <Input id="partOfSpeech" {...register('partOfSpeech')} />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="exampleSentence">{t('field.exampleSentence')}</Label>
            <Textarea id="exampleSentence" rows={3} {...register('exampleSentence')} />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="exampleReading">{t('field.exampleReading')}</Label>
            <Textarea id="exampleReading" rows={3} {...register('exampleReading')} />
          </div>

          <div className="space-y-1.5 md:col-span-2">
            <Label htmlFor="exampleTranslation">{t('field.exampleTranslation')}</Label>
            <Textarea id="exampleTranslation" rows={2} {...register('exampleTranslation')} />
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
