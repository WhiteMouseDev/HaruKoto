import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { queryKeys } from '@/lib/query-keys';

type AvatarResponse = { avatarUrl: string };

export function useUploadAvatar() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (file: File): Promise<AvatarResponse> => {
      const formData = new FormData();
      formData.append('file', file);

      const res = await fetch('/api/v1/user/avatar', {
        method: 'POST',
        body: formData,
      });

      if (!res.ok) {
        const error = await res.json().catch(() => ({ error: '업로드 실패' }));
        throw new Error(error.error || `업로드 실패: ${res.status}`);
      }

      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.profile });
      queryClient.invalidateQueries({ queryKey: queryKeys.dashboard });
      toast.success('프로필 사진이 변경되었어요');
    },
    onError: (error: Error) => {
      toast.error(error.message);
    },
  });
}
