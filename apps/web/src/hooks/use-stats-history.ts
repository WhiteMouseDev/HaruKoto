import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import { queryKeys } from '@/lib/query-keys';

export type HistoryRecord = {
  date: string;
  wordsStudied: number;
  quizzesCompleted: number;
  correctAnswers: number;
  totalAnswers: number;
  conversationCount: number;
  studyTimeSeconds: number;
  xpEarned: number;
};

type HistoryData = {
  year: number;
  month: number;
  records: HistoryRecord[];
};

async function fetchAllHistory(year: number): Promise<HistoryRecord[]> {
  const now = new Date();
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth() + 1;

  const maxMonth = year === currentYear ? currentMonth : 12;

  const promises = Array.from({ length: maxMonth }, (_, i) =>
    apiFetch<HistoryData>(
      `/api/v1/stats/history?year=${year}&month=${i + 1}`
    ).catch(() => ({ year, month: i + 1, records: [] as HistoryRecord[] }))
  );

  const results = await Promise.all(promises);
  return results.flatMap((r) => r.records);
}

export function useStatsHistory(year: number) {
  return useQuery<HistoryRecord[]>({
    queryKey: queryKeys.statsHistory(year),
    queryFn: () => fetchAllHistory(year),
    staleTime: 10 * 60 * 1000,
  });
}
