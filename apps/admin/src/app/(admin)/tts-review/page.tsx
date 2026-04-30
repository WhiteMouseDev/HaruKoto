'use client';

import { useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  AlertTriangle,
  CheckCircle2,
  Eye,
  FileAudio2,
  Headphones,
  RefreshCw,
  ShieldAlert,
} from 'lucide-react';
import { useTranslations } from 'next-intl';
import {
  fetchTtsReviewBatchTargets,
  fetchTtsReviewBatches,
  fetchTtsReviewExecutePreview,
  fetchTtsReviewGenerationPlan,
  type TtsReviewBatchItem,
  type TtsReviewBatchTargetsResponse,
  type TtsReviewExecutePreviewItem,
  type TtsReviewExecutePreviewResponse,
  type TtsReviewGenerationPlanItem,
  type TtsReviewGenerationPlanResponse,
  type TtsReviewTargetItem,
  type TtsReviewSurface,
} from '@/lib/api/admin-content';
import { Button } from '@/components/ui/button';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { cn } from '@/lib/utils';

type FilterValue = 'all' | TtsReviewSurface;

const FILTERS: FilterValue[] = [
  'all',
  'admin_existing_tts',
  'admin_extension_required',
];

const EMPTY_BATCHES: TtsReviewBatchItem[] = [];

function surfaceClassName(surface: TtsReviewSurface): string {
  return surface === 'admin_existing_tts'
    ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-300'
    : 'bg-amber-100 text-amber-700 dark:bg-amber-950/40 dark:text-amber-300';
}

function SourceKindLabel({ kind }: { kind: TtsReviewBatchItem['sourceKind'] }) {
  const t = useTranslations('ttsReview');
  switch (kind) {
    case 'topic_vocabulary_fields':
      return t('sourceKind.topicVocabularyFields');
    case 'topic_grammar_fields':
      return t('sourceKind.topicGrammarFields');
    case 'topic_grammar_question_prompts':
      return t('sourceKind.topicGrammarQuestionPrompts');
    case 'topic_kana_fields':
      return t('sourceKind.topicKanaFields');
    case 'example_sentence_fields':
      return t('sourceKind.exampleSentenceFields');
    case 'seed_candidate_script_lines':
      return t('sourceKind.seedCandidateScriptLines');
    case 'seed_candidate_question_prompts':
      return t('sourceKind.seedCandidateQuestionPrompts');
  }
}

function SurfaceLabel({ surface }: { surface: TtsReviewSurface }) {
  const t = useTranslations('ttsReview');
  return surface === 'admin_existing_tts'
    ? t('surface.adminExisting')
    : t('surface.adminExtension');
}

function BlockerLabel({
  blocker,
}: {
  blocker: TtsReviewBatchItem['adminExport']['blockers'][number];
}) {
  const t = useTranslations('ttsReview');
  switch (blocker) {
    case 'admin_tts_field_gap':
      return t('blocker.adminTtsFieldGap');
    case 'admin_content_type_gap':
      return t('blocker.adminContentTypeGap');
    case 'lesson_seed_admin_surface_gap':
      return t('blocker.lessonSeedAdminSurfaceGap');
  }
}

function AudioTargetTypeLabel({
  type,
}: {
  type: TtsReviewTargetItem['audioTargetType'];
}) {
  const t = useTranslations('ttsReview');
  switch (type) {
    case 'vocabulary':
      return t('audioTargetType.vocabulary');
    case 'grammar':
      return t('audioTargetType.grammar');
    case 'kana':
      return t('audioTargetType.kana');
    case 'lesson_script':
      return t('audioTargetType.lessonScript');
    case 'example_sentence':
      return t('audioTargetType.exampleSentence');
    case 'question_prompt':
      return t('audioTargetType.questionPrompt');
  }
}

function AudioFieldLabel({
  field,
}: {
  field: TtsReviewTargetItem['audioField'];
}) {
  const t = useTranslations('ttsReview');
  switch (field) {
    case 'word':
      return t('audioField.word');
    case 'reading':
      return t('audioField.reading');
    case 'japanese':
      return t('audioField.japanese');
    case 'pattern':
      return t('audioField.pattern');
    case 'example_sentence':
      return t('audioField.exampleSentence');
    case 'script_line':
      return t('audioField.scriptLine');
    case 'question_prompt':
      return t('audioField.questionPrompt');
  }
}

function SummaryTile({
  label,
  value,
  icon,
}: {
  label: string;
  value: number;
  icon: ReactNode;
}) {
  return (
    <div className="flex min-h-24 items-center gap-3 rounded-lg border bg-card px-4 py-3">
      <div className="flex size-9 shrink-0 items-center justify-center rounded-md bg-muted text-muted-foreground">
        {icon}
      </div>
      <div className="min-w-0">
        <div className="truncate text-xs text-muted-foreground">{label}</div>
        <div className="mt-1 text-2xl font-semibold tabular-nums">{value}</div>
      </div>
    </div>
  );
}

function SkeletonRows() {
  return (
    <>
      {Array.from({ length: 5 }).map((_, index) => (
        <TableRow key={index}>
          <TableCell colSpan={7}>
            <div className="h-9 animate-pulse rounded-md bg-muted" />
          </TableCell>
        </TableRow>
      ))}
    </>
  );
}

function BatchTable({
  batches,
  isLoading,
  selectedBatchId,
  onSelectBatch,
}: {
  batches: TtsReviewBatchItem[];
  isLoading: boolean;
  selectedBatchId: string | null;
  onSelectBatch: (batchId: string) => void;
}) {
  const t = useTranslations('ttsReview');

  return (
    <div className="overflow-x-auto rounded-lg border bg-card">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="min-w-64 px-4">{t('table.batch')}</TableHead>
            <TableHead className="min-w-40">{t('table.surface')}</TableHead>
            <TableHead className="w-28 text-right">{t('table.targets')}</TableHead>
            <TableHead className="w-28 text-right">{t('table.required')}</TableHead>
            <TableHead className="w-32 text-right">{t('table.missing')}</TableHead>
            <TableHead className="min-w-64">{t('table.blockers')}</TableHead>
            <TableHead className="w-32 text-right">{t('table.actions')}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {isLoading ? (
            <SkeletonRows />
          ) : (
            batches.map((batch) => (
              <TableRow
                key={batch.batchId}
                className={cn(
                  selectedBatchId === batch.batchId &&
                    'bg-muted/40 hover:bg-muted/40',
                )}
              >
                <TableCell className="px-4 whitespace-normal">
                  <div className="font-medium">{batch.batchId}</div>
                  <div className="mt-1 text-xs text-muted-foreground">
                    <SourceKindLabel kind={batch.sourceKind} />
                  </div>
                </TableCell>
                <TableCell>
                  <span
                    className={cn(
                      'inline-flex rounded-full px-2 py-0.5 text-xs font-medium',
                      surfaceClassName(batch.reviewSurface),
                    )}
                  >
                    <SurfaceLabel surface={batch.reviewSurface} />
                  </span>
                </TableCell>
                <TableCell className="text-right tabular-nums">
                  {batch.targetCount}
                </TableCell>
                <TableCell className="text-right tabular-nums">
                  {batch.requiredBeforePublishCount}
                </TableCell>
                <TableCell className="text-right tabular-nums">
                  {batch.generationStatusSummary.missing}
                </TableCell>
                <TableCell className="whitespace-normal">
                  {batch.adminExport.blockers.length === 0 ? (
                    <span className="inline-flex items-center gap-1 text-xs text-muted-foreground">
                      <CheckCircle2 className="size-3.5" />
                      {t('table.noBlockers')}
                    </span>
                  ) : (
                    <div className="flex flex-wrap gap-1.5">
                      {batch.adminExport.blockers.map((blocker) => (
                        <span
                          key={blocker}
                          className="inline-flex items-center gap-1 rounded-md bg-muted px-2 py-1 text-xs"
                        >
                          <ShieldAlert className="size-3" />
                          <BlockerLabel blocker={blocker} />
                        </span>
                      ))}
                    </div>
                  )}
                </TableCell>
                <TableCell className="text-right">
                  <Button
                    type="button"
                    variant={
                      selectedBatchId === batch.batchId ? 'default' : 'outline'
                    }
                    size="sm"
                    aria-pressed={selectedBatchId === batch.batchId}
                    onClick={() => onSelectBatch(batch.batchId)}
                  >
                    <Eye className="size-4" />
                    {t('table.viewTargets')}
                  </Button>
                </TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>
    </div>
  );
}

function TargetRowsSkeleton() {
  return (
    <>
      {Array.from({ length: 4 }).map((_, index) => (
        <TableRow key={index}>
          <TableCell colSpan={8}>
            <div className="h-9 animate-pulse rounded-md bg-muted" />
          </TableCell>
        </TableRow>
      ))}
    </>
  );
}

function TargetStatusBadge({
  target,
}: {
  target: TtsReviewTargetItem;
}) {
  const t = useTranslations('ttsReview');
  return (
    <span
      className={cn(
        'inline-flex rounded-full px-2 py-0.5 text-xs font-medium',
        target.generationStatus === 'missing'
          ? 'bg-slate-100 text-slate-700 dark:bg-slate-900 dark:text-slate-300'
          : 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-300',
      )}
    >
      {target.requiredBeforePublish
        ? t('target.required')
        : t('target.optional')}
      {' / '}
      {t(`generationStatus.${target.generationStatus}`)}
    </span>
  );
}

function GenerationPlanBadge({
  item,
  isLoading,
}: {
  item: TtsReviewGenerationPlanItem | undefined;
  isLoading: boolean;
}) {
  const t = useTranslations('ttsReview');

  if (isLoading || !item) {
    return (
      <span className="inline-flex rounded-full bg-muted px-2 py-0.5 text-xs font-medium text-muted-foreground">
        {t('generationPlan.loading')}
      </span>
    );
  }

  const className =
    item.operationStatus === 'ready_after_db_lookup'
      ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-300'
      : item.operationStatus === 'manual_mapping_required'
        ? 'bg-amber-100 text-amber-700 dark:bg-amber-950/40 dark:text-amber-300'
        : 'bg-rose-100 text-rose-700 dark:bg-rose-950/40 dark:text-rose-300';
  const visibleCandidates = item.candidates.slice(0, 3);

  return (
    <div className="flex flex-col items-start gap-1">
      <span
        className={cn(
          'inline-flex rounded-full px-2 py-0.5 text-xs font-medium',
          className,
        )}
      >
        {t(`generationPlan.${item.operationStatus}`)}
      </span>
      <span className="text-xs text-muted-foreground">
        {t('generationPlan.candidates', { count: item.candidates.length })}
      </span>
      {visibleCandidates.length > 0 ? (
        <div className="flex max-w-56 flex-col gap-0.5">
          {visibleCandidates.map((candidate) => {
            const order = candidate.vocabularyOrder ?? candidate.grammarOrder;
            const label =
              candidate.contentLabel ?? candidate.matchType ?? candidate.topicId;
            const detail =
              candidate.contentReading && candidate.meaningKo
                ? `${candidate.contentReading} · ${candidate.meaningKo}`
                : candidate.meaningKo;
            return (
              <div
                key={[
                  candidate.contentType,
                  candidate.topicId,
                  candidate.jlptLevel,
                  order,
                  candidate.matchType,
                ].join(':')}
                className="truncate text-xs text-muted-foreground"
                title={
                  detail
                    ? `${candidate.jlptLevel ?? ''} #${order} ${label} · ${detail}`
                    : undefined
                }
              >
                {candidate.jlptLevel ? `${candidate.jlptLevel} ` : null}
                {order ? `#${order} ` : null}
                {label}
              </div>
            );
          })}
          {item.candidates.length > visibleCandidates.length ? (
            <div className="text-xs text-muted-foreground">
              +{item.candidates.length - visibleCandidates.length}
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

function ExecutePreviewBadge({
  item,
  isLoading,
}: {
  item: TtsReviewExecutePreviewItem | undefined;
  isLoading: boolean;
}) {
  const t = useTranslations('ttsReview');

  if (isLoading || !item) {
    return (
      <span className="inline-flex rounded-full bg-muted px-2 py-0.5 text-xs font-medium text-muted-foreground">
        {t('executePreview.loading')}
      </span>
    );
  }

  const className =
    item.lookupStatus === 'resolved'
      ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-300'
      : item.lookupStatus === 'missing' || item.lookupStatus === 'ambiguous'
        ? 'bg-rose-100 text-rose-700 dark:bg-rose-950/40 dark:text-rose-300'
        : 'bg-muted text-muted-foreground';

  return (
    <div className="flex flex-col items-start gap-1">
      <span
        className={cn(
          'inline-flex rounded-full px-2 py-0.5 text-xs font-medium',
          className,
        )}
      >
        {t(`executePreview.${item.lookupStatus}`)}
      </span>
      {item.contentItemId ? (
        <span className="max-w-44 truncate font-mono text-xs text-muted-foreground">
          {item.contentLabel ?? item.contentItemId}
        </span>
      ) : null}
    </div>
  );
}

function TargetDetailPanel({
  selectedBatchId,
  data,
  generationPlan,
  executePreview,
  isLoading,
  isPlanLoading,
  isPreviewLoading,
  isError,
  onRetry,
}: {
  selectedBatchId: string | null;
  data: TtsReviewBatchTargetsResponse | undefined;
  generationPlan: TtsReviewGenerationPlanResponse | undefined;
  executePreview: TtsReviewExecutePreviewResponse | undefined;
  isLoading: boolean;
  isPlanLoading: boolean;
  isPreviewLoading: boolean;
  isError: boolean;
  onRetry: () => void;
}) {
  const t = useTranslations('ttsReview');
  const tError = useTranslations('error');
  const generationPlanByTargetId = useMemo(
    () =>
      new Map(
        generationPlan?.items.map((item) => [item.target.targetId, item]) ?? [],
      ),
    [generationPlan],
  );
  const executePreviewByTargetId = useMemo(
    () =>
      new Map(
        executePreview?.items.map((item) => [item.target.targetId, item]) ?? [],
      ),
    [executePreview],
  );

  if (!selectedBatchId) {
    return null;
  }

  return (
    <div className="mt-6 rounded-lg border bg-card">
      <div className="flex flex-col gap-2 border-b px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <FileAudio2 className="size-4 text-muted-foreground" />
            <h2 className="truncate text-sm font-semibold">
              {data?.batch.batchId ?? selectedBatchId}
            </h2>
          </div>
          <div className="mt-1 text-xs text-muted-foreground">
            {t('targetPanel.count', {
              count: data?.targets.length ?? data?.batch.targetCount ?? 0,
            })}
            {generationPlan?.summary ? (
              <>
                {' · '}
                {t('generationPlan.summary', {
                  ready: generationPlan.summary.readyAfterDbLookupTargets,
                  manual: generationPlan.summary.manualMappingRequiredTargets,
                  blocked: generationPlan.summary.blockedTargets,
                })}
              </>
            ) : null}
            {executePreview?.summary ? (
              <>
                {' · '}
                {t('executePreview.summary', {
                  resolved: executePreview.summary.resolvedTargets,
                  generatable: executePreview.summary.generatableTargets,
                })}
              </>
            ) : null}
          </div>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={onRetry}
          disabled={isLoading}
        >
          <RefreshCw className={cn('size-4', isLoading && 'animate-spin')} />
          {t('refresh')}
        </Button>
      </div>

      {isError ? (
        <div className="px-4 py-8 text-center">
          <p className="text-sm text-muted-foreground">
            {t('targetPanel.error')}
          </p>
          <Button
            variant="outline"
            size="sm"
            className="mt-4"
            onClick={onRetry}
          >
            {tError('retry')}
          </Button>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="min-w-64 px-4">
                  {t('targetTable.target')}
                </TableHead>
                <TableHead className="min-w-32">
                  {t('targetTable.type')}
                </TableHead>
                <TableHead className="min-w-32">
                  {t('targetTable.field')}
                </TableHead>
                <TableHead className="w-24 text-right">
                  {t('targetTable.speed')}
                </TableHead>
                <TableHead className="min-w-36">
                  {t('targetTable.status')}
                </TableHead>
                <TableHead className="min-w-44">
                  {t('targetTable.plan')}
                </TableHead>
                <TableHead className="min-w-44">
                  {t('targetTable.lookup')}
                </TableHead>
                <TableHead className="min-w-72">
                  {t('targetTable.source')}
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading || !data ? (
                <TargetRowsSkeleton />
              ) : (
                data.targets.map((target) => (
                  <TableRow key={target.targetId}>
                    <TableCell className="px-4 whitespace-normal">
                      <div className="font-medium">{target.targetId}</div>
                      <div className="mt-1 text-xs text-muted-foreground">
                        {target.topicId}
                      </div>
                    </TableCell>
                    <TableCell>
                      <AudioTargetTypeLabel type={target.audioTargetType} />
                    </TableCell>
                    <TableCell>
                      <AudioFieldLabel field={target.audioField} />
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {target.defaultSpeed.toFixed(2)}
                    </TableCell>
                    <TableCell>
                      <TargetStatusBadge target={target} />
                    </TableCell>
                    <TableCell>
                      <GenerationPlanBadge
                        item={generationPlanByTargetId.get(target.targetId)}
                        isLoading={isPlanLoading}
                      />
                    </TableCell>
                    <TableCell>
                      <ExecutePreviewBadge
                        item={executePreviewByTargetId.get(target.targetId)}
                        isLoading={isPreviewLoading}
                      />
                    </TableCell>
                    <TableCell className="whitespace-normal">
                      <div className="font-mono text-xs">
                        {target.textSource}
                      </div>
                      {target.preferredVoiceId ? (
                        <div className="mt-1 text-xs text-muted-foreground">
                          {target.preferredVoiceId}
                        </div>
                      ) : null}
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  );
}

export default function TtsReviewPage() {
  const t = useTranslations('ttsReview');
  const tError = useTranslations('error');
  const [filter, setFilter] = useState<FilterValue>('all');
  const [selectedBatchId, setSelectedBatchId] = useState<string | null>(null);
  const reviewSurface = filter === 'all' ? undefined : filter;
  const query = useQuery({
    queryKey: ['admin-tts-review-batches', reviewSurface ?? 'all'],
    queryFn: () => fetchTtsReviewBatches({ reviewSurface }),
    staleTime: 60_000,
  });
  const targetQuery = useQuery({
    queryKey: ['admin-tts-review-batch-targets', selectedBatchId],
    queryFn: () => {
      if (!selectedBatchId) {
        throw new Error('Missing selected TTS review batch');
      }
      return fetchTtsReviewBatchTargets(selectedBatchId);
    },
    enabled: selectedBatchId !== null,
    staleTime: 60_000,
  });
  const generationPlanQuery = useQuery({
    queryKey: ['admin-tts-review-generation-plan', selectedBatchId],
    queryFn: () => {
      if (!selectedBatchId) {
        throw new Error('Missing selected TTS review batch');
      }
      return fetchTtsReviewGenerationPlan(selectedBatchId);
    },
    enabled: selectedBatchId !== null,
    staleTime: 60_000,
  });
  const executePreviewQuery = useQuery({
    queryKey: ['admin-tts-review-execute-preview', selectedBatchId],
    queryFn: () => {
      if (!selectedBatchId) {
        throw new Error('Missing selected TTS review batch');
      }
      return fetchTtsReviewExecutePreview(selectedBatchId);
    },
    enabled: selectedBatchId !== null,
    staleTime: 60_000,
  });

  const batches = query.data?.batches ?? EMPTY_BATCHES;
  const summary = query.data?.summary;
  const extensionBatches = useMemo(
    () =>
      batches.filter((batch) => batch.reviewSurface === 'admin_extension_required')
        .length,
    [batches],
  );

  return (
    <div className="max-w-6xl">
      <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <div className="flex items-center gap-2">
            <Headphones className="size-5 text-muted-foreground" />
            <h1 className="text-xl font-semibold">{t('title')}</h1>
          </div>
          <p className="mt-1 text-sm text-muted-foreground">{t('subtitle')}</p>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() => void query.refetch()}
          disabled={query.isFetching}
        >
          <RefreshCw
            className={cn('size-4', query.isFetching && 'animate-spin')}
          />
          {t('refresh')}
        </Button>
      </div>

      <div className="mb-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <SummaryTile
          label={t('summary.totalTargets')}
          value={summary?.totalTargets ?? 0}
          icon={<Headphones className="size-4" />}
        />
        <SummaryTile
          label={t('summary.adminReadyTargets')}
          value={summary?.adminReadyTargets ?? 0}
          icon={<CheckCircle2 className="size-4" />}
        />
        <SummaryTile
          label={t('summary.extensionRequiredTargets')}
          value={summary?.extensionRequiredTargets ?? 0}
          icon={<AlertTriangle className="size-4" />}
        />
        <SummaryTile
          label={t('summary.extensionBatches')}
          value={extensionBatches}
          icon={<ShieldAlert className="size-4" />}
        />
      </div>

      <div className="mb-4 flex flex-wrap gap-2">
        {FILTERS.map((value) => (
          <Button
            key={value}
            type="button"
            variant={filter === value ? 'default' : 'outline'}
            size="sm"
            aria-pressed={filter === value}
            onClick={() => {
              setFilter(value);
              setSelectedBatchId(null);
            }}
          >
            {value === 'all'
              ? t('filter.all')
              : value === 'admin_existing_tts'
                ? t('filter.adminExisting')
                : t('filter.adminExtension')}
          </Button>
        ))}
      </div>

      {query.isError ? (
        <div className="rounded-lg border bg-card px-4 py-10 text-center">
          <p className="text-sm text-muted-foreground">{t('error')}</p>
          <Button
            variant="outline"
            size="sm"
            className="mt-4"
            onClick={() => void query.refetch()}
          >
            {tError('retry')}
          </Button>
        </div>
      ) : (
        <>
          <BatchTable
            batches={batches}
            isLoading={query.isLoading}
            selectedBatchId={selectedBatchId}
            onSelectBatch={setSelectedBatchId}
          />
          <TargetDetailPanel
            selectedBatchId={selectedBatchId}
            data={targetQuery.data}
            generationPlan={generationPlanQuery.data}
            executePreview={executePreviewQuery.data}
            isLoading={targetQuery.isLoading}
            isPlanLoading={generationPlanQuery.isLoading}
            isPreviewLoading={executePreviewQuery.isLoading}
            isError={
              targetQuery.isError ||
              generationPlanQuery.isError ||
              executePreviewQuery.isError
            }
            onRetry={() => {
              void targetQuery.refetch();
              void generationPlanQuery.refetch();
              void executePreviewQuery.refetch();
            }}
          />
        </>
      )}
    </div>
  );
}
