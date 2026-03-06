'use client';

import { motion } from 'framer-motion';
import { LogOut, UserX } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { SectionLabel } from './section-label';

type AccountSectionProps = {
  onLogout: () => void;
  loggingOut: boolean;
  onDeleteAccount: () => void;
  deleting: boolean;
};

export function AccountSection({
  onLogout,
  loggingOut,
  onDeleteAccount,
  deleting,
}: AccountSectionProps) {
  return (
    <motion.div
      initial={{ y: 10, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ delay: 0.25 }}
      className="flex flex-col gap-1.5"
    >
      <SectionLabel>계정</SectionLabel>
      <Card>
        <CardContent className="flex flex-col p-0">
          {/* Logout */}
          <button
            className="hover:bg-accent flex items-center gap-3 px-4 py-3.5 text-left transition-colors"
            onClick={onLogout}
            disabled={loggingOut}
          >
            <LogOut className="text-muted-foreground size-5" />
            <span className="text-sm font-medium">
              {loggingOut ? '로그아웃 중...' : '로그아웃'}
            </span>
          </button>

          <Separator />

          {/* Delete Account */}
          <button
            className="hover:bg-accent flex items-center gap-3 px-4 py-3.5 text-left transition-colors"
            onClick={onDeleteAccount}
            disabled={deleting}
          >
            <UserX className="text-destructive size-5" />
            <span className="text-destructive text-sm font-medium">
              {deleting ? '탈퇴 처리 중...' : '회원 탈퇴'}
            </span>
          </button>
        </CardContent>
      </Card>
    </motion.div>
  );
}
