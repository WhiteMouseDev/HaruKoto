'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api';
import { queryKeys } from '@/lib/query-keys';

export type CharacterListItem = {
  id: string;
  name: string;
  nameJa: string;
  nameRomaji: string;
  gender: string;
  description: string;
  relationship: string;
  speechStyle: string;
  targetLevel: string;
  tier: string;
  unlockCondition: string | null;
  isDefault: boolean;
  avatarEmoji: string;
  avatarUrl: string | null;
  gradient: string | null;
  order: number;
};

export type CharacterDetail = CharacterListItem & {
  ageDescription: string;
  backgroundStory: string;
  personality: string;
  voiceName: string;
  voiceBackup: string | null;
  silenceMs: number;
};

export function useCharacters() {
  return useQuery({
    queryKey: queryKeys.characters,
    queryFn: () =>
      apiFetch<{ characters: CharacterListItem[] }>('/api/v1/chat/characters'),
    select: (data) => data.characters,
    staleTime: 5 * 60 * 1000,
  });
}

export function useCharacter(id: string | null) {
  return useQuery({
    queryKey: queryKeys.character(id ?? ''),
    queryFn: () =>
      apiFetch<{ character: CharacterDetail }>(
        `/api/v1/chat/characters?id=${id}`
      ),
    select: (data) => data.character,
    enabled: !!id,
    staleTime: 5 * 60 * 1000,
  });
}

export function useCharacterStats() {
  return useQuery({
    queryKey: queryKeys.characterStats,
    queryFn: () =>
      apiFetch<{ characterStats: Record<string, number> }>(
        '/api/v1/chat/characters/stats'
      ),
    select: (data) => data.characterStats,
    staleTime: 60 * 1000,
  });
}

export function useCharacterFavorites() {
  return useQuery({
    queryKey: queryKeys.characterFavorites,
    queryFn: () =>
      apiFetch<{ favoriteIds: string[] }>(
        '/api/v1/chat/characters/favorites'
      ),
    select: (data) => new Set(data.favoriteIds),
    staleTime: 60 * 1000,
  });
}

export function useToggleFavorite() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (characterId: string) =>
      apiFetch<{ favorited: boolean }>('/api/v1/chat/characters/favorites', {
        method: 'POST',
        body: JSON.stringify({ characterId }),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.characterFavorites });
    },
  });
}
