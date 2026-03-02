'use client';

import { useState, useEffect, useCallback } from 'react';

type PushState = 'unsupported' | 'default' | 'granted' | 'denied';

export function usePushNotifications() {
  const [state, setState] = useState<PushState>('unsupported');
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      setState('unsupported');
      return;
    }

    // 현재 권한 상태 확인
    const permission = Notification.permission;
    setState(permission as PushState);
  }, []);

  const subscribe = useCallback(async () => {
    if (state === 'unsupported' || state === 'denied') return false;

    setIsLoading(true);
    try {
      const registration = await navigator.serviceWorker.ready;

      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY,
      });

      const keys = subscription.toJSON().keys;
      if (!keys) throw new Error('No keys in subscription');

      await fetch('/api/v1/push/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          endpoint: subscription.endpoint,
          keys: {
            p256dh: keys.p256dh,
            auth: keys.auth,
          },
        }),
      });

      setState('granted');
      return true;
    } catch (err) {
      console.error('Push subscribe error:', err);
      // 권한 거부된 경우
      if (Notification.permission === 'denied') {
        setState('denied');
      }
      return false;
    } finally {
      setIsLoading(false);
    }
  }, [state]);

  const unsubscribe = useCallback(async () => {
    setIsLoading(true);
    try {
      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();

      if (subscription) {
        await fetch('/api/v1/push/subscribe', {
          method: 'DELETE',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            endpoint: subscription.endpoint,
          }),
        });
        await subscription.unsubscribe();
      }

      setState('default');
      return true;
    } catch (err) {
      console.error('Push unsubscribe error:', err);
      return false;
    } finally {
      setIsLoading(false);
    }
  }, []);

  return { state, isLoading, subscribe, unsubscribe };
}
