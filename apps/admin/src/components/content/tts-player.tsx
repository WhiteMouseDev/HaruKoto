'use client';

import { useTranslations } from 'next-intl';
import { Play, Pause, RotateCcw, CheckCircle2, XCircle } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { useTtsPlayer } from '@/hooks/use-tts-player';
import { TTS_FIELDS, type ContentType } from '@/lib/tts-fields';
import { RegenerateConfirmDialog } from '@/components/content/regenerate-confirm-dialog';

type TtsPlayerProps = {
  contentType: ContentType;
  itemId: string;
  itemLabel: string;
};

export function TtsPlayer({ contentType, itemId, itemLabel }: TtsPlayerProps) {
  const t = useTranslations('tts');
  const {
    audioUrl,
    isLoading,
    playingField,
    confirmField,
    setConfirmField,
    handlePlayPause,
    regenerateMutation,
  } = useTtsPlayer(contentType, itemId);

  const fields = TTS_FIELDS[contentType].options;

  // Loading skeleton
  if (isLoading) {
    return (
      <div className="flex items-center gap-2 rounded-lg border border-border bg-card p-3">
        <div className="h-8 w-40 animate-pulse rounded bg-muted" />
        <div className="size-8 animate-pulse rounded-full bg-muted" />
        <div className="flex flex-1 items-end gap-0.5">
          {[3, 5, 4].map((h, i) => (
            <div
              key={i}
              className="w-1 animate-pulse rounded-sm bg-muted"
              style={{ height: `${h * 4}px` }}
            />
          ))}
        </div>
      </div>
    );
  }

  const hasAudio = !!audioUrl;

  return (
    <>
      <div className="rounded-lg border border-border bg-card">
        {fields.map((field, index) => (
          <div
            key={field.value}
            className={`flex items-center gap-2 p-3 ${
              index < fields.length - 1 ? 'border-b border-border' : ''
            }`}
          >
            {/* Status icon */}
            {hasAudio ? (
              <CheckCircle2 className="size-4 shrink-0 text-green-500" />
            ) : (
              <XCircle className="size-4 shrink-0 text-muted-foreground" />
            )}

            {/* Field name label */}
            <span className="flex-1 text-sm">
              {t(field.labelKey as Parameters<typeof t>[0])}
            </span>

            {/* Action buttons — audio present */}
            {hasAudio ? (
              <>
                <Button
                  variant="outline"
                  size="icon"
                  onClick={() => handlePlayPause(field.value)}
                  aria-label={playingField === field.value ? t('pause') : t('play')}
                  className="size-8 shrink-0"
                >
                  {playingField === field.value ? (
                    <Pause className="size-4" />
                  ) : (
                    <Play className="size-4" />
                  )}
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={() => setConfirmField(field.value)}
                  aria-label={t('regenerateTooltip')}
                  className="size-8 shrink-0"
                >
                  <RotateCcw className="size-4" />
                </Button>
              </>
            ) : (
              <>
                <span className="text-xs text-muted-foreground">
                  {t('noAudio')}
                </span>
                <Button
                  variant="default"
                  size="sm"
                  onClick={() => setConfirmField(field.value)}
                >
                  {t('generate')}
                </Button>
              </>
            )}
          </div>
        ))}
      </div>

      <RegenerateConfirmDialog
        open={confirmField !== null}
        onClose={() => setConfirmField(null)}
        onConfirm={() => {
          if (confirmField) {
            regenerateMutation.mutate(confirmField);
          }
        }}
        itemLabel={itemLabel}
        isLoading={regenerateMutation.isPending}
      />
    </>
  );
}
