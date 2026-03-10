'use client';

import { useState, useRef } from 'react';
import { motion } from 'framer-motion';
import {
  User as UserIcon,
  Pencil,
  Camera,
  Calendar,
  BookOpen,
  Zap,
  Flame,
  Loader2,
} from 'lucide-react';
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { Progress } from '@/components/ui/progress';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from '@/components/ui/sheet';

type ProfileHeroProps = {
  nickname: string;
  avatarUrl: string | null;
  jlptLevel: string;
  experiencePoints: number;
  level: number;
  levelProgress: { currentXp: number; xpForNext: number };
  totalStudyDays: number;
  totalWordsStudied: number;
  longestStreak: number;
  onNicknameUpdate?: (nickname: string) => Promise<void>;
  onAvatarUpload?: (file: File) => Promise<void>;
  avatarUploading?: boolean;
};

export function ProfileHero({
  nickname,
  avatarUrl,
  jlptLevel,
  experiencePoints,
  level,
  levelProgress,
  totalStudyDays,
  totalWordsStudied,
  longestStreak,
  onNicknameUpdate,
  onAvatarUpload,
  avatarUploading,
}: ProfileHeroProps) {
  const [sheetOpen, setSheetOpen] = useState(false);
  const [newNickname, setNewNickname] = useState(nickname);
  const [saving, setSaving] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleSave = async () => {
    if (!onNicknameUpdate || newNickname.trim().length < 1) return;
    setSaving(true);
    try {
      await onNicknameUpdate(newNickname.trim());
      setSheetOpen(false);
    } finally {
      setSaving(false);
    }
  };

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !onAvatarUpload) return;
    await onAvatarUpload(file);
    // Reset input so the same file can be re-selected
    e.target.value = '';
  };

  const stats = [
    { icon: Calendar, label: '총 학습일', value: `${totalStudyDays}일`, color: 'text-hk-blue' },
    { icon: BookOpen, label: '학습 단어', value: `${totalWordsStudied}개`, color: 'text-primary' },
    { icon: Zap, label: '총 XP', value: `${experiencePoints}`, color: 'text-hk-yellow' },
    { icon: Flame, label: '최장 연속', value: `${longestStreak}일`, color: 'text-hk-red' },
  ];

  return (
    <>
      <motion.div
        initial={{ y: 10, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.3 }}
      >
        <Card>
          <CardContent className="p-4">
            {/* Profile Row */}
            <div className="flex items-center gap-3">
              <button
                type="button"
                className="relative"
                disabled={avatarUploading}
                onClick={() => fileInputRef.current?.click()}
              >
                <Avatar className="size-12" size="lg">
                  {avatarUrl ? <AvatarImage src={avatarUrl} alt={nickname} /> : null}
                  <AvatarFallback className="size-12 text-base">
                    <UserIcon className="size-6" />
                  </AvatarFallback>
                </Avatar>
                <span className="bg-primary absolute -right-0.5 -bottom-0.5 flex size-5 items-center justify-center rounded-full text-white shadow-sm">
                  {avatarUploading ? (
                    <Loader2 className="size-3 animate-spin" />
                  ) : (
                    <Camera className="size-3" />
                  )}
                </span>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/jpeg,image/png,image/webp,image/gif"
                  className="hidden"
                  onChange={handleFileChange}
                />
              </button>
              <div className="flex items-center gap-2">
                <h2 className="text-lg font-bold">{nickname}</h2>
                {onNicknameUpdate && (
                  <button
                    type="button"
                    onClick={() => {
                      setNewNickname(nickname);
                      setSheetOpen(true);
                    }}
                    className="text-muted-foreground hover:text-foreground transition-colors"
                  >
                    <Pencil className="size-3.5" />
                  </button>
                )}
                <Badge variant="secondary" className="text-[10px]">
                  {jlptLevel}
                </Badge>
              </div>
            </div>

            {/* Level Progress Row */}
            <div className="mt-3 flex items-center gap-2">
              <span className="text-xs font-bold">Lv.{level}</span>
              <Progress
                value={levelProgress.currentXp}
                max={levelProgress.xpForNext}
                className="h-1.5 flex-1"
              />
              <span className="text-muted-foreground text-[10px] tabular-nums">
                {levelProgress.currentXp}/{levelProgress.xpForNext} XP
              </span>
            </div>

            <Separator className="my-3" />

            {/* Stats Row */}
            <div className="grid grid-cols-4 gap-1 text-center">
              {stats.map((stat) => (
                <div key={stat.label} className="flex flex-col items-center gap-0.5">
                  <stat.icon className={`size-4 ${stat.color}`} />
                  <span className="text-sm font-bold">{stat.value}</span>
                  <span className="text-muted-foreground text-[10px]">{stat.label}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </motion.div>

      <Sheet open={sheetOpen} onOpenChange={setSheetOpen}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>닉네임 변경</SheetTitle>
            <SheetDescription>새로운 닉네임을 입력해주세요.</SheetDescription>
          </SheetHeader>
          <div className="flex flex-col gap-3 px-4 pb-6">
            <Input
              value={newNickname}
              onChange={(e) => setNewNickname(e.target.value)}
              maxLength={20}
              placeholder="닉네임을 입력해주세요"
              className="h-12 rounded-xl text-center text-lg"
            />
            <Button
              className="h-12 rounded-xl"
              disabled={newNickname.trim().length < 1 || saving}
              onClick={handleSave}
            >
              {saving ? '저장 중...' : '저장'}
            </Button>
          </div>
        </SheetContent>
      </Sheet>
    </>
  );
}
