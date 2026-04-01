'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';

import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';

type RejectReasonDialogProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onConfirm: (reason: string) => void;
  isLoading: boolean;
};

export function RejectReasonDialog({
  open,
  onOpenChange,
  onConfirm,
  isLoading,
}: RejectReasonDialogProps) {
  const t = useTranslations('review');
  const [reason, setReason] = useState('');

  function handleOpenChange(nextOpen: boolean) {
    if (!nextOpen) {
      setReason('');
    }
    onOpenChange(nextOpen);
  }

  function handleConfirm() {
    if (reason.trim().length === 0) return;
    onConfirm(reason.trim());
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent showCloseButton={false}>
        <DialogHeader>
          <DialogTitle>{t('reject')}</DialogTitle>
        </DialogHeader>

        <div className="flex flex-col gap-2">
          <Label htmlFor="reject-reason">{t('reasonLabel')}</Label>
          <Textarea
            id="reject-reason"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder={t('reasonPlaceholder')}
            rows={4}
            disabled={isLoading}
          />
        </div>

        <DialogFooter>
          <Button
            variant="outline"
            onClick={() => handleOpenChange(false)}
            disabled={isLoading}
          >
            {t('cancel')}
          </Button>
          <Button
            variant="destructive"
            onClick={handleConfirm}
            disabled={isLoading || reason.trim().length === 0}
          >
            {t('confirmReject')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
