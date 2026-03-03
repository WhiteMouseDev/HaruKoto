'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import { User as UserIcon, Pencil } from 'lucide-react';
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from '@/components/ui/sheet';

type JlptLevel = 'N5' | 'N4' | 'N3' | 'N2' | 'N1';

type ProfileHeaderProps = {
  nickname: string;
  avatarUrl: string | null;
  jlptLevel: JlptLevel;
  createdAt: string;
  onNicknameUpdate?: (nickname: string) => Promise<void>;
};

export function ProfileHeader({
  nickname,
  avatarUrl,
  jlptLevel,
  createdAt,
  onNicknameUpdate,
}: ProfileHeaderProps) {
  const [sheetOpen, setSheetOpen] = useState(false);
  const [newNickname, setNewNickname] = useState(nickname);
  const [saving, setSaving] = useState(false);

  const joinDate = new Date(createdAt).toLocaleDateString('ko-KR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

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

  return (
    <>
      <motion.div
        className="flex items-center gap-4"
        initial={{ y: 10, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.3 }}
      >
        <Avatar className="size-16" size="lg">
          {avatarUrl ? <AvatarImage src={avatarUrl} alt={nickname} /> : null}
          <AvatarFallback className="size-16 text-lg">
            <UserIcon className="size-7" />
          </AvatarFallback>
        </Avatar>
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-2">
            <h2 className="text-xl font-bold">{nickname}</h2>
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
          <p className="text-muted-foreground text-sm">{joinDate} 가입</p>
        </div>
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
