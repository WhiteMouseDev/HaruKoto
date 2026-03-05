import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { apiFetch } from '@/lib/api';
import { queryKeys } from '@/lib/query-keys';

type ProfileCache = {
  profile: Record<string, unknown>;
  summary: Record<string, unknown>;
  achievements: unknown[];
};

export function useUpdateProfile() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: Record<string, unknown>) =>
      apiFetch('/api/v1/user/profile', {
        method: 'PATCH',
        body: JSON.stringify(data),
      }),
    onMutate: async (data) => {
      await queryClient.cancelQueries({ queryKey: queryKeys.profile });

      const previous = queryClient.getQueryData<ProfileCache>(queryKeys.profile);

      if (previous) {
        queryClient.setQueryData<ProfileCache>(queryKeys.profile, (old) => {
          if (!old) return old;

          const newProfile = { ...old.profile };

          // callSettings: merge into existing
          if (data.callSettings) {
            const existing = (newProfile.callSettings as Record<string, unknown>) ?? {};
            newProfile.callSettings = { ...existing, ...(data.callSettings as Record<string, unknown>) };
          }

          // Direct profile fields (nickname, jlptLevel, dailyGoal, etc.)
          const { callSettings: _, ...directFields } = data; // eslint-disable-line @typescript-eslint/no-unused-vars
          Object.assign(newProfile, directFields);

          return { ...old, profile: newProfile };
        });
      }

      return { previous };
    },
    onError: (_err, _data, context) => {
      if (context?.previous) {
        queryClient.setQueryData(queryKeys.profile, context.previous);
      }
      toast.error('설정 변경에 실패했어요. 다시 시도해주세요.');
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.profile });
      queryClient.invalidateQueries({ queryKey: queryKeys.dashboard });
    },
  });
}
