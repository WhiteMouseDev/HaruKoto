'use client';

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { useVoiceCall, type CallScenario } from '@/hooks/use-voice-call';
import { useProfile } from '@/hooks/use-dashboard';
import { CallScreen } from '@/components/features/chat/call-screen';
import { apiFetch } from '@/lib/api';
import type { Scenario } from '@/hooks/use-scenarios';

function CallPageInner() {
  const searchParams = useSearchParams();
  const scenarioId = searchParams.get('scenarioId');

  const { data: profileData } = useProfile();
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

  const call = useVoiceCall({
    nickname: profileData?.profile.nickname,
    jlptLevel: profileData?.profile.jlptLevel,
    scenario,
  });

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

  if (scenarioLoading) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-linear-to-b from-slate-900 to-black">
        <div className="size-6 animate-spin rounded-full border-2 border-white/30 border-t-white" />
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-50 bg-linear-to-b from-slate-900 to-black">
      <CallScreen call={call} scenarioTitle={scenario?.title} />
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
