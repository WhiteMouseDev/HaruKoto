'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useParams, useSearchParams } from 'next/navigation';
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

type ReviewStatus = 'needs_review' | 'approved' | 'rejected';

type ClozeDetail = {
  id: string;
  sentence: string;
  translation: string;
  correctAnswer: string;
  options: unknown[] | null;
  explanation: string | null;
  jlptLevel: string;
  reviewStatus: ReviewStatus;
  createdAt: string;
  updatedAt: string | null;
};

type SentenceArrangeDetail = {
  id: string;
  koreanSentence: string;
  japaneseSentence: string;
  tokens: unknown[] | null;
  explanation: string | null;
  jlptLevel: string;
  reviewStatus: ReviewStatus;
  createdAt: string;
  updatedAt: string | null;
};

type QuizDetail = ClozeDetail | SentenceArrangeDetail;

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

const clozeSchema = z.object({
  sentence: z.string().min(1),
  translation: z.string().min(1),
  correctAnswer: z.string().min(1),
  options: jsonArraySchema,
  explanation: z.string().optional(),
});

const sentenceArrangeSchema = z.object({
  koreanSentence: z.string().min(1),
  japaneseSentence: z.string().min(1),
  tokens: jsonArraySchema,
  explanation: z.string().optional(),
});

type ClozeFormValues = z.infer<typeof clozeSchema>;
type SentenceArrangeFormValues = z.infer<typeof sentenceArrangeSchema>;

function isCloze(detail: QuizDetail): detail is ClozeDetail {
  return 'sentence' in detail;
}

function ClozeForm({
  data,
  patchMutation,
}: {
  data: ClozeDetail;
  patchMutation: { mutate: (data: Record<string, unknown>, opts?: { onSuccess?: () => void; onError?: () => void }) => void; isPending: boolean };
}) {
  const t = useTranslations('edit');
  const { register, handleSubmit, formState: { dirtyFields }, reset } = useForm<ClozeFormValues>({
    resolver: zodResolver(clozeSchema),
    values: {
      sentence: data.sentence,
      translation: data.translation,
      correctAnswer: data.correctAnswer,
      options: data.options ? JSON.stringify(data.options, null, 2) : '',
      explanation: data.explanation ?? '',
    },
  });

  function onSave(values: ClozeFormValues) {
    const changed: Record<string, unknown> = {};
    (Object.keys(dirtyFields) as (keyof ClozeFormValues)[]).forEach((key) => {
      if (key === 'options') {
        const val = values[key];
        changed[key] = val && val.trim() ? (JSON.parse(val) as unknown[]) : null;
      } else {
        changed[key] = values[key];
      }
    });
    if (Object.keys(changed).length === 0) { toast.info('変更がありません'); return; }
    patchMutation.mutate(changed, {
      onSuccess: () => { toast.success(t('saveSuccess')); reset(values); },
      onError: () => toast.error(t('saveError')),
    });
  }

  return (
    <form onSubmit={handleSubmit(onSave)} className="space-y-6">
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <div className="space-y-1.5 md:col-span-2">
          <Label htmlFor="sentence">{t('field.sentence')}</Label>
          <Textarea id="sentence" rows={3} {...register('sentence')} />
        </div>
        <div className="space-y-1.5 md:col-span-2">
          <Label htmlFor="translation">{t('field.translation')}</Label>
          <Textarea id="translation" rows={2} {...register('translation')} />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="correctAnswer">{t('field.correctAnswer')}</Label>
          <Input id="correctAnswer" {...register('correctAnswer')} />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="options">{t('field.options')}</Label>
          <Textarea id="options" rows={3} placeholder='["選択肢1","選択肢2"]' {...register('options')} />
        </div>
        <div className="space-y-1.5 md:col-span-2">
          <Label htmlFor="explanation">{t('field.explanation')}</Label>
          <Textarea id="explanation" rows={3} {...register('explanation')} />
        </div>
      </div>
      <Button type="submit" disabled={patchMutation.isPending} className="bg-primary">
        {t('save')}
      </Button>
    </form>
  );
}

function SentenceArrangeForm({
  data,
  patchMutation,
}: {
  data: SentenceArrangeDetail;
  patchMutation: { mutate: (data: Record<string, unknown>, opts?: { onSuccess?: () => void; onError?: () => void }) => void; isPending: boolean };
}) {
  const t = useTranslations('edit');
  const { register, handleSubmit, formState: { dirtyFields }, reset } = useForm<SentenceArrangeFormValues>({
    resolver: zodResolver(sentenceArrangeSchema),
    values: {
      koreanSentence: data.koreanSentence,
      japaneseSentence: data.japaneseSentence,
      tokens: data.tokens ? JSON.stringify(data.tokens, null, 2) : '',
      explanation: data.explanation ?? '',
    },
  });

  function onSave(values: SentenceArrangeFormValues) {
    const changed: Record<string, unknown> = {};
    (Object.keys(dirtyFields) as (keyof SentenceArrangeFormValues)[]).forEach((key) => {
      if (key === 'tokens') {
        const val = values[key];
        changed[key] = val && val.trim() ? (JSON.parse(val) as unknown[]) : null;
      } else {
        changed[key] = values[key];
      }
    });
    if (Object.keys(changed).length === 0) { toast.info('変更がありません'); return; }
    patchMutation.mutate(changed, {
      onSuccess: () => { toast.success(t('saveSuccess')); reset(values); },
      onError: () => toast.error(t('saveError')),
    });
  }

  return (
    <form onSubmit={handleSubmit(onSave)} className="space-y-6">
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <div className="space-y-1.5 md:col-span-2">
          <Label htmlFor="koreanSentence">{t('field.koreanSentence')}</Label>
          <Textarea id="koreanSentence" rows={2} {...register('koreanSentence')} />
        </div>
        <div className="space-y-1.5 md:col-span-2">
          <Label htmlFor="japaneseSentence">{t('field.japaneseSentence')}</Label>
          <Textarea id="japaneseSentence" rows={2} {...register('japaneseSentence')} />
        </div>
        <div className="space-y-1.5 md:col-span-2">
          <Label htmlFor="tokens">{t('field.tokens')}</Label>
          <Textarea id="tokens" rows={4} placeholder='["トークン1","トークン2"]' {...register('tokens')} />
        </div>
        <div className="space-y-1.5 md:col-span-2">
          <Label htmlFor="explanation">{t('field.explanation')}</Label>
          <Textarea id="explanation" rows={3} {...register('explanation')} />
        </div>
      </div>
      <Button type="submit" disabled={patchMutation.isPending} className="bg-primary">
        {t('save')}
      </Button>
    </form>
  );
}

export default function QuizDetailPage() {
  const { id } = useParams<{ id: string }>();
  const searchParams = useSearchParams();
  const quizType = searchParams.get('type') ?? 'cloze';
  const t = useTranslations('edit');
  const tReview = useTranslations('review');
  const [rejectDialogOpen, setRejectDialogOpen] = useState(false);

  // Map quiz type to API content type
  const apiContentType =
    quizType === 'sentence_arrange' ? 'quiz/sentence-arrange' : 'quiz/cloze';

  const { detailQuery, patchMutation, reviewMutation, auditQuery } =
    useContentDetail<QuizDetail>(apiContentType, id);

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
  } = useReviewQueue('quiz');

  const data = detailQuery.data;

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
        {Array.from({ length: 5 }).map((_, i) => (
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
        href="/quiz"
        className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="size-4" />
        {t('backToList')}
      </Link>

      <h1 className="text-xl font-semibold">{t('title.quiz')}</h1>

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
        contentType={quizType === 'sentence_arrange' ? 'sentence_arrange' : 'cloze'}
        itemId={id}
        itemLabel={
          isCloze(data)
            ? data.sentence
            : (data as SentenceArrangeDetail).japaneseSentence
        }
      />

      {isCloze(data) ? (
        <ClozeForm data={data} patchMutation={patchMutation} />
      ) : (
        <SentenceArrangeForm
          data={data as SentenceArrangeDetail}
          patchMutation={patchMutation}
        />
      )}

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
