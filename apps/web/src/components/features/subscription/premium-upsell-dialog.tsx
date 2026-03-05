'use client';

import { useRouter } from 'next/navigation';
import { Crown, Sparkles } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';

type PremiumUpsellDialogProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  reason?: string;
};

export function PremiumUpsellDialog({
  open,
  onOpenChange,
  reason,
}: PremiumUpsellDialogProps) {
  const router = useRouter();

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-sm">
        <DialogHeader className="items-center text-center">
          <div className="bg-primary/10 mb-2 flex size-16 items-center justify-center rounded-full">
            <Crown className="text-primary size-8" />
          </div>
          <DialogTitle className="text-xl">프리미엄으로 업그레이드</DialogTitle>
          <DialogDescription>
            {reason ?? '무제한 AI 학습으로 일본어 실력을 더 빠르게 키워보세요!'}
          </DialogDescription>
        </DialogHeader>

        <div className="flex flex-col gap-2 py-2">
          <div className="flex items-center gap-2 text-sm">
            <Sparkles className="text-hk-yellow size-4" />
            <span>AI 채팅 & 통화 무제한</span>
          </div>
          <div className="flex items-center gap-2 text-sm">
            <Sparkles className="text-hk-yellow size-4" />
            <span>모든 AI 캐릭터 해금</span>
          </div>
          <div className="flex items-center gap-2 text-sm">
            <Sparkles className="text-hk-yellow size-4" />
            <span>상세 학습 리포트</span>
          </div>
        </div>

        <DialogFooter className="flex-col gap-2 sm:flex-col">
          <Button
            className="w-full"
            size="lg"
            onClick={() => {
              onOpenChange(false);
              router.push('/pricing');
            }}
          >
            플랜 보기
          </Button>
          <Button
            variant="ghost"
            className="w-full"
            onClick={() => onOpenChange(false)}
          >
            나중에
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
