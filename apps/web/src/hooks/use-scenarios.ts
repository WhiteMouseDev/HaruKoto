import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import { queryKeys } from '@/lib/query-keys';

type Scenario = {
  id: string;
  title: string;
  titleJa: string;
  description: string;
  category: string;
  difficulty: string;
  estimatedMinutes: number;
  keyExpressions: string[];
  situation: string;
  yourRole: string;
  aiRole: string;
};

type ScenariosResponse = {
  scenarios: Scenario[];
};

export type { Scenario, ScenariosResponse };

export function useScenarios(category: string | null) {
  return useQuery<ScenariosResponse>({
    queryKey: queryKeys.scenarios(category ?? ''),
    queryFn: () =>
      apiFetch<ScenariosResponse>(
        `/api/v1/chat/scenarios?category=${category}`
      ),
    enabled: !!category,
    staleTime: 30 * 60 * 1000,
  });
}
