'use client';

import { useTranslations } from 'next-intl';
import { Loader2 } from 'lucide-react';

import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

type RegenerateConfirmDialogProps = {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  itemLabel: string;
  isLoading: boolean;
};

export function RegenerateConfirmDialog({
  open,
  onClose,
  onConfirm,
  itemLabel,
  isLoading,
}: RegenerateConfirmDialogProps) {
  const t = useTranslations('tts');

  return (
    <Dialog open={open} onOpenChange={(next) => { if (!next) onClose(); }}>
      <DialogContent showCloseButton={false}>
        <DialogHeader>
          <DialogTitle>{t('regenerateTitle', { itemLabel })}</DialogTitle>
        </DialogHeader>

        <DialogFooter>
          <Button
            variant="outline"
            onClick={onClose}
            disabled={isLoading}
            autoFocus
          >
            {t('regenerateCancel')}
          </Button>
          <Button
            variant="default"
            onClick={onConfirm}
            disabled={isLoading}
          >
            {isLoading && <Loader2 className="mr-2 size-4 animate-spin" />}
            {t('regenerateConfirm')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
