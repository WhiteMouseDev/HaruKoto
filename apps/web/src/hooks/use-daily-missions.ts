import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { apiFetch } from '@/lib/api';
import { queryKeys } from '@/lib/query-keys';

export type Mission = {
  id: string;
  missionType: string;
  label: string;
  description: string;
  targetCount: number;
  currentCount: number;
  isCompleted: boolean;
  rewardClaimed: boolean;
  xpReward: number;
};

type MissionsResponse = {
  missions: Mission[];
  completedCount: number;
  totalCount: number;
};

export function useDailyMissions() {
  return useQuery<MissionsResponse>({
    queryKey: queryKeys.missions,
    queryFn: () => apiFetch<MissionsResponse>('/api/v1/missions/today'),
    staleTime: 60 * 1000, // 1 minute
  });
}

export function useClaimMissionReward() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (missionId: string) =>
      apiFetch<{ success: boolean; xpReward: number; totalXp: number }>(
        '/api/v1/missions/claim',
        { method: 'POST', body: JSON.stringify({ missionId }) }
      ),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.missions });
      queryClient.invalidateQueries({ queryKey: queryKeys.profile });
      queryClient.invalidateQueries({ queryKey: queryKeys.dashboard });
    },
    onError: () => {
      toast.error('보상 수령에 실패했어요. 다시 시도해주세요.');
    },
  });
}
