'use client';

import { useState, useCallback } from 'react';
import { ProfileHero } from '@/components/features/my/profile-hero';
import { AchievementsSection } from '@/components/features/my/achievements-section';
import { SubscriptionSection } from '@/components/features/my/subscription-section';
import { SettingsMenu } from '@/components/features/my/settings-menu';
import {
  getDefaultCallSettings,
  type CallSettingsData,
} from '@/components/features/my/call-settings';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { createClient } from '@/lib/supabase/client';
import { useProfile } from '@/hooks/use-dashboard';
import { useUpdateProfile } from '@/hooks/use-update-profile';

type JlptLevel = 'N5' | 'N4' | 'N3' | 'N2' | 'N1';

type MyProfileData = {
  profile: {
    id: string;
    nickname: string;
    avatarUrl: string | null;
    jlptLevel: JlptLevel;
    dailyGoal: number;
    experiencePoints: number;
    level: number;
    levelProgress: { currentXp: number; xpForNext: number };
    streakCount: number;
    longestStreak: number;
    callSettings: Partial<CallSettingsData> | null;
    showKana: boolean;
    createdAt: string;
  };
  summary: {
    totalWordsStudied: number;
    totalQuizzesCompleted: number;
    totalStudyDays: number;
    totalXpEarned: number;
  };
  achievements: {
    achievementType: string;
    achievedAt: string;
  }[];
};

export default function MyPage() {
  const { data, isLoading: loading } = useProfile() as {
    data: MyProfileData | undefined;
    isLoading: boolean;
  };
  const updateProfile = useUpdateProfile();
  const [loggingOut, setLoggingOut] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [deleteConfirmText, setDeleteConfirmText] = useState('');
  const [deleting, setDeleting] = useState(false);

  const handleNicknameUpdate = useCallback(
    async (nickname: string) => {
      await updateProfile.mutateAsync({ nickname });
    },
    [updateProfile]
  );

  const handleUpdate = useCallback(
    async (field: string, value: unknown) => {
      await updateProfile.mutateAsync({ [field]: value });
    },
    [updateProfile]
  );

  const handleCallSettingsUpdate = useCallback(
    (partial: Partial<CallSettingsData>) => {
      updateProfile.mutate({ callSettings: partial });
    },
    [updateProfile]
  );

  const handleLogout = async () => {
    setLoggingOut(true);
    try {
      const supabase = createClient();
      await supabase.auth.signOut();
      window.location.href = '/login';
    } catch {
      setLoggingOut(false);
    }
  };

  const handleDeleteAccount = async () => {
    setDeleting(true);
    try {
      const res = await fetch('/api/v1/user/account', { method: 'DELETE' });
      if (!res.ok) throw new Error('Failed');
      const supabase = createClient();
      await supabase.auth.signOut();
      window.location.href = '/login';
    } catch {
      setDeleting(false);
    }
  };

  if (loading) {
    return (
      <div className="flex flex-col gap-4 p-4">
        <h1 className="pt-2 text-2xl font-bold">MY</h1>
        <div className="rounded-xl border p-4">
          <div className="flex items-center gap-3">
            <div className="bg-muted size-12 animate-pulse rounded-full" />
            <div className="flex flex-col gap-2">
              <div className="bg-muted h-5 w-24 animate-pulse rounded" />
              <div className="bg-muted h-1.5 w-32 animate-pulse rounded-full" />
            </div>
          </div>
          <div className="mt-4 grid grid-cols-4 gap-2">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="bg-muted h-12 animate-pulse rounded-lg" />
            ))}
          </div>
        </div>
        <div className="bg-muted h-20 animate-pulse rounded-xl" />
        <div className="bg-muted h-48 animate-pulse rounded-xl" />
      </div>
    );
  }

  if (!data) {
    return (
      <div className="flex flex-col gap-4 p-4">
        <h1 className="pt-2 text-2xl font-bold">MY</h1>
        <p className="text-muted-foreground">
          프로필을 불러올 수 없습니다. 다시 시도해주세요.
        </p>
      </div>
    );
  }

  const { profile, summary, achievements } = data;

  return (
    <div className="flex flex-col gap-4 p-4">
      <h1 className="pt-2 text-2xl font-bold">MY</h1>

      <ProfileHero
        nickname={profile.nickname}
        avatarUrl={profile.avatarUrl}
        jlptLevel={profile.jlptLevel}
        experiencePoints={profile.experiencePoints}
        level={profile.level}
        levelProgress={profile.levelProgress}
        totalStudyDays={summary.totalStudyDays}
        totalWordsStudied={summary.totalWordsStudied}
        longestStreak={profile.longestStreak}
        onNicknameUpdate={handleNicknameUpdate}
      />

      <AchievementsSection achievements={achievements} />

      <SubscriptionSection />

      <SettingsMenu
        jlptLevel={profile.jlptLevel}
        dailyGoal={profile.dailyGoal}
        showKana={profile.showKana}
        onUpdate={handleUpdate}
        callSettings={{
          ...getDefaultCallSettings(profile.jlptLevel),
          ...(profile.callSettings ?? {}),
        }}
        onCallSettingsUpdate={handleCallSettingsUpdate}
        onLogout={handleLogout}
        loggingOut={loggingOut}
        onDeleteAccount={() => setDeleteDialogOpen(true)}
        deleting={deleting}
      />

      {/* 사업자 정보 */}
      <footer className="text-muted-foreground/60 mt-4 mb-20 space-y-1 px-1 text-[11px] leading-relaxed">
        <p className="text-muted-foreground/80 font-medium">
          화이트마우스데브 (WhiteMouseDev)
        </p>
        <p>대표: 김건우</p>
        <p>사업자등록번호: 364-26-01985, 통신판매업신고번호: </p>
        <p>주소: 서울특별시 송파구 양재대로 1218</p>
        <p>연락처: whitemousedev@whitemouse.dev</p>
        <div className="flex gap-3 pt-1">
          <a href="/terms" className="underline underline-offset-2">
            이용약관
          </a>
          <a href="/privacy" className="underline underline-offset-2">
            개인정보처리방침
          </a>
        </div>
      </footer>

      {/* Delete Account Dialog */}
      <Dialog
        open={deleteDialogOpen}
        onOpenChange={(open) => {
          if (!deleting) {
            setDeleteDialogOpen(open);
            if (!open) setDeleteConfirmText('');
          }
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>회원 탈퇴</DialogTitle>
            <DialogDescription>
              탈퇴하면 다음 데이터가 모두 삭제되며 복구할 수 없습니다.
            </DialogDescription>
          </DialogHeader>

          <ul className="text-muted-foreground list-disc pl-5 text-sm">
            <li>학습 진행 상황</li>
            <li>퀴즈 기록</li>
            <li>AI 회화 기록</li>
            <li>단어장</li>
            <li>업적</li>
            <li>알림 설정</li>
          </ul>

          <div className="flex flex-col gap-2">
            <label htmlFor="delete-confirm" className="text-sm font-medium">
              확인을 위해 &quot;탈퇴&quot;를 입력해주세요.
            </label>
            <Input
              id="delete-confirm"
              value={deleteConfirmText}
              onChange={(e) => setDeleteConfirmText(e.target.value)}
              placeholder="탈퇴"
              disabled={deleting}
            />
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => {
                setDeleteDialogOpen(false);
                setDeleteConfirmText('');
              }}
              disabled={deleting}
            >
              취소
            </Button>
            <Button
              variant="destructive"
              onClick={handleDeleteAccount}
              disabled={deleteConfirmText !== '탈퇴' || deleting}
            >
              {deleting ? '탈퇴 처리 중...' : '회원 탈퇴'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
