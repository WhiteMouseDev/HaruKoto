'use client';

import { useEffect } from 'react';
import { useVoiceCall } from '@/hooks/use-voice-call';
import { useProfile } from '@/hooks/use-dashboard';
import { CallScreen } from '@/components/features/chat/call-screen';

export default function CallPage() {
  const { data: profileData } = useProfile();
  const call = useVoiceCall(profileData?.profile.nickname);

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

  return (
    <div className="fixed inset-0 z-50 bg-gradient-to-b from-slate-900 to-black">
      <CallScreen call={call} />
    </div>
  );
}
