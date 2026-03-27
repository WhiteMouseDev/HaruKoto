'use client';

import { useTranslations } from 'next-intl';
import { Play, Pause, RotateCcw } from 'lucide-react';

import { Button } from '@/components/ui/button';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
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
    isPlaying,
    selectedField,
    setSelectedField,
    confirmOpen,
    setConfirmOpen,
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

  // Audio absent state
  if (!audioUrl) {
    return (
      <>
        <div className="flex items-center gap-2 rounded-lg border border-border bg-muted p-3">
          <Select value={selectedField} onValueChange={setSelectedField}>
            <SelectTrigger className="h-8 w-40">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {fields.map((opt) => (
                <SelectItem key={opt.value} value={opt.value}>
                  {t(opt.labelKey as Parameters<typeof t>[0])}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>

          <span className="flex-1 text-sm text-muted-foreground">
            {t('noAudio')}
          </span>

          <Button
            variant="default"
            size="sm"
            onClick={() => setConfirmOpen(true)}
          >
            {t('generate')}
          </Button>
        </div>

        <RegenerateConfirmDialog
          open={confirmOpen}
          onClose={() => setConfirmOpen(false)}
          onConfirm={() => regenerateMutation.mutate()}
          itemLabel={itemLabel}
          isLoading={regenerateMutation.isPending}
        />
      </>
    );
  }

  // Audio present state
  return (
    <>
      <div className="flex items-center gap-2 rounded-lg border border-border bg-card p-3">
        <Select value={selectedField} onValueChange={setSelectedField}>
          <SelectTrigger className="h-8 w-40">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {fields.map((opt) => (
              <SelectItem key={opt.value} value={opt.value}>
                {t(opt.labelKey as Parameters<typeof t>[0])}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Button
          variant="outline"
          size="icon"
          onClick={handlePlayPause}
          aria-label={isPlaying ? t('pause') : t('play')}
          className="size-8 shrink-0"
        >
          {isPlaying ? (
            <Pause className="size-4" />
          ) : (
            <Play className="size-4" />
          )}
        </Button>

        {/* Waveform bars */}
        <div
          className="flex flex-1 items-end gap-0.5"
          aria-hidden="true"
        >
          {[3, 5, 4, 3].map((h, i) => (
            <div
              key={i}
              className={`w-1 rounded-sm bg-primary/60 transition-all ${isPlaying ? 'animate-pulse' : ''}`}
              style={{ height: isPlaying ? `${h * 4}px` : `${h * 2}px` }}
            />
          ))}
        </div>

        <Button
          variant="ghost"
          size="icon"
          onClick={() => setConfirmOpen(true)}
          aria-label={t('regenerateTooltip')}
          className="size-8 shrink-0"
        >
          <RotateCcw className="size-4" />
        </Button>
      </div>

      <RegenerateConfirmDialog
        open={confirmOpen}
        onClose={() => setConfirmOpen(false)}
        onConfirm={() => regenerateMutation.mutate()}
        itemLabel={itemLabel}
        isLoading={regenerateMutation.isPending}
      />
    </>
  );
}
