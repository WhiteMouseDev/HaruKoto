'use client';

import { useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { Bell, BellOff, Check } from 'lucide-react';
import { GameIcon } from '@/components/ui/game-icon';
import { Button } from '@/components/ui/button';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from '@/components/ui/sheet';
import {
  useNotifications,
  useMarkNotificationsRead,
  useMarkNotificationRead,
} from '@/hooks/use-notifications';

const TYPE_ICON: Record<string, string> = {
  level_up: 'party-popper',
  streak: 'flame',
  achievement: 'trophy',
};

const TYPE_LINK: Record<string, string> = {
  level_up: '/my',
  streak: '/home',
  achievement: '/my',
  xp: '/home',
};

function formatRelativeTime(dateStr: string): string {
  const now = Date.now();
  const diff = now - new Date(dateStr).getTime();
  const minutes = Math.floor(diff / 60_000);

  if (minutes < 1) return '방금 전';
  if (minutes < 60) return `${minutes}분 전`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}시간 전`;

  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}일 전`;

  return new Date(dateStr).toLocaleDateString('ko-KR', {
    month: 'short',
    day: 'numeric',
  });
}

export function NotificationCenter() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const { data, isLoading: loading } = useNotifications();
  const markRead = useMarkNotificationsRead();
  const markOne = useMarkNotificationRead();

  const notifications = data?.notifications ?? [];
  const unreadCount = data?.unreadCount ?? 0;

  const handleNotificationClick = useCallback(
    (id: string, type: string, isRead: boolean) => {
      if (!isRead) {
        markOne.mutate(id);
      }
      const link = TYPE_LINK[type];
      if (link) {
        setOpen(false);
        router.push(link);
      }
    },
    [markOne, router]
  );

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <button className="bg-accent relative flex items-center justify-center rounded-full p-2">
          <Bell className="text-muted-foreground size-5" />
          {unreadCount > 0 && (
            <span className="bg-hk-red absolute -top-0.5 -right-0.5 flex size-4 items-center justify-center rounded-full text-[10px] font-bold text-white">
              {unreadCount > 9 ? '9+' : unreadCount}
            </span>
          )}
        </button>
      </SheetTrigger>
      <SheetContent side="right" className="flex flex-col">
        <SheetHeader className="flex-row items-center justify-between">
          <SheetTitle>알림</SheetTitle>
          {unreadCount > 0 && (
            <Button
              variant="ghost"
              size="sm"
              className="text-muted-foreground gap-1.5 text-xs"
              onClick={() => markRead.mutate()}
            >
              <Check className="size-3.5" />
              모두 읽음
            </Button>
          )}
        </SheetHeader>

        <div className="flex-1 overflow-y-auto">
          {loading && notifications.length === 0 ? (
            <div className="flex flex-col gap-3 p-4">
              {[1, 2, 3].map((n) => (
                <div
                  key={n}
                  className="bg-secondary h-16 animate-pulse rounded-lg"
                />
              ))}
            </div>
          ) : notifications.length === 0 ? (
            <div className="flex flex-col items-center justify-center gap-2 py-16">
              <BellOff className="text-muted-foreground size-10" />
              <p className="text-muted-foreground text-sm">
                새로운 알림이 없어요
              </p>
            </div>
          ) : (
            <div className="flex flex-col">
              {notifications.map((notification) => (
                <button
                  key={notification.id}
                  className={`hover:bg-accent flex w-full gap-3 border-b px-4 py-3 text-left transition-colors ${
                    notification.isRead ? 'opacity-60' : ''
                  }`}
                  onClick={() =>
                    handleNotificationClick(
                      notification.id,
                      notification.type,
                      notification.isRead
                    )
                  }
                >
                  <GameIcon
                    name={
                      notification.emoji ||
                      TYPE_ICON[notification.type] ||
                      'megaphone'
                    }
                    className="mt-0.5 size-5 shrink-0"
                  />
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium">{notification.title}</p>
                    <p className="text-muted-foreground truncate text-xs">
                      {notification.body}
                    </p>
                    <p className="text-muted-foreground mt-0.5 text-[11px]">
                      {formatRelativeTime(notification.createdAt)}
                    </p>
                  </div>
                  {!notification.isRead && (
                    <span className="bg-hk-red mt-2 size-2 shrink-0 rounded-full" />
                  )}
                </button>
              ))}
            </div>
          )}
        </div>
      </SheetContent>
    </Sheet>
  );
}
