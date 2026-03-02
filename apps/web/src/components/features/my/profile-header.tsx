'use client';

import { motion } from 'framer-motion';
import { User as UserIcon } from 'lucide-react';
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
type JlptLevel = 'N5' | 'N4' | 'N3' | 'N2' | 'N1';

type ProfileHeaderProps = {
  nickname: string;
  avatarUrl: string | null;
  jlptLevel: JlptLevel;
  createdAt: string;
};

export function ProfileHeader({
  nickname,
  avatarUrl,
  jlptLevel,
  createdAt,
}: ProfileHeaderProps) {
  const joinDate = new Date(createdAt).toLocaleDateString('ko-KR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  return (
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
          <Badge variant="secondary" className="text-[10px]">
            {jlptLevel}
          </Badge>
        </div>
        <p className="text-muted-foreground text-sm">{joinDate} 가입</p>
      </div>
    </motion.div>
  );
}
