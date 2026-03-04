'use client';

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { useVoiceCall, type CallScenario, type CallSettings } from '@/hooks/use-voice-call';
import { getDefaultCallSettings } from '@/components/features/my/call-settings';
import { useProfile } from '@/hooks/use-dashboard';
import { useCharacter } from '@/hooks/use-characters';
import { CallScreen } from '@/components/features/chat/call-screen';
import { setDarkTheme, setLightTheme } from '@/lib/flutter-bridge';
import { apiFetch } from '@/lib/api';
import type { Scenario } from '@/hooks/use-scenarios';

function CallPageInner() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const scenarioId = searchParams.get('scenarioId');
  const characterId = searchParams.get('characterId');

  const { data: profileData } = useProfile();
  const { data: character, isLoading: characterLoading } = useCharacter(characterId);
  const [scenario, setScenario] = useState<CallScenario | undefined>();
  const [scenarioLoading, setScenarioLoading] = useState(!!scenarioId);

  // Fetch scenario data when scenarioId is present
  useEffect(() => {
    if (!scenarioId) return;

    async function fetchScenario() {
      try {
        // Find the scenario from the scenarios list
        const data = await apiFetch<{ scenarios: Scenario[] }>(
          '/api/v1/chat/scenarios'
        );
        const found = data.scenarios.find((s) => s.id === scenarioId);
        if (found) {
          setScenario({
            id: found.id,
            title: found.title,
            titleJa: found.titleJa,
            situation: found.situation,
            yourRole: found.yourRole,
            aiRole: found.aiRole,
            systemPrompt: null,
            keyExpressions: found.keyExpressions,
          });
        }
      } catch {
        // Fallback to free call if scenario fetch fails
      } finally {
        setScenarioLoading(false);
      }
    }

    fetchScenario();
  }, [scenarioId]);

  const jlptLevel = profileData?.profile.jlptLevel ?? 'N5';
  const userCallSettings: CallSettings = {
    ...getDefaultCallSettings(jlptLevel),
    ...((profileData?.profile as Record<string, unknown>)?.callSettings as CallSettings ?? {}),
  };

  const call = useVoiceCall({
    nickname: profileData?.profile.nickname,
    jlptLevel,
    scenario,
    callSettings: userCallSettings,
    character: character ?? undefined,
  });

  // Flutter WebView 배경색 동기화
  useEffect(() => {
    setDarkTheme();
    return () => setLightTheme();
  }, []);

  // Warn before leaving during active call
  useEffect(() => {
    function handleBeforeUnload(e: BeforeUnloadEvent) {
      if (call.state !== 'idle' && call.state !== 'ended') {
        e.preventDefault();
      }
    }

    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, [call.state]);

  if (scenarioLoading || characterLoading) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-linear-to-b from-slate-900 to-black">
        <div className="size-6 animate-spin rounded-full border-2 border-white/30 border-t-white" />
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-50 bg-linear-to-b from-slate-900 to-black">
      <CallScreen
        call={call}
        scenarioTitle={scenario?.title}
        characterName={character?.name}
        characterNameJa={character?.nameJa}
        avatarUrl={character?.avatarUrl ?? undefined}
        onBack={() => router.back()}
      />
    </div>
  );
}

export default function CallPage() {
  return (
    <Suspense
      fallback={
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-linear-to-b from-slate-900 to-black">
          <div className="size-6 animate-spin rounded-full border-2 border-white/30 border-t-white" />
        </div>
      }
    >
      <CallPageInner />
    </Suspense>
  );
}
