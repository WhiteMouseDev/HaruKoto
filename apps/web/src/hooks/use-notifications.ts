import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import { queryKeys } from '@/lib/query-keys';

type Notification = {
  id: string;
  type: string;
  title: string;
  body: string;
  emoji: string | null;
  isRead: boolean;
  createdAt: string;
};

type NotificationsResponse = {
  notifications: Notification[];
  unreadCount: number;
};

export type { Notification };

export function useNotifications() {
  return useQuery<NotificationsResponse>({
    queryKey: queryKeys.notifications,
    queryFn: () => apiFetch<NotificationsResponse>('/api/v1/notifications'),
    staleTime: 30 * 1000,
  });
}

export function useMarkNotificationsRead() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: () =>
      apiFetch('/api/v1/notifications', {
        method: 'PATCH',
        body: JSON.stringify({}),
      }),
    onMutate: async () => {
      await queryClient.cancelQueries({ queryKey: queryKeys.notifications });

      const previous = queryClient.getQueryData<NotificationsResponse>(
        queryKeys.notifications
      );

      queryClient.setQueryData<NotificationsResponse>(
        queryKeys.notifications,
        (old) =>
          old
            ? {
                notifications: old.notifications.map((n) => ({
                  ...n,
                  isRead: true,
                })),
                unreadCount: 0,
              }
            : old
      );

      return { previous };
    },
    onError: (_err, _vars, context) => {
      if (context?.previous) {
        queryClient.setQueryData(queryKeys.notifications, context.previous);
      }
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.notifications });
    },
  });
}

export function useMarkNotificationRead() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) =>
      apiFetch('/api/v1/notifications', {
        method: 'PATCH',
        body: JSON.stringify({ id }),
      }),
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: queryKeys.notifications });

      const previous = queryClient.getQueryData<NotificationsResponse>(
        queryKeys.notifications
      );

      queryClient.setQueryData<NotificationsResponse>(
        queryKeys.notifications,
        (old) => {
          if (!old) return old;
          const target = old.notifications.find(
            (n) => n.id === id && !n.isRead
          );
          if (!target) return old;
          return {
            notifications: old.notifications.map((n) =>
              n.id === id ? { ...n, isRead: true } : n
            ),
            unreadCount: Math.max(0, old.unreadCount - 1),
          };
        }
      );

      return { previous };
    },
    onError: (_err, _vars, context) => {
      if (context?.previous) {
        queryClient.setQueryData(queryKeys.notifications, context.previous);
      }
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.notifications });
    },
  });
}
